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

global MAX_LITERAL_LENGTH_AS_STRING = 5;
global LITERAL_OFFSET_SHIFT: [Field; 6] = [
   0x10000000000, 0x100000000, 0x1000000, 0x10000, 0x100,1
];
fn extract_literal_from_array(arr: [u8; MAX_LITERAL_LENGTH_AS_STRING], json_length: Field) -> JSONLiteral {
    let false_field = 0x66616c7365;
    let true_field = 0x74727565;
    let null_field = 0x6e756c6c;

    let mut parsed_literal: Field = 0;
    for i in 0..MAX_LITERAL_LENGTH_AS_STRING {
        parsed_literal *= 0x100;

        let value = arr[i] as Field;
        parsed_literal += value;
    }
    parsed_literal /= LITERAL_OFFSET_SHIFT[json_length];
    let is_false = parsed_literal == false_field;
    let is_null = parsed_literal == null_field;
    let is_true = parsed_literal == true_field;
    JSONLiteral::new(is_true, is_false, is_null)
}

struct JSONLiteral {
    value: Field,
}

impl JSONLiteral {
    fn new(is_true: bool, is_false: bool, is_null: bool) -> Self {
        assert(is_false as Field + is_null as Field + is_true as Field == 1, "parse literal: invalid entry");
        JSONLiteral { value: is_true as Field * 2 + is_null as Field }
    }
    fn is_true(self) -> bool {
        self.value == 2
    }
    fn is_null(self) -> bool {
        self.value == 1
    }
    fn is_false(self) -> bool {
        self.value == 0
    }
    fn to_bool(self) -> bool {
        self.value == 2
    }
}

impl<let NumBytes: u32, let NumPackedFields: u16, let MaxNumTokens: u16, let MaxNumValues: u16> JSON<NumBytes,NumPackedFields, MaxNumTokens, MaxNumValues> {

    fn get_literal<let KeyBytes: u16>(self, key: [u8; KeyBytes]) -> Option<JSONLiteral> {
        assert(self.layer_context != ARRAY_LAYER, "cannot extract array elements via a key");

        let (exists, entry) = self.get_json_entry(key);
        assert(
            (entry.entry_type - LITERAL_TOKEN) * exists as Field == 0, "get_literal: entry exists but is not a literal!"
        );
        let mut parsed_string: [u8; MAX_LITERAL_LENGTH_AS_STRING] = self.extract_string_entry(entry);

        Option { _is_some: exists, _value: extract_literal_from_array(parsed_string, entry.json_length) }
    }

    fn get_literal_var<let KeyBytes: u16>(self, key: [u8; KeyBytes], key_length: u16) -> Option<JSONLiteral> {
        assert(self.layer_context != ARRAY_LAYER, "cannot extract array elements via a key");

        let (exists, entry) = self.get_json_entry_var(key, key_length);
        assert(
            (entry.entry_type - LITERAL_TOKEN) * exists as Field == 0, "get_literal_var: entry exists but is not a literal!"
        );
        let mut parsed_string: [u8; MAX_LITERAL_LENGTH_AS_STRING] = self.extract_string_entry(entry);

        Option { _is_some: exists, _value: extract_literal_from_array(parsed_string, entry.json_length) }
    }

    fn get_literal_unchecked_var<let KeyBytes: u16>(self, key: [u8; KeyBytes], key_length: u16) -> JSONLiteral {
        assert(self.layer_context != ARRAY_LAYER, "cannot extract array elements via a key");

        let entry= self.get_json_entry_unchecked_var(key, key_length);
        assert(
            entry.entry_type == LITERAL_TOKEN, "get_literal_unchecked_var: entry exists but is not a literal!"
        );
        let mut parsed_string: [u8; MAX_LITERAL_LENGTH_AS_STRING] = self.extract_string_entry(entry);

        extract_literal_from_array(parsed_string, entry.json_length)
    }

    fn get_literal_unchecked<let KeyBytes: u16>(self, key: [u8; KeyBytes]) -> JSONLiteral {
        assert(self.layer_context != ARRAY_LAYER, "cannot extract array elements via a key");

        let entry= self.get_json_entry_unchecked(key);
        assert(
            entry.entry_type == LITERAL_TOKEN, "get_literal_unchecked_var: entry exists but is not a literal!"
        );
        let mut parsed_string: [u8; MAX_LITERAL_LENGTH_AS_STRING] = self.extract_string_entry(entry);

        extract_literal_from_array(parsed_string, entry.json_length)
    }

    fn get_literal_from_array(self, array_index: Field) -> Option<JSONLiteral> {
        assert(self.layer_context == ARRAY_LAYER, "can only acceess array elements from array");

        let parent_entry = JSONEntry::from_field(self.packed_json_entries[self.layer_index_in_transcript]);

        let valid = lt_field_16_bit(array_index, parent_entry.num_children);
        let entry_index = (parent_entry.child_pointer + array_index) * valid as Field;

        let entry = JSONEntry::from_field(self.packed_json_entries[entry_index]);

        assert(
            (entry.entry_type - LITERAL_TOKEN) * valid as Field == 0, "get_literal_from_array: entry exists but is not a literal!"
        );

        let mut parsed_string: [u8; MAX_LITERAL_LENGTH_AS_STRING] = self.extract_string_entry(entry);
        let result = extract_literal_from_array(parsed_string, entry.json_length);

        Option { _is_some: valid, _value: result }
    }

    fn get_literal_from_array_unchecked(self, array_index: Field) -> JSONLiteral {
        assert(self.layer_context == ARRAY_LAYER, "can only acceess array elements from array");

        let parent_entry = JSONEntry::from_field(self.packed_json_entries[self.layer_index_in_transcript]);

        let valid = lt_field_16_bit(array_index, parent_entry.num_children);
        assert(valid, "array overflow");
        let entry_index = (parent_entry.child_pointer + array_index);

        let entry = JSONEntry::from_field(self.packed_json_entries[entry_index]);

        assert(
            entry.entry_type == LITERAL_TOKEN, "get_literal_from_array_unchecked: entry exists but is not a literal!"
        );

        let mut parsed_string: [u8; MAX_LITERAL_LENGTH_AS_STRING] = self.extract_string_entry(entry);
        extract_literal_from_array(parsed_string, entry.json_length)
    }
}
