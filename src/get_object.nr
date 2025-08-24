use crate::enums::Layer::{ARRAY_LAYER, OBJECT_LAYER};
use crate::enums::Token::END_OBJECT_TOKEN;
use crate::getters::KeyHashable;
use crate::json::JSON;
use crate::json_entry::JSONEntry;

/// getter methods for extracting object types out of a JSON struct
impl<let NumBytes: u32, let NumPackedFields: u32, let MaxNumTokens: u32, let MaxNumValues: u32, let MaxKeyFields: u32> JSON<NumBytes, NumPackedFields, MaxNumTokens, MaxNumValues, MaxKeyFields> {
    /// Updates the JSON object to point to a specific object entry
    pub(crate) fn update_json_object(mut self, entry: JSONEntry, key_index: u32) -> Self {
        self.root_id = entry.id;
        self.layer_type_of_root = OBJECT_LAYER;
        self.root_index_in_transcript = key_index;
        self
    }

    /// if the root JSON is an object, extract a child object given by `key`
    ///
    /// returns an Option<JSON> where, if the object exists, the JSON object will have the requested object as its root value
    pub(crate) fn get_object<K>(self, key: K) -> Option<Self>
    where
        K: KeyHashable,
    {
        let (exists, entry, key_index) = self.get_json_entry(key);
        if exists {
            assert_eq(
                entry.entry_type,
                END_OBJECT_TOKEN as Field,
                "get_object: entry exists but is not an object!",
            );
        }

        let result = self.update_json_object(entry, key_index);

        if exists {
            Option::some(result)
        } else {
            Option::none()
        }
    }

    // if the root JSON is an object, extract a child object given by `key`
    ///
    /// will revert if the requested object does not exist
    pub(crate) fn get_object_unchecked<K>(self, key: K) -> Self
    where
        K: KeyHashable,
    {
        assert(self.layer_type_of_root != ARRAY_LAYER, "cannot extract array elements via a key");
        let (entry, key_index) = self.get_json_entry_unchecked_with_key_index(key);
        let entry: JSONEntry = self.json_entries_packed[key_index].into();
        assert_eq(
            entry.entry_type,
            END_OBJECT_TOKEN as Field,
            "get_object: entry exists but is not an object!",
        );

        self.update_json_object(entry, key_index)
    }

    /// if the root JSON is an array, extract an object given by the position of the target in the source array
    ///
    /// returns an Option<JSON> where, if the object exists, the JSON object will have the requested object as its root value
    pub(crate) fn get_object_from_array(self, array_index: Field) -> Option<Self> {
        let (entry, valid, entry_index) = self.get_entry_from_array(array_index);
        if valid {
            assert_eq(
                entry.entry_type,
                END_OBJECT_TOKEN as Field,
                "get_object_from_array: entry exists but is not an object!",
            );
        }

        let result = self.update_json_object(entry, entry_index);

        if valid {
            Option::some(result)
        } else {
            Option::none()
        }
    }

    /// if the root JSON is an array, extract an object given by the position of the target in the source array
    ///
    /// will revert if the object does not exist
    pub(crate) fn get_object_from_array_unchecked(self, array_index: Field) -> Self {
        let result = self.get_object_from_array(array_index);
        result.expect(f"array index out of bounds")
    }
}

#[test]
fn test_object() {
    let text = "{ \"foo\": [ [1,{ \"bartholomew tony Harrison III\": { \"hello\": \"world\" }},3], [[3,4]], [[]], [], { \"bar\": [\"b\", \"a\", \"z\" ]} ]}";

    let mut json: JSON<123, 7, 60, 60, 2> = JSON::parse_json_from_string(text);

    let first = json.get_array_unchecked("foo".as_bytes());
    assert(first.get_length() == 5);

    let A = first.get_array_from_array_unchecked(0);
    assert(A.get_length() == 3);

    let B = A.get_object_from_array_unchecked(1);
    let B_alt = A.get_object_from_array(1);
    assert(B == B_alt.unwrap());

    let C = B.get_object_unchecked("bartholomew tony Harrison III".as_bytes());
    assert_eq(JSONEntry::from(C.json_entries_packed[C.root_index_in_transcript]).num_children, 1);

    let not_real = B.get_object("bartholomew tony Harrison IV".as_bytes());
    assert(not_real.is_some() == false);

    let C = B.get_object_unchecked(BoundedVec::from_parts_unchecked(
        "bartholomew tony Harrison III".as_bytes(),
        29,
    ));
    assert_eq(JSONEntry::from(C.json_entries_packed[C.root_index_in_transcript]).num_children, 1);

    let C = B.get_object(BoundedVec::from_parts_unchecked(
        "bartholomew tony Harrison III".as_bytes(),
        28,
    ));
    assert(C.is_some() == false);

    let C = B.get_object(BoundedVec::from_parts_unchecked(
        "bartholomew tony Harrison IIIekurfgaeoiurh".as_bytes(),
        29,
    ));
    assert(C.is_some() == true);

    let second = first.get_object_from_array_unchecked(4);

    let third = second.get_array_unchecked("bar".as_bytes());

    let E: BoundedVec<u8, 1> = third.get_string_from_array_unchecked(0);
    let F: BoundedVec<u8, 1> = third.get_string_from_array_unchecked(1);
    let G: BoundedVec<u8, 1> = third.get_string_from_array_unchecked(2);
    assert(E.storage() == "b".as_bytes());
    assert(F.storage() == "a".as_bytes());
    assert(G.storage() == "z".as_bytes());
}
