use crate::enums::Token::NUMERIC_TOKEN;
use crate::getters::KeyHashable;
use crate::json::JSON;
use crate::json_tables::ASCII_TO_NUMBER;
use crate::utils::cast_num_to_u32;

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
    parsed_number /= NUMBER_OFFSET_SHIFT[cast_num_to_u32(json_length)];
    parsed_number as u64
}

/// getter methods for extracting numeric values out of a JSON struct
///
/// numeric values must fit into a `u64` type.
/// decimal values and scientific notation are not yet supported
impl<let NumBytes: u32, let NumPackedFields: u32, let MaxNumTokens: u32, let MaxNumValues: u32, let MaxKeyFields: u32> JSON<NumBytes, NumPackedFields, MaxNumTokens, MaxNumValues, MaxKeyFields> {

    /// if the root JSON is an object, extract a numeric value given by `key`
    ///
    /// returns an Option<u64> which will be null if the key does not exist
    pub(crate) fn get_number<K>(self, key: K) -> Option<u64>
    where
        K: KeyHashable,
    {
        let (exists, entry, _) = self.get_json_entry(key);
        assert(
            (entry.entry_type - NUMERIC_TOKEN as Field) * exists as Field == 0,
            "get_number: entry exists but is not a number!",
        );
        let mut parsed_string: [u8; U64_LENGTH_AS_BASE10_STRING] = self.extract_string_entry(entry);

        if exists {
            Option::some(extract_number_from_array(parsed_string, entry.json_length))
        } else {
            Option::none()
        }
    }

    /// if the root JSON is an object, extract a u64 value given by `key`
    ///
    /// will revert if the number does not exist
    pub(crate) fn get_number_unchecked<K>(self, key: K) -> u64
    where
        K: KeyHashable,
    {
        let entry = self.get_json_entry_unchecked(key);
        assert(
            entry.entry_type == NUMERIC_TOKEN as Field,
            "get_number_unchecked: entry exists but is not a number!",
        );
        let mut parsed_string: [u8; U64_LENGTH_AS_BASE10_STRING] = self.extract_string_entry(entry);

        extract_number_from_array(parsed_string, entry.json_length)
    }

    /// if the root JSON is an array, extract a numeric value given by the position of the target in the source array
    ///
    /// returns an Option<u64> which will be null if the number does not exist
    pub fn get_number_from_array(self, array_index: Field) -> Option<u64> {
        let (entry, valid, _) = self.get_entry_from_array(array_index);
        if valid {
            assert_eq(
                entry.entry_type,
                NUMERIC_TOKEN as Field,
                "get_number: entry exists but is not a number!",
            );
        }

        let mut parsed_string: [u8; U64_LENGTH_AS_BASE10_STRING] = self.extract_string_entry(entry);
        let result = extract_number_from_array(parsed_string, entry.json_length);

        if valid {
            Option::some(result)
        } else {
            Option::none()
        }
    }

    /// if the root JSON is an array, extract a numeric value given by the position of the target in the source array
    ///
    /// will revert if the number does not exist
    pub fn get_number_from_array_unchecked(self, array_index: Field) -> u64 {
        let result = self.get_number_from_array(array_index);
        result.expect(f"array index out of bounds")
    }
}
