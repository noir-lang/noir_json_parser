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

        assert(
            (entry.entry_type - BEGIN_ARRAY_TOKEN) * exists as Field == 0, "key does not describe an object"
        );

        let mut r = self;
        r.layer_id = entry.parent_index;
        r.root_id = entry.id;
        r.layer_context = ARRAY_LAYER;
        r.layer_index_in_transcript = key_index;

        Option { _is_some: exists, _value: r }
    }

    fn get_array_unchecked<let KeyBytes: u16>(self, key: [u8; KeyBytes]) -> Self {
        assert(self.layer_context != ARRAY_LAYER, "cannot extract array elements via a key");

        let key_index = self.key_exists_impl_unchecked(key, KeyBytes);
        let entry: JSONEntry = JSONEntry::from_field(self.packed_json_entries[key_index]);

        assert(entry.entry_type == BEGIN_ARRAY_TOKEN, "key does not describe an object");

        let mut r = self;
        r.layer_id = entry.parent_index;
        r.root_id = entry.id;
        r.layer_context = ARRAY_LAYER;
        r.layer_index_in_transcript = key_index;

        r
    }

    fn get_array_unchecked_var<let KeyBytes: u16>(self, key: [u8; KeyBytes], key_length: u16) -> Self {
        assert(self.layer_context != ARRAY_LAYER, "cannot extract array elements via a key");

        let key_index = self.key_exists_impl_unchecked(key, key_length);
        let entry: JSONEntry = JSONEntry::from_field(self.packed_json_entries[key_index]);

        assert(entry.entry_type == BEGIN_ARRAY_TOKEN, "key does not describe an object");

        let mut r = self;
        r.layer_id = entry.parent_index;
        r.root_id = entry.id;
        r.layer_context = ARRAY_LAYER;
        r.layer_index_in_transcript = key_index;

        r
    }
    fn get_array_var<let KeyBytes: u16>(self, key: [u8; KeyBytes], key_length: u16) -> Option<Self> {
        assert(self.layer_context != ARRAY_LAYER, "cannot extract array elements via a key");
        let (exists, key_index) = self.key_exists_impl(key, key_length);
        let entry: JSONEntry = JSONEntry::from_field(self.packed_json_entries[key_index]);

        // TODO: ADD A layer_context VARIABLE INTO JSON WHICH DESCRIBES WHETHER WE ARE AN OBJECT, ARRAY OR SINGLE VALUE
        assert(
            (entry.entry_type - BEGIN_ARRAY_TOKEN) * exists as Field == 0, "key does not describe an object"
        );

        let mut r = self;
        r.layer_id = entry.parent_index;
        r.root_id = entry.id;
        r.layer_context = ARRAY_LAYER;
        r.layer_index_in_transcript = key_index;

        Option { _is_some: exists, _value: r }
    }

    fn get_array_from_array(self, array_index: Field) -> Option<Self> {
        assert(self.layer_context == ARRAY_LAYER, "can only acceess array elements from array");

        let parent_entry = JSONEntry::from_field(self.packed_json_entries[self.layer_index_in_transcript]);

        let valid = lt_field_16_bit(array_index, parent_entry.num_children);
        let entry_index = (parent_entry.child_pointer + array_index) * valid as Field;

        let entry = JSONEntry::from_field(self.packed_json_entries[entry_index]);

        assert(
            (entry.entry_type - BEGIN_ARRAY_TOKEN) * valid as Field == 0, "get_object_from_array: entry exists but is not an object!"
        );

        let mut r = self;
        r.layer_id = entry.parent_index;
        r.root_id = entry.id;
        r.layer_context = ARRAY_LAYER;
        r.layer_index_in_transcript = entry_index;

        Option { _is_some: valid, _value: r }
    }

    fn get_array_from_array_unchecked(self, array_index: Field) -> Self {
        assert(self.layer_context == ARRAY_LAYER, "can only acceess array elements from array");

        let parent_entry = JSONEntry::from_field(self.packed_json_entries[self.layer_index_in_transcript]);

        let valid = lt_field_16_bit(array_index, parent_entry.num_children);
        assert(valid, "array overflow");
        let entry_index = (parent_entry.child_pointer + array_index);

        let entry = JSONEntry::from_field(self.packed_json_entries[entry_index]);

        assert(
            entry.entry_type == BEGIN_ARRAY_TOKEN, "get_array_from_array_unchecked: entry exists but is not an array!"
        );

        let mut r = self;
        r.layer_id = entry.parent_index;
        r.root_id = entry.id;
        r.layer_context = ARRAY_LAYER;
        r.layer_index_in_transcript = entry_index;
        r
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
                    JSONValue { value: BoundedVec{ len: child_entry.json_length as u32, storage: parsed_string }, value_type: child_entry.entry_type }
                );
            }
        }
        r
    }
}

#[test]
fn test_array() {
    let text = "{ \"foo\": [ [1,2,3], [[3,4]], [[]], [], { \"bar\": [\"b\", \"a\", \"z\" ]} ]}";

    let mut json: JSON<_, 7, 60, 60> = JSON::parse_json(text);

    let first = json.get_array_unchecked("foo".as_bytes());
    assert(first.get_length() == 5);

    let A = first.get_array_from_array_unchecked(0);
    assert(A.get_length() == 3);

    let B = first.get_array_from_array_unchecked(1);
    assert(B.get_length() == 1);

    let C = first.get_array_from_array(2).unwrap();
    assert(C.get_length() == 1);

    // incorrect sorting. the object comes before the array. why?
    // 
    let D = first.get_array_from_array_unchecked(3);
    assert(D.get_length() == 0);

    let B_A = B.get_array_from_array_unchecked(0);
    assert(B_A.get_length() == 2);

    let C_A = C.get_array_from_array_unchecked(0);
    assert(C_A.get_length() == 0);

    let fake = first.get_array_from_array(5);
    assert(fake.is_some() == false);

    let E = first.get_object_from_array_unchecked(4);

    let entry_maybe = JSONEntry::from_field(E.packed_json_entries[E.layer_index_in_transcript]);
    println(f"entry = {entry_maybe}");
    let child = JSONEntry::from_field(E.packed_json_entries[entry_maybe.child_pointer]);
    println(f"target? = {child}");
    println(f"{E}");
    let E_A = E.get_array_unchecked("bar".as_bytes());
    assert(E_A.get_length() == 3);
}
