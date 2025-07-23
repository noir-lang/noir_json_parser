use crate::_comparison_tools::lt::lt_field_16_bit;
use crate::enums::Layer::ARRAY_LAYER;
use crate::enums::Token::NUMERIC_TOKEN;
use crate::json::JSON;
use crate::json_entry::JSONEntry;
use crate::json_tables::ASCII_TO_NUMBER;

global U64_LENGTH_AS_BASE10_STRING: u32 = 20;
global NUMBER_OFFSET_SHIFT: [Field; 21] = [
    100000000000000000000,
    10000000000000000000,
    1000000000000000000,
    100000000000000000,
    10000000000000000,
    1000000000000000,
    100000000000000,
    10000000000000,
    1000000000000,
    100000000000,
    10000000000,
    1000000000,
    100000000,
    10000000,
    1000000,
    100000,
    10000,
    1000,
    100,
    10,
    1,
];

fn extract_number_from_array(arr: [u8; U64_LENGTH_AS_BASE10_STRING], json_length: Field) -> u64 {
    let mut parsed_number: Field = 0;
    for i in 0..U64_LENGTH_AS_BASE10_STRING {
        parsed_number *= 10;

        let value = ASCII_TO_NUMBER[arr[i] as u32] as Field;
        parsed_number += value;
    }
    json_length.assert_max_bit_size::<32>();
    parsed_number /= NUMBER_OFFSET_SHIFT[json_length as u32];
    parsed_number as u64
}

/**
 * @brief getter methods for extracting numeric values out of a JSON struct
 * @note numeric values must fit into a `u64` type.
 *       decimal values and scientific notation are not yet supported
 **/
impl<let NumBytes: u32, let NumPackedFields: u32, let MaxNumTokens: u32, let MaxNumValues: u32, let MaxKeyFields: u32> JSON<NumBytes, NumPackedFields, MaxNumTokens, MaxNumValues, MaxKeyFields> {

    /**
     * @brief if the root JSON is an object, extract a numeric value given by `key`
     * @description returns an Option<u64> which will be null if the key does not exist
     **/
    fn get_number<let KeyBytes: u32>(self, key: [u8; KeyBytes]) -> Option<u64> {
        let (exists, entry) = self.get_json_entry(key);
        assert(
            (entry.entry_type - NUMERIC_TOKEN) * exists as u32 == 0,
            "get_number: entry exists but is not a number!",
        );
        let mut parsed_string: [u8; U64_LENGTH_AS_BASE10_STRING] = self.extract_string_entry(entry);

        if exists {
            Option::some(extract_number_from_array(parsed_string, entry.json_length))
        } else {
            Option::none()
        }
    }

    /**
     * @brief if the root JSON is an object, extract a u64 value given by `key`
     * @description will revert if the number does not exist
     **/
    fn get_number_unchecked<let KeyBytes: u32>(self, key: [u8; KeyBytes]) -> u64 {
        let entry = self.get_json_entry_unchecked(key);
        assert(
            entry.entry_type == NUMERIC_TOKEN,
            "get_number_unchecked: entry exists but is not a number!",
        );
        let mut parsed_string: [u8; U64_LENGTH_AS_BASE10_STRING] = self.extract_string_entry(entry);

        extract_number_from_array(parsed_string, entry.json_length)
    }

    /**
     * @brief same as `get_number` for where the key length may be less than KeyBytes
     **/
    fn get_number_var<let KeyBytes: u32>(self, key: BoundedVec<u8, KeyBytes>) -> Option<u64> {
        let (exists, entry) = self.get_json_entry_var(key);
        assert(
            (entry.entry_type - NUMERIC_TOKEN) * exists as u32 == 0,
            "get_number: entry exists but is not a number!",
        );
        let mut parsed_string: [u8; U64_LENGTH_AS_BASE10_STRING] = self.extract_string_entry(entry);

        if exists {
            Option::some(extract_number_from_array(parsed_string, entry.json_length))
        } else {
            Option::none()
        }
    }

    /**
     * @brief same as `get_number_unchecked` for where the key length may be less than KeyBytes
     **/
    fn get_number_unchecked_var<let KeyBytes: u32>(self, key: BoundedVec<u8, KeyBytes>) -> u64 {
        let entry = self.get_json_entry_unchecked_var(key);
        assert(
            entry.entry_type == NUMERIC_TOKEN,
            "get_number_unchecked: entry exists but is not a number!",
        );
        let mut parsed_string: [u8; U64_LENGTH_AS_BASE10_STRING] = self.extract_string_entry(entry);

        extract_number_from_array(parsed_string, entry.json_length)
    }

    /**
     * @brief if the root JSON is an array, extract a numeric value given by the position of the target in the source array
     * @description returns an Option<u64> which will be null if the number does not exist
     **/
    fn get_number_from_array(self, array_index: Field) -> Option<u64> {
        assert(
            self.layer_type_of_root == ARRAY_LAYER,
            "can only acceess array elements from array",
        );

        let parent_entry: JSONEntry =
            self.json_entries_packed[self.root_index_in_transcript].into();

        let valid = lt_field_16_bit(array_index, parent_entry.num_children);
        let entry_index = (parent_entry.child_pointer + array_index) * valid as Field;
        entry_index.assert_max_bit_size::<32>();
        let entry: JSONEntry = self.json_entries_packed[entry_index as u32].into();

        assert(
            (entry.entry_type - NUMERIC_TOKEN) * valid as u32 == 0,
            "get_number: entry exists but is not a number!",
        );

        let mut parsed_string: [u8; U64_LENGTH_AS_BASE10_STRING] = self.extract_string_entry(entry);
        let result = extract_number_from_array(parsed_string, entry.json_length);

        if valid {
            Option::some(result)
        } else {
            Option::none()
        }
    }

    /**
     * @brief if the root JSON is an array, extract a numeric value given by the position of the target in the source array
     * @description will revert if the number does not exist
     **/
    fn get_number_from_array_unchecked(self, array_index: Field) -> u64 {
        assert(
            self.layer_type_of_root == ARRAY_LAYER,
            "can only acceess array elements from array",
        );

        let parent_entry: JSONEntry =
            self.json_entries_packed[self.root_index_in_transcript].into();

        let valid = lt_field_16_bit(array_index, parent_entry.num_children);
        assert(valid, "array overflow");
        let entry_index = (parent_entry.child_pointer + array_index);
        entry_index.assert_max_bit_size::<32>();
        let entry: JSONEntry = self.json_entries_packed[entry_index as u32].into();

        assert(entry.entry_type == NUMERIC_TOKEN, "get_number: entry exists but is not a number!");

        let mut parsed_string: [u8; U64_LENGTH_AS_BASE10_STRING] = self.extract_string_entry(entry);
        extract_number_from_array(parsed_string, entry.json_length)
    }
}
