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

global U64_LENGTH_AS_BASE10_STRING = 20;
global NUMBER_OFFSET_SHIFT: [Field; 21] = [
    100000000000000000000,10000000000000000000,1000000000000000000,100000000000000000,10000000000000000,1000000000000000,100000000000000,10000000000000, 1000000000000, 100000000000, 10000000000, 1000000000, 100000000,10000000,1000000,100000,10000,1000,100,10,1
];
fn extract_number_from_array(arr: [u8; U64_LENGTH_AS_BASE10_STRING], json_length: Field) -> u64 {
    let mut parsed_number: Field = 0;
    for i in 0..U64_LENGTH_AS_BASE10_STRING {
        parsed_number *= 10;

        let value = ASCII_TO_NUMBER[arr[i]] as Field;
        parsed_number += value;
    }
    parsed_number /= NUMBER_OFFSET_SHIFT[json_length];
    parsed_number as u64
}
impl<let NumBytes: u32, let NumPackedFields: u16, let MaxNumTokens: u16, let MaxNumValues: u16> JSON<NumBytes,NumPackedFields, MaxNumTokens, MaxNumValues> {

    fn get_number<let KeyBytes: u16>(self, key: [u8; KeyBytes]) -> Option<u64> {
        let (exists, entry) = self.get_json_entry(key);
        assert(
            (entry.entry_type - NUMERIC_TOKEN) * exists as Field == 0, "get_number: entry exists but is not a number!"
        );
        let mut parsed_string: [u8; U64_LENGTH_AS_BASE10_STRING] = self.extract_string_entry(entry);

        Option { _is_some: exists, _value: extract_number_from_array(parsed_string, entry.json_length) }
    }

    fn get_number_var<let KeyBytes: u16>(self, key: [u8; KeyBytes], key_length: u16) -> Option<u64> {
        let (exists, entry) = self.get_json_entry_var(key, key_length);
        assert(
            (entry.entry_type - NUMERIC_TOKEN) * exists as Field == 0, "get_number: entry exists but is not a number!"
        );
        let mut parsed_string: [u8; U64_LENGTH_AS_BASE10_STRING] = self.extract_string_entry(entry);

        Option { _is_some: exists, _value: extract_number_from_array(parsed_string, entry.json_length) }
    }

    fn get_number_unchecked<let KeyBytes: u16>(self, key: [u8; KeyBytes]) -> u64 {
        let  entry = self.get_json_entry_unchecked(key);
        assert(entry.entry_type == NUMERIC_TOKEN, "get_number_unchecked: entry exists but is not a number!");
        let mut parsed_string: [u8; U64_LENGTH_AS_BASE10_STRING] = self.extract_string_entry(entry);

        extract_number_from_array(parsed_string, entry.json_length)
    }

    fn get_number_unchecked_var<let KeyBytes: u16>(self, key: [u8; KeyBytes], key_length: u16) -> u64 {
        let  entry = self.get_json_entry_unchecked_var(key, key_length);
        assert(entry.entry_type == NUMERIC_TOKEN, "get_number_unchecked: entry exists but is not a number!");
        let mut parsed_string: [u8; U64_LENGTH_AS_BASE10_STRING] = self.extract_string_entry(entry);

        extract_number_from_array(parsed_string, entry.json_length)
    }

    fn get_number_from_array(self, array_index: Field) -> Option<u64> {
        assert(self.layer_context == ARRAY_LAYER, "can only acceess array elements from array");

        let parent_entry = JSONEntry::from_field(self.packed_json_entries[self.layer_index_in_transcript]);

        let valid = lt_field_16_bit(array_index, parent_entry.num_children);
        let entry_index = (parent_entry.child_pointer + array_index) * valid as Field;

        let entry = JSONEntry::from_field(self.packed_json_entries[entry_index]);

        assert(
            (entry.entry_type - NUMERIC_TOKEN) * valid as Field == 0, "get_number: entry exists but is not a number!"
        );

        let mut parsed_string: [u8; U64_LENGTH_AS_BASE10_STRING] = self.extract_string_entry(entry);
        let result = extract_number_from_array(parsed_string, entry.json_length);

        Option { _is_some: valid, _value: result }
    }

    fn get_number_from_array_unchecked(self, array_index: Field) -> u64 {
        assert(self.layer_context == ARRAY_LAYER, "can only acceess array elements from array");

        let parent_entry = JSONEntry::from_field(self.packed_json_entries[self.layer_index_in_transcript]);

        let valid = lt_field_16_bit(array_index, parent_entry.num_children);
        assert(valid, "array overflow");
        let entry_index = (parent_entry.child_pointer + array_index);

        let entry = JSONEntry::from_field(self.packed_json_entries[entry_index]);

        assert(entry.entry_type == NUMERIC_TOKEN, "get_number: entry exists but is not a number!");

        let mut parsed_string: [u8; U64_LENGTH_AS_BASE10_STRING] = self.extract_string_entry(entry);
        extract_number_from_array(parsed_string, entry.json_length)
    }
}
