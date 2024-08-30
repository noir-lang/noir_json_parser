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

impl<let NumBytes: u32, let NumPackedFields: u16, let MaxNumTokens: u16, let MaxNumValues: u16> JSON<NumBytes,NumPackedFields, MaxNumTokens, MaxNumValues> {

    fn get_object_var<let KeyBytes: u16>(self, key: [u8; KeyBytes], key_length: u16) -> Option<Self> {
        assert(self.layer_context != ARRAY_LAYER, "cannot extract array elements via a key");

        let (exists, key_index) = self.key_exists_impl(key, key_length);
        let entry: JSONEntry = JSONEntry::from_field(self.packed_json_entries[key_index]);
        assert(
            (entry.entry_type - BEGIN_OBJECT_TOKEN) * exists as Field == 0, "get_object: entry exists but is not an object!"
        );

        let mut r = self;
        r.layer_id = entry.parent_index;
        r.layer_context = OBJECT_LAYER;
        r.layer_index_in_transcript = key_index;
        Option { _is_some: exists, _value: r }
    }

    fn get_object<let KeyBytes: u16>(self, key: [u8; KeyBytes]) -> Option<Self> {
        assert(self.layer_context != ARRAY_LAYER, "cannot extract array elements via a key");

        let (exists, key_index) = self.key_exists_impl(key, KeyBytes);
        let entry: JSONEntry = JSONEntry::from_field(self.packed_json_entries[key_index]);
        assert(
            (entry.entry_type - BEGIN_OBJECT_TOKEN) * exists as Field == 0, "get_object: entry exists but is not an object!"
        );

        let mut r = self;
        r.layer_id = entry.parent_index;
        r.layer_context = OBJECT_LAYER;
        r.layer_index_in_transcript = key_index;
        Option { _is_some: exists, _value: r }
    }

    fn get_object_unchecked_var<let KeyBytes: u16>(self, key: [u8; KeyBytes], key_length: u16) -> Self {
        assert(self.layer_context != ARRAY_LAYER, "cannot extract array elements via a key");
        let (entry, key_index) = self.get_json_entry_unchecked_with_key_index_var(key, key_length);
        let entry: JSONEntry = JSONEntry::from_field(self.packed_json_entries[key_index]);
        assert(entry.entry_type == BEGIN_OBJECT_TOKEN, "get_object: entry exists but is not an object!");

        let mut r = self;
        r.layer_id = entry.parent_index;
        r.layer_context = OBJECT_LAYER;
        r.layer_index_in_transcript = key_index;
        r
    }

    fn get_object_unchecked<let KeyBytes: u16>(self, key: [u8; KeyBytes]) -> Self {
        assert(self.layer_context != ARRAY_LAYER, "cannot extract array elements via a key");
        let (entry, key_index) = self.get_json_entry_unchecked_with_key_index_var(key, KeyBytes);
        let entry: JSONEntry = JSONEntry::from_field(self.packed_json_entries[key_index]);
        assert(entry.entry_type == BEGIN_OBJECT_TOKEN, "get_object: entry exists but is not an object!");

        let mut r = self;
        r.layer_id = entry.parent_index;
        r.layer_context = OBJECT_LAYER;
        r.layer_index_in_transcript = key_index;
        r
    }
}
