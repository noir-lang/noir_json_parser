use crate::_comparison_tools::lt::lt_field_16_bit;
use crate::enums::Layer::{ARRAY_LAYER, OBJECT_LAYER};
use crate::enums::Token::END_ARRAY_TOKEN;
use crate::json::JSON;
use crate::json::JSONValue;
use crate::json_entry::JSONEntry;

/**
 * @brief getter methods for extracting array types out of a JSON struct
 **/
impl<let NumBytes: u32, let NumPackedFields: u32, let MaxNumTokens: u32, let MaxNumValues: u32, let MaxKeyFields: u32> JSON<NumBytes, NumPackedFields, MaxNumTokens, MaxNumValues, MaxKeyFields> {

    /**
     * @brief if the root JSON is an array, return its length
     **/
    pub(crate) fn get_length(self) -> u32 {
        assert(self.layer_type_of_root == ARRAY_LAYER, "can only get length of an array type");
        let parent_entry: JSONEntry =
            self.json_entries_packed[self.root_index_in_transcript].into();
        parent_entry.num_children as u32
    }

    /**
     * @brief if the root JSON is an object, extract an array given by `key`
     * @description returns an Option<JSON> where, if the array exists, the JSON object will have the requested array as its root value  
     **/
    pub(crate) fn get_array<let KeyBytes: u32>(self, key: [u8; KeyBytes]) -> Option<Self> {
        assert(self.layer_type_of_root != ARRAY_LAYER, "cannot extract array elements via a key");
        let (exists, key_index) = self.key_exists_impl(key);
        let entry: JSONEntry = self.json_entries_packed[key_index].into();
        assert(
            (entry.entry_type - END_ARRAY_TOKEN) * exists as Field == 0,
            "key does not describe an object",
        );

        let mut r = self;
        r.layer_type_of_root = entry.parent_index;
        r.root_id = entry.id;
        r.layer_type_of_root = ARRAY_LAYER;
        r.root_index_in_transcript = key_index;

        if exists {
            Option::some(r)
        } else {
            Option::none()
        }
    }

    /**
     * @brief if the root JSON is an object, extract an array given by `key`
     * @description will revert if the array does not exist
     **/
    pub(crate) fn get_array_unchecked<let KeyBytes: u32>(self, key: [u8; KeyBytes]) -> Self {
        assert(self.layer_type_of_root != ARRAY_LAYER, "cannot extract array elements via a key");

        let (entry, key_index) = self.get_json_entry_unchecked_with_key_index(key);
        assert(entry.entry_type == END_ARRAY_TOKEN, "key does not describe an object");

        let mut r = self;
        r.layer_type_of_root = entry.parent_index;
        r.root_id = entry.id;
        r.layer_type_of_root = ARRAY_LAYER;
        r.root_index_in_transcript = key_index;

        r
    }

    /**
     * @brief same as `get_array` for where the key length may be less than KeyBytes
     **/
    pub(crate) fn get_array_var<let KeyBytes: u32>(
        self,
        key: BoundedVec<u8, KeyBytes>,
    ) -> Option<Self> {
        assert(self.layer_type_of_root != ARRAY_LAYER, "cannot extract array elements via a key");
        let (exists, key_index) = self.key_exists_impl_var(key);
        let entry: JSONEntry = self.json_entries_packed[key_index].into();
        // TODO: ADD A layer_context VARIABLE INTO JSON WHICH DESCRIBES WHETHER WE ARE AN OBJECT, ARRAY OR SINGLE VALUE
        assert(
            (entry.entry_type - END_ARRAY_TOKEN) * exists as Field == 0,
            "key does not describe an object",
        );

        let mut r = self;
        r.layer_type_of_root = entry.parent_index;
        r.root_id = entry.id;
        r.layer_type_of_root = ARRAY_LAYER;
        r.root_index_in_transcript = key_index;

        if exists {
            Option::some(r)
        } else {
            Option::none()
        }
    }

    /**
     * @brief same as `get_array_unchecked` for where the key length may be less than KeyBytes
     **/
    pub(crate) fn get_array_unchecked_var<let KeyBytes: u32>(
        self,
        key: BoundedVec<u8, KeyBytes>,
    ) -> Self {
        assert(self.layer_type_of_root != ARRAY_LAYER, "cannot extract array elements via a key");

        let (entry, key_index) = self.get_json_entry_unchecked_with_key_index_var(key);
        assert(entry.entry_type == END_ARRAY_TOKEN, "key does not describe an object");

        let mut r = self;
        r.layer_type_of_root = entry.parent_index;
        r.root_id = entry.id;
        r.layer_type_of_root = ARRAY_LAYER;
        r.root_index_in_transcript = key_index;

        r
    }

    /**
     * @brief if the root JSON is an array, extract an array given by the position of the target in the source array
     * @description returns an Option<JSON> where, if the array exists, the JSON object will have the requested array as its root value  
     **/
    pub(crate) fn get_array_from_array(self, array_index: Field) -> Option<Self> {
        assert(
            self.layer_type_of_root == ARRAY_LAYER,
            "can only acceess array elements from array",
        );

        let parent_entry: JSONEntry =
            self.json_entries_packed[self.root_index_in_transcript].into();
        let valid = lt_field_16_bit(array_index, parent_entry.num_children);
        let entry_index = (parent_entry.child_pointer + array_index) * valid as Field;

        let entry: JSONEntry = self.json_entries_packed[entry_index].into();
        assert(
            (entry.entry_type - END_ARRAY_TOKEN) * valid as Field == 0,
            "get_object_from_array: entry exists but is not an object!",
        );

        let mut r = self;
        r.layer_type_of_root = entry.parent_index;
        r.root_id = entry.id;
        r.layer_type_of_root = ARRAY_LAYER;
        r.root_index_in_transcript = entry_index;

        if valid {
            Option::some(r)
        } else {
            Option::none()
        }
    }

    /**
     * @brief if the root JSON is an array, extract an array given by the position of the target in the source array
     * @description will revert if the array does not exist
     **/
    pub(crate) fn get_array_from_array_unchecked(self, array_index: Field) -> Self {
        assert(
            self.layer_type_of_root == ARRAY_LAYER,
            "can only acceess array elements from array",
        );

        let parent_entry: JSONEntry =
            self.json_entries_packed[self.root_index_in_transcript].into();
        let valid = lt_field_16_bit(array_index, parent_entry.num_children);
        assert(valid, "array overflow");
        let entry_index = (parent_entry.child_pointer + array_index);
        let entry: JSONEntry = self.json_entries_packed[entry_index].into();
        assert(
            entry.entry_type == END_ARRAY_TOKEN,
            "get_array_from_array_unchecked: entry exists but is not an array!",
        );

        let mut r = self;
        r.layer_type_of_root = entry.parent_index;
        r.root_id = entry.id;
        r.layer_type_of_root = ARRAY_LAYER;
        r.root_index_in_transcript = entry_index;
        r
    }

    /**
     * @brief if the root is an array, map over the array values, applying `fn f` to each value
     **/
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
            let child_entry: JSONEntry = self.json_entries_packed[entry_index].into();
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
