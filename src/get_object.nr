use crate::json_entry::JSONEntry;
use crate::json::JSON;
use crate::lt::lt_field_16_bit;
use crate::json_tables::{OBJECT_LAYER, ARRAY_LAYER, BEGIN_OBJECT_TOKEN};
use crate::keyhash::get_keyhash;
use crate::getters::JSONValue;

/**
 * @brief getter methods for extracting object types out of a JSON struct
 **/
impl<let NumBytes: u32, let NumPackedFields: u16, let MaxNumTokens: u16, let MaxNumValues: u16> JSON<NumBytes,NumPackedFields, MaxNumTokens, MaxNumValues> {

    /**
     * @brief if the root JSON is an object, extract a child object given by `key`
     * @description returns an Option<JSON> where, if the object exists, the JSON object will have the requested object as its root value  
     **/
    fn get_object<let KeyBytes: u16>(self, key: [u8; KeyBytes]) -> Option<Self> {
        assert(self.layer_context != ARRAY_LAYER, "cannot extract array elements via a key");

        let (exists, key_index) = self.key_exists_impl(key, KeyBytes);
        let entry: JSONEntry = self.packed_json_entries[key_index].into();
        assert(
            (entry.entry_type - BEGIN_OBJECT_TOKEN) * exists as Field == 0, "get_object: entry exists but is not an object!"
        );

        let mut r = self;
        r.layer_id = entry.parent_index;
        r.root_id = entry.id;
        r.layer_context = OBJECT_LAYER;
        r.layer_index_in_transcript = key_index;
        Option { _is_some: exists, _value: r }
    }

    /**
     * @brief if the root JSON is an object, extract a child object given by `key`
     * @description will revert if the requested object does not exist
     **/
    fn get_object_unchecked<let KeyBytes: u16>(self, key: [u8; KeyBytes]) -> Self {
        assert(self.layer_context != ARRAY_LAYER, "cannot extract array elements via a key");
        let (entry, key_index) = self.get_json_entry_unchecked_with_key_index_var(key, KeyBytes);
        let entry: JSONEntry = self.packed_json_entries[key_index].into();
        assert(entry.entry_type == BEGIN_OBJECT_TOKEN, "get_object: entry exists but is not an object!");

        let mut r = self;
        r.layer_id = entry.parent_index;
        r.root_id = entry.id;
        r.layer_context = OBJECT_LAYER;
        r.layer_index_in_transcript = key_index;
        r
    }

    /**
     * @brief same as `get_object` for where the key length may be less than KeyBytes
     **/
    fn get_object_var<let KeyBytes: u16>(self, key: [u8; KeyBytes], key_length: u16) -> Option<Self> {
        assert(self.layer_context != ARRAY_LAYER, "cannot extract array elements via a key");

        let (exists, key_index) = self.key_exists_impl(key, key_length);
        let entry: JSONEntry = self.packed_json_entries[key_index].into();
        assert(
            (entry.entry_type - BEGIN_OBJECT_TOKEN) * exists as Field == 0, "get_object: entry exists but is not an object!"
        );

        let mut r = self;
        r.layer_id = entry.parent_index;
        r.root_id = entry.id;
        r.layer_context = OBJECT_LAYER;
        r.layer_index_in_transcript = key_index;
        Option { _is_some: exists, _value: r }
    }

    /**
     * @brief same as `get_object_unchecked` for where the key length may be less than KeyBytes
     **/
    fn get_object_unchecked_var<let KeyBytes: u16>(self, key: [u8; KeyBytes], key_length: u16) -> Self {
        assert(self.layer_context != ARRAY_LAYER, "cannot extract array elements via a key");
        let (entry, key_index) = self.get_json_entry_unchecked_with_key_index_var(key, key_length);
        let entry: JSONEntry = self.packed_json_entries[key_index].into();
        assert(entry.entry_type == BEGIN_OBJECT_TOKEN, "get_object: entry exists but is not an object!");

        let mut r = self;
        r.layer_id = entry.parent_index;
        r.root_id = entry.id;
        r.layer_context = OBJECT_LAYER;
        r.layer_index_in_transcript = key_index;
        r
    }

    /**
     * @brief if the root JSON is an array, extract an object given by the position of the target in the source array
     * @description returns an Option<JSON> where, if the object exists, the JSON object will have the requested object as its root value  
     **/
    fn get_object_from_array(self, array_index: Field) -> Option<Self> {
        assert(self.layer_context == ARRAY_LAYER, "can only acceess array elements from array");

        let parent_entry : JSONEntry = self.packed_json_entries[self.layer_index_in_transcript].into();

        let valid = lt_field_16_bit(array_index, parent_entry.num_children);
        let entry_index = (parent_entry.child_pointer + array_index) * valid as Field;

        let entry : JSONEntry = self.packed_json_entries[entry_index].into();

        assert(
            (entry.entry_type - BEGIN_OBJECT_TOKEN) * valid as Field == 0, "get_object_from_array: entry exists but is not an object!"
        );

        let mut r = self;
        r.layer_id = entry.parent_index;
        r.root_id = entry.id;
        r.layer_context = OBJECT_LAYER;
        r.layer_index_in_transcript = entry_index;

        Option { _is_some: valid, _value: r }
    }

    /**
     * @brief if the root JSON is an array, extract an object given by the position of the target in the source array
     * @description will revert if the object does not exist
     **/
    fn get_object_from_array_unchecked(self, array_index: Field) -> Self {
        assert(self.layer_context == ARRAY_LAYER, "can only acceess array elements from array");

        let parent_entry : JSONEntry = self.packed_json_entries[self.layer_index_in_transcript].into();

        let valid = lt_field_16_bit(array_index, parent_entry.num_children);
        assert(valid, "array overflow");
        let entry_index = (parent_entry.child_pointer + array_index);

        let entry : JSONEntry = self.packed_json_entries[entry_index].into();
        assert(
            entry.entry_type == BEGIN_OBJECT_TOKEN, "get_object_from_array_unchecked: entry exists but is not an object!"
        );

        let mut r = self;
        r.layer_id = entry.parent_index;
        r.root_id = entry.id;
        r.layer_context = OBJECT_LAYER;
        r.layer_index_in_transcript = entry_index;
        r
    }
}

#[test]
fn test_object() {
    let text = "{ \"foo\": [ [1,{ \"bartholomew tony Harrison III\": { \"hello\": \"world\" }},3], [[3,4]], [[]], [], { \"bar\": [\"b\", \"a\", \"z\" ]} ]}";

    let mut json: JSON<_, 7, 60, 60> = JSON::parse_json(text);

    let first = json.get_array_unchecked("foo".as_bytes());
    assert(first.get_length() == 5);

    let A = first.get_array_from_array_unchecked(0);
    assert(A.get_length() == 3);

    let B = A.get_object_from_array_unchecked(1);
    let B_alt = A.get_object_from_array(1);
    assert(B == B_alt.unwrap());

    let C = B.get_object_unchecked("bartholomew tony Harrison III".as_bytes());
    assert(JSONEntry::from(C.packed_json_entries[C.layer_index_in_transcript]).num_children == 1);

    let not_real = B.get_object("bartholomew tony Harrison IV".as_bytes());
    assert(not_real.is_some() == false);

    let C = B.get_object_unchecked_var("bartholomew tony Harrison III".as_bytes(), 29);
    assert(JSONEntry::from(C.packed_json_entries[C.layer_index_in_transcript]).num_children == 1);

    let C = B.get_object_var("bartholomew tony Harrison III".as_bytes(), 28);
    assert(C.is_some() == false);

    let C = B.get_object_var("bartholomew tony Harrison IIIekurfgaeoiurh".as_bytes(), 29);
    assert(C.is_some() == true);

    let second = first.get_object_from_array_unchecked(4);

    let third = second.get_array_unchecked("bar".as_bytes());

    let E: BoundedVec<u8, 1> = third.get_string_from_array_unchecked(0);
    let F: BoundedVec<u8, 1> = third.get_string_from_array_unchecked(1);
    let G: BoundedVec<u8, 1> = third.get_string_from_array_unchecked(2);
    assert(E.storage == "b".as_bytes());
    assert(F.storage == "a".as_bytes());
    assert(G.storage == "z".as_bytes());
}
