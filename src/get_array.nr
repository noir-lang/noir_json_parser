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
use crate::getters::JSONValue;

impl<let NumBytes: u32, let NumPackedFields: u16, let MaxNumTokens: u16, let MaxNumValues: u16> JSON<NumBytes,NumPackedFields, MaxNumTokens, MaxNumValues> {

    fn get_length(self) -> u32 {
        assert(self.layer_context == ARRAY_LAYER, "can only get length of an array type");
        let parent_entry = JSONEntry::from_field(self.packed_json_entries[self.layer_index_in_transcript]);
        parent_entry.num_children as u32
    }

    fn get_array<let KeyBytes: u16>(self, key: [u8; KeyBytes]) -> Option<Self> {
        assert(self.layer_context != ARRAY_LAYER, "cannot extract array elements via a key");
        let (exists, key_index) = self.key_exists_impl(key, KeyBytes);
        let entry: JSONEntry = JSONEntry::from_field(self.packed_json_entries[key_index]);

        assert(entry.entry_type == BEGIN_ARRAY_TOKEN, "key does not describe an object");

        let mut result: Option<JSON<NumBytes, NumPackedFields, MaxNumTokens, MaxNumValues>> = Option::none();
        if (exists) {
            let mut r = self;
            r.layer_id = entry.parent_index;
            r.layer_context = ARRAY_LAYER;
            r.layer_index_in_transcript = key_index;
            result = Option::some(r);
        }
        result
    }

    fn get_array_var<let KeyBytes: u16>(self, key: [u8; KeyBytes], key_length: u16) -> Option<Self> {
        assert(self.layer_context != ARRAY_LAYER, "cannot extract array elements via a key");
        let (exists, key_index) = self.key_exists_impl(key, key_length);
        let entry: JSONEntry = JSONEntry::from_field(self.packed_json_entries[key_index]);

        // TODO: ADD A layer_context VARIABLE INTO JSON WHICH DESCRIBES WHETHER WE ARE AN OBJECT, ARRAY OR SINGLE VALUE
        assert(entry.entry_type == BEGIN_ARRAY_TOKEN, "key does not describe an object");

        let mut result: Option<JSON<NumBytes, NumPackedFields, MaxNumTokens, MaxNumValues>> = Option::none();
        if (exists) {
            let mut r = self;
            r.layer_id = entry.parent_index;
            r.layer_context = ARRAY_LAYER;
            r.layer_index_in_transcript = key_index;
            result = Option::some(r);
        }
        result
    }

    fn map<U, let MaxElements: u32, let MaxElementBytes: u32>(
        self,
        f: fn(JSONValue<MaxElementBytes>) -> U
    ) -> [U; MaxElements] where U: std::default::Default {
        assert(self.layer_context == ARRAY_LAYER, "can only call map on an array");

        let entry = JSONEntry::from_field(self.packed_json_entries[self.layer_index_in_transcript]);

        let num_children = entry.num_children;
        let mut r: [U; MaxElements] = [U::default(); MaxElements];

        for i in 0..MaxElements {
            let valid = lt_field_16_bit(i as Field, num_children);
            let entry_index = (entry.child_pointer + i as Field) * valid as Field;
            let child_entry = JSONEntry::from_field(self.packed_json_entries[entry_index]);

            let mut parsed_string: [u8; MaxElementBytes] = [0; MaxElementBytes];
            for j in 0..MaxElementBytes {
                let byte_valid = lt_field_16_bit(j as Field, child_entry.json_length);
                // n.b. conditionally setting index to 0 can be removed if we ensure json is padded such that this index does not overflow json bytes
                let byte = self.json[(child_entry.json_pointer + i as Field) * valid as Field];
                // TODO improve efficiency? measure...
                if (byte_valid) {
                    parsed_string[i] = byte;
                }
            }

            if (valid) {
                r[i] = f(
                    JSONValue { length: child_entry.json_length, value: parsed_string, value_type: child_entry.entry_type }
                );
            }
        }
        r
    }
}
