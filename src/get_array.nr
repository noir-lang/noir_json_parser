use crate::_comparison_tools::lt::lt_field_16_bit;
use crate::enums::Layer::ARRAY_LAYER;
use crate::enums::Token::END_ARRAY_TOKEN;
use crate::getters::KeyHashable;
use crate::json::JSON;
use crate::json::JSONValue;
use crate::json_entry::JSONEntry;
use crate::utils::cast_num_to_u32;

/// getter methods for extracting array types out of a JSON struct
impl<let NumBytes: u32, let NumPackedFields: u32, let MaxNumTokens: u32, let MaxNumValues: u32, let MaxKeyFields: u32> JSON<NumBytes, NumPackedFields, MaxNumTokens, MaxNumValues, MaxKeyFields> {
    /// Updates the JSON object to point to a specific array entry
    pub(crate) fn update_json_array(mut self, entry: JSONEntry, key_index: u32) -> Self {
        self.root_id = entry.id;
        self.layer_type_of_root = ARRAY_LAYER;
        self.root_index_in_transcript = key_index;
        self
    }
    /// if the root JSON is an array, return its length
    pub(crate) fn get_length(self) -> u32 {
        assert(self.layer_type_of_root == ARRAY_LAYER, "can only get length of an array type");
        let parent_entry: JSONEntry =
            self.json_entries_packed[self.root_index_in_transcript].into();
        parent_entry.num_children as u32
    }

    /// if the root JSON is an object, extract an array given by `key`
    ///
    /// returns an Option<JSON> where, if the array exists, the JSON object will have the requested array as its root value
    pub(crate) fn get_array<K>(self, key: K) -> Option<Self>
    where
        K: KeyHashable,
    {
        let (exists, entry, key_index) = self.get_json_entry(key);
        if !exists {
            assert_eq(
                entry.entry_type,
                END_ARRAY_TOKEN as Field,
                "key does not describe an object",
            );
        }

        let result = self.update_json_array(entry, key_index);

        if exists {
            Option::some(result)
        } else {
            Option::none()
        }
    }

    /// if the root JSON is an object, extract an array given by `key`
    ///
    /// will revert if the array does not exist
    pub(crate) fn get_array_unchecked<K>(self, key: K) -> Self
    where
        K: KeyHashable,
    {
        assert(self.layer_type_of_root != ARRAY_LAYER, "cannot extract array elements via a key");

        let (entry, key_index) = self.get_json_entry_unchecked_with_key_index(key);
        assert(entry.entry_type == END_ARRAY_TOKEN as Field, "key does not describe an object");

        self.update_json_array(entry, key_index)
    }

    /// if the root JSON is an array, extract an array given by the position of the target in the source array
    ///
    /// returns an Option<JSON> where, if the array exists, the JSON object will have the requested array as its root value
    pub(crate) fn get_array_from_array(self, array_index: Field) -> Option<Self> {
        let (entry, valid, entry_index) = self.get_entry_from_array(array_index);
        if valid {
            assert_eq(
                entry.entry_type,
                END_ARRAY_TOKEN as Field,
                "get_object_from_array: entry exists but is not an object!",
            );
        }

        let result = self.update_json_array(entry, entry_index);

        if valid {
            Option::some(result)
        } else {
            Option::none()
        }
    }

    /// if the root JSON is an array, extract an array given by the position of the target in the source array
    ///
    /// will revert if the array does not exist
    pub(crate) fn get_array_from_array_unchecked(self, array_index: Field) -> Self {
        let result = self.get_array_from_array(array_index);
        result.expect(f"array index out of bounds")
    }

    /// if the root is an array, map over the array values, applying `fn f` to each value
    fn map<U, let MaxElements: u32, let MaxElementBytes: u32>(
        self,
        f: fn(JSONValue<MaxElementBytes>) -> U,
    ) -> [U; MaxElements]
    where
        U: std::default::Default,
    {
        assert(self.layer_type_of_root == ARRAY_LAYER, "can only call map on an array");

        let entry: JSONEntry = self.json_entries_packed[self.root_index_in_transcript].into();
        let num_children = entry.num_children;
        let mut r: [U; MaxElements] = [U::default(); MaxElements];

        for i in 0..MaxElements {
            let valid = lt_field_16_bit(i as Field, num_children);
            let entry_index = (entry.child_pointer + i as Field) * valid as Field;
            let child_entry: JSONEntry =
                self.json_entries_packed[cast_num_to_u32(entry_index)].into();
            let mut parsed_string: [u8; MaxElementBytes] = [0; MaxElementBytes];
            for j in 0..MaxElementBytes {
                let byte_valid = lt_field_16_bit(j as Field, child_entry.json_length);
                // n.b. conditionally setting index to 0 can be removed if we ensure json is padded such that this index does not overflow json bytes
                let byte = self.json[cast_num_to_u32(
                    child_entry.json_pointer + i as Field * valid as Field,
                )];
                // TODO improve efficiency? measure...
                if (byte_valid) {
                    parsed_string[i] = byte;
                }
            }

            if (valid) {
                r[i] = f(
                    JSONValue {
                        value: BoundedVec::from_parts_unchecked(
                            parsed_string,
                            child_entry.json_length as u32,
                        ),
                        value_type: child_entry.entry_type,
                    },
                );
            }
        }
        r
    }
}

#[test]
fn test_array() {
    let text = "{ \"foo\": [ [1,2,3], [[3,4]], [[]], [], { \"bar\": [\"b\", \"a\", \"z\" ]} ]}";

    let mut json: JSON<_, 7, 60, 60, 2> = JSON::parse_json_from_string(text);

    let first = json.get_array_unchecked("foo".as_bytes());
    assert(first.get_length() == 5);

    let A: JSON<68, 7, 60, 60, 2> = first.get_array_from_array_unchecked(0);
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

    let E_A = E.get_array_unchecked("bar".as_bytes());
    assert(E_A.get_length() == 3);
}
