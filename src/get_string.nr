use crate::getters;
use dep::noir_sort;
use crate::json_entry::JSONEntry;
use crate::redux::JSON;
use crate::keymap;
use crate::lt::{lt_field_8_bit, lt_field_16_bit, assert_lt_240_bit, assert_gt_240_bit};
use crate::redux_tables::{
    OBJECT_LAYER, ARRAY_LAYER, NUMERIC_TOKEN, LITERAL_TOKEN, STRING_TOKEN, BEGIN_OBJECT_TOKEN,
    BEGIN_ARRAY_TOKEN, ASCII_TO_NUMBER, ESCAPE_SEQUENCE_END_CHARS, ESCAPE_SEQUENCE_START_CHARS,
    ESCAPE_SEQUENCE_REPLACEMENT
};
use crate::keyhash::Hasher;
use crate::keyhash::get_keyhash;
use crate::slice_field::slice_fields;

unconstrained fn to_u8(f: Field) -> u8 {
    f as u8
}
fn process_escape_sequences<let N: u16>(input: BoundedVec<u8, N>) -> BoundedVec<u8, N> {
    let string = input.storage;
    let mut result: [u8; N] = [0; N];
    let mut result_ptr = 0;
    let mut character = string[0];
    let mut skip = 0;
    let mut cached_byte: Field = 0;
    for i in 1..N {
        let next_character = string[i];
        let escape_sequence_start_candidate = ESCAPE_SEQUENCE_START_CHARS[character];
        let escape_sequence_end_candidate = ESCAPE_SEQUENCE_END_CHARS[next_character];
        let escape_sequence_replacement_candidate = ESCAPE_SEQUENCE_REPLACEMENT[next_character];
        let mut is_escape_sequence = (escape_sequence_start_candidate & escape_sequence_end_candidate) as Field;
        is_escape_sequence = is_escape_sequence * (1 - skip);
        let mut written_byte = is_escape_sequence * escape_sequence_replacement_candidate as Field
            + (1 - is_escape_sequence) * character as Field;

        written_byte = written_byte * (1 - skip) + cached_byte * skip;
        let written_byte_u8 = to_u8(written_byte);
        assert(written_byte_u8 as Field == written_byte);

        result[result_ptr] = written_byte_u8;
        result_ptr += (1 - is_escape_sequence);
        cached_byte = written_byte;
        skip = is_escape_sequence;
        character = next_character;
    }

    let written_byte: Field = character as Field * (1 - skip) + cached_byte * skip;
    let written_byte_u8 = to_u8(written_byte);
    assert(written_byte_u8 as Field == written_byte);
    result[result_ptr] =  written_byte_u8;
    result_ptr += 1;

    let num_removed_chars = N as Field - result_ptr;
    let new_length = input.len as Field - num_removed_chars;
    BoundedVec { storage: result, len: new_length as u32 }
}

#[test]
fn test_process_escape_sequence_2() {
    let text = BoundedVec::from_array("\\\"Ade\\nel Solangi\\\"".as_bytes());
    let mut expected = text;
    expected = BoundedVec::from_array("\"Ade\nel Solangi\"".as_bytes());
    let result: BoundedVec<u8, 19> = process_escape_sequences(text);
    assert(result == expected);
}
#[test]
fn test_process_escape_sequence() {
    // end with escape sequence
    {
        let text = BoundedVec::from_array("the qulick brown fox said \\\"why hello there\\\"  \\\\".as_bytes());

        let expected: BoundedVec<u8, 49> = BoundedVec::from_array("the qulick brown fox said \"why hello there\"  \\".as_bytes());

        let result: BoundedVec<u8, 49> = process_escape_sequences(text);

        assert(result == expected);
    }
    // end without escape sequence
    {
        let text = BoundedVec::from_array("\\\"he qulick brown fox said \\n \\r \\\"why hello there\\\"  \\\\".as_bytes());

        let expected: BoundedVec<u8, 56> = BoundedVec::from_array("\"he qulick brown fox said \n \r \"why hello there\"  \\".as_bytes());

        let result = process_escape_sequences(text);

        assert(result == expected);
    }
}

impl<let NumBytes: u32, let NumPackedFields: u16, let MaxNumTokens: u16, let MaxNumValues: u16> JSON<NumBytes,NumPackedFields, MaxNumTokens, MaxNumValues> {

    fn get_string<let KeyBytes: u16, let StringBytes: u16>(self, key: [u8; KeyBytes]) -> Option<BoundedVec<u8, StringBytes>> {
        let (exists, entry) = self.get_json_entry(key);
        assert(
            (entry.entry_type - STRING_TOKEN) * exists as Field == 0, "get_string: entry exists but is not a string!"
        );
        let mut parsed_string: [u8; StringBytes] = self.extract_string_entry(entry);

        let parsed_string: BoundedVec<u8, StringBytes> = process_escape_sequences(BoundedVec { storage: parsed_string, len: entry.json_length as u32 });
        Option { _is_some: exists, _value: parsed_string }
    }

    fn get_string_var<let KeyBytes: u16, let StringBytes: u16>(self, key: BoundedVec<u8, KeyBytes>) -> Option<BoundedVec<u8, StringBytes>> {
        let (exists, entry) = self.get_json_entry_var(key.storage, key.len as u16);
        assert(
            (entry.entry_type - STRING_TOKEN) * exists as Field == 0, "get_string: entry exists but is not a string!"
        );
        let mut parsed_string: [u8; StringBytes] = self.extract_string_entry(entry);

        let parsed_string: BoundedVec<u8, StringBytes> = process_escape_sequences(BoundedVec { storage: parsed_string, len: entry.json_length as u32 });
        Option { _is_some: exists, _value: parsed_string }
    }

    fn get_string_unchecked<let KeyBytes: u16, let StringBytes: u16>(self, key: [u8; KeyBytes]) -> BoundedVec<u8, StringBytes> {
        let entry = self.get_json_entry_unchecked(key);
        assert(entry.entry_type == STRING_TOKEN, "get_string_unchecked: entry exists but is not a string!");
        let parsed_string = BoundedVec { storage: self.extract_string_entry(entry), len: entry.json_length as u32 };
        process_escape_sequences(parsed_string)
    }

    fn get_string_unchecked_var<let KeyBytes: u16, let StringBytes: u16>(self, key: BoundedVec<u8, KeyBytes>) -> BoundedVec<u8, StringBytes> {
        let entry = self.get_json_entry_unchecked_var(key.storage, key.len as u16);
        assert(entry.entry_type == STRING_TOKEN, "get_string_unchecked: entry exists but is not a string!");
        let parsed_string = BoundedVec { storage: self.extract_string_entry(entry), len: entry.json_length as u32 };
        process_escape_sequences(parsed_string)
    }

    fn get_string_from_path<let KeyBytes: u16, let StringBytes: u16, let PathDepth: u16>(self, keys: [BoundedVec<u8, KeyBytes>; PathDepth]) -> Option<BoundedVec<u8, StringBytes>> {
        let mut target = self;
        let mut valid = true;
        for i in 0..PathDepth - 1 {
            let child  = self.get_object_var(keys[i].storage, keys[i].len as u16);

            target = child._value;
            valid = valid & child._is_some;
        }

        let mut final = target.get_string_var(keys[PathDepth - 1]);
        final._is_some = final._is_some & valid;
        final
    }

    fn get_value<let KeyBytes: u16, let StringBytes: u16>(self, key: [u8; KeyBytes]) -> Option<BoundedVec<u8, StringBytes>> {
        let (exists, entry) = self.get_json_entry(key);
        let mut parsed_string: [u8; StringBytes] = self.extract_string_entry(entry);

        let parsed_string: BoundedVec<u8, StringBytes> = BoundedVec { storage: parsed_string, len: entry.json_length as u32 };
        Option { _is_some: exists, _value: parsed_string }
    }

    fn get_value_var<let KeyBytes: u16, let StringBytes: u16>(self, key: BoundedVec<u8, KeyBytes>) -> Option<BoundedVec<u8, StringBytes>> {
        let (exists, entry) = self.get_json_entry_var(key.storage, key.len as u16);
        let mut parsed_string: [u8; StringBytes] = self.extract_string_entry(entry);

        let parsed_string: BoundedVec<u8, StringBytes> = BoundedVec { storage: parsed_string, len: entry.json_length as u32 };
        Option { _is_some: exists, _value: parsed_string }
    }

    fn get_value_unchecked<let KeyBytes: u16, let StringBytes: u16>(self, key: [u8; KeyBytes]) -> BoundedVec<u8, StringBytes> {
        let entry = self.get_json_entry_unchecked(key);
        BoundedVec { storage: self.extract_string_entry(entry), len: entry.json_length as u32 }
    }

    fn get_value_unchecked_var<let KeyBytes: u16, let StringBytes: u16>(self, key: BoundedVec<u8, KeyBytes>) -> BoundedVec<u8, StringBytes> {
        let entry = self.get_json_entry_unchecked_var(key.storage, key.len as u16);
        BoundedVec { storage: self.extract_string_entry(entry), len: entry.json_length as u32 }
    }

    fn get_value_from_path<let KeyBytes: u16, let StringBytes: u16, let PathDepth: u16>(self, keys: [BoundedVec<u8, KeyBytes>; PathDepth]) -> Option<BoundedVec<u8, StringBytes>> {
        let mut target = self;
        let mut valid = true;
        for i in 0..PathDepth - 1 {
            let child  = self.get_object_var(keys[i].storage, keys[i].len as u16);

            target = child._value;
            valid = valid & child._is_some;
        }

        let mut final = target.get_value_var(keys[PathDepth - 1]);
        final._is_some = final._is_some & valid;
        final
    }
}
