use crate::_comparison_tools::lt::lt_field_16_bit;
use crate::enums::Layer::ARRAY_LAYER;
use crate::enums::Token::STRING_TOKEN;
use crate::json::JSON;
use crate::json::JSONValue;
use crate::json_entry::JSONEntry;
use crate::json_tables::{
    ESCAPE_SEQUENCE_END_CHARS, ESCAPE_SEQUENCE_REPLACEMENT, ESCAPE_SEQUENCE_START_CHARS,
};
use crate::utils::cast_num_to_u32;

fn process_escape_sequences<let N: u32>(input: BoundedVec<u8, N>) -> BoundedVec<u8, N> {
    let string = input.storage();
    let mut result: [u8; N] = [0; N];
    let mut result_ptr = 0;
    let mut character = string[0];
    let mut skip = 0;
    let mut cached_byte: Field = 0;
    for i in 1..N {
        let next_character = string[i];
        let escape_sequence_start_candidate = ESCAPE_SEQUENCE_START_CHARS[character as u32];
        let escape_sequence_end_candidate = ESCAPE_SEQUENCE_END_CHARS[next_character as u32];
        let escape_sequence_replacement_candidate =
            ESCAPE_SEQUENCE_REPLACEMENT[next_character as u32];
        let mut is_escape_sequence =
            (escape_sequence_start_candidate & escape_sequence_end_candidate) as Field;
        is_escape_sequence = is_escape_sequence * (1 - skip);
        let mut written_byte = is_escape_sequence * escape_sequence_replacement_candidate as Field
            + (1 - is_escape_sequence) * character as Field;

        written_byte = written_byte * (1 - skip) + cached_byte * skip;
        written_byte.assert_max_bit_size::<8>();
        let written_byte_u8 = written_byte as u8;

        result[result_ptr] = written_byte_u8;
        result_ptr += cast_num_to_u32(1 - is_escape_sequence);
        cached_byte = written_byte;
        skip = is_escape_sequence;
        character = next_character;
    }

    let written_byte: Field = character as Field * (1 - skip) + cached_byte * skip;
    written_byte.assert_max_bit_size::<8>();
    let written_byte_u8 = written_byte as u8;
    result[result_ptr] = written_byte_u8;
    result_ptr += 1;

    let num_removed_chars = N - result_ptr;
    let new_length = input.len() - num_removed_chars;
    BoundedVec::from_parts_unchecked(result, new_length as u32)
}

#[test]
fn test_process_escape_sequence_2() {
    let text = BoundedVec::from_array("\\\"Ade\\nel Solangi\\\"".as_bytes());
    let mut expected = text;
    expected = BoundedVec::from_array("\"Ade\nel Solangi\"".as_bytes());
    let result: BoundedVec<u8, 19> = process_escape_sequences(text);
    assert(result == expected);
}
#[test]
fn test_process_escape_sequence() {
    // end with escape sequence
    {
        let text = BoundedVec::from_array("the qulick brown fox said \\\"why hello there\\\"  \\\\"
            .as_bytes());

        let expected: BoundedVec<u8, 49> = BoundedVec::from_array(
            "the qulick brown fox said \"why hello there\"  \\".as_bytes(),
        );

        let result: BoundedVec<u8, 49> = process_escape_sequences(text);

        assert(result == expected);
    }
    // end without escape sequence
    {
        let text = BoundedVec::from_array(
            "\\\"he qulick brown fox said \\n \\r \\\"why hello there\\\"  \\\\".as_bytes(),
        );

        let expected: BoundedVec<u8, 56> = BoundedVec::from_array(
            "\"he qulick brown fox said \n \r \"why hello there\"  \\".as_bytes(),
        );

        let result = process_escape_sequences(text);

        assert(result == expected);
    }
}

/**
 * @brief getter methods for extracting string values out of a JSON struct
 * @note returned strings will have escape sequences converted into the relevant ASCII characters.
 *       If you want to avoid this, use `get_value` instead of `get_string`
 **/
impl<let NumBytes: u32, let NumPackedFields: u32, let MaxNumTokens: u32, let MaxNumValues: u32, let MaxKeyFields: u32> JSON<NumBytes, NumPackedFields, MaxNumTokens, MaxNumValues, MaxKeyFields> {

    /**
     * @brief if the root JSON is an object, extract a string given by `key`
     * @description returns an Option<BoundedVec> which will be null if the key does not exist
     * @note the `StringBytes` parameter defines the maximum allowable length of the returned string
     **/
    pub(crate) fn get_string<let KeyBytes: u32, let StringBytes: u32>(
        self,
        key: [u8; KeyBytes],
    ) -> Option<BoundedVec<u8, StringBytes>> {
        let (exists, entry) = self.get_json_entry(key);
        assert(
            (entry.entry_type - STRING_TOKEN as Field) * exists as Field == 0,
            "get_string: entry exists but is not a string!",
        );
        let mut parsed_string: [u8; StringBytes] = self.extract_string_entry(entry);

        let parsed_string: BoundedVec<u8, StringBytes> = process_escape_sequences(
            BoundedVec::from_parts_unchecked(parsed_string, entry.json_length as u32),
        );

        if exists {
            Option::some(parsed_string)
        } else {
            Option::none()
        }
    }

    /**
     * @brief if the root JSON is an object, extract a string given by `key`
     * @description will revert if the string does not exist
     * @note the `StringBytes` parameter defines the maximum allowable length of the returned string
     **/
    pub(crate) fn get_string_unchecked<let KeyBytes: u32, let StringBytes: u32>(
        self,
        key: [u8; KeyBytes],
    ) -> BoundedVec<u8, StringBytes> {
        let entry = self.get_json_entry_unchecked(key);
        assert(
            entry.entry_type == STRING_TOKEN as Field,
            "get_string_unchecked: entry exists but is not a string!",
        );
        let parsed_string = BoundedVec::from_parts_unchecked(
            self.extract_string_entry(entry),
            entry.json_length as u32,
        );
        process_escape_sequences(parsed_string)
    }

    /**
     * @brief same as `get_string` for where the key length may be less than KeyBytes
     **/
    pub(crate) fn get_string_var<let KeyBytes: u32, let StringBytes: u32>(
        self,
        key: BoundedVec<u8, KeyBytes>,
    ) -> Option<BoundedVec<u8, StringBytes>> {
        let (exists, entry) = self.get_json_entry_var(key);
        assert(
            (entry.entry_type - STRING_TOKEN as Field) * exists as Field == 0,
            "get_string: entry exists but is not a string!",
        );
        let mut parsed_string: [u8; StringBytes] = self.extract_string_entry(entry);
        let parsed_string: BoundedVec<u8, StringBytes> = process_escape_sequences(
            BoundedVec::from_parts_unchecked(parsed_string, entry.json_length as u32),
        );

        if exists {
            Option::some(parsed_string)
        } else {
            Option::none()
        }
    }

    /**
     * @brief same as `get_string_unchecked` for where the key length may be less than KeyBytes
     **/
    pub(crate) fn get_string_unchecked_var<let KeyBytes: u32, let StringBytes: u32>(
        self,
        key: BoundedVec<u8, KeyBytes>,
    ) -> BoundedVec<u8, StringBytes> {
        let entry = self.get_json_entry_unchecked_var(key);
        assert(
            entry.entry_type == STRING_TOKEN as Field,
            "get_string_unchecked: entry exists but is not a string!",
        );
        let parsed_string = BoundedVec::from_parts_unchecked(
            self.extract_string_entry(entry),
            entry.json_length as u32,
        );
        process_escape_sequences(parsed_string)
    }

    /**
     * @brief if the root JSON is an array, extract a string given by the position of the target in the source array
     * @description returns an Option<BoundedVec> which will be null if the string does not exist
     **/
    pub(crate) fn get_string_from_array<let StringBytes: u32>(
        self,
        array_index: Field,
    ) -> Option<BoundedVec<u8, StringBytes>> {
        assert(
            self.layer_type_of_root == ARRAY_LAYER,
            "can only acceess array elements from array",
        );

        let parent_entry: JSONEntry =
            self.json_entries_packed[self.root_index_in_transcript].into();

        let valid = lt_field_16_bit(array_index, parent_entry.num_children);
        let entry_index = (parent_entry.child_pointer + array_index) * valid as Field;

        let entry: JSONEntry = self.json_entries_packed[cast_num_to_u32(entry_index)].into();
        if !valid {
            assert_eq(
                entry.entry_type,
                STRING_TOKEN as Field,
                "get_array_element_as_string: entry exists but is not a string!",
            );
        }

        let mut parsed_string: [u8; StringBytes] = self.extract_string_entry(entry);
        let parsed_string: BoundedVec<u8, StringBytes> = process_escape_sequences(
            BoundedVec::from_parts_unchecked(parsed_string, entry.json_length as u32),
        );

        if valid {
            Option::some(parsed_string)
        } else {
            Option::none()
        }
    }

    /**
     * @brief if the root JSON is an array, extract a string given by the position of the target in the source array
     * @description will revert if the string does not exist
     **/
    pub(crate) fn get_string_from_array_unchecked<let StringBytes: u32>(
        self,
        array_index: Field,
    ) -> BoundedVec<u8, StringBytes> {
        assert(
            self.layer_type_of_root == ARRAY_LAYER,
            "can only acceess array elements from array",
        );

        let parent_entry: JSONEntry =
            self.json_entries_packed[self.root_index_in_transcript].into();

        let valid = lt_field_16_bit(array_index, parent_entry.num_children);
        assert(valid, "array overflow");
        let entry_index = (parent_entry.child_pointer + array_index);

        let entry: JSONEntry = self.json_entries_packed[cast_num_to_u32(entry_index)].into();

        assert(
            entry.entry_type == STRING_TOKEN as Field,
            "get_string_from_array_unchecked: entry exists but is not a string!",
        );

        let mut parsed_string: [u8; StringBytes] = self.extract_string_entry(entry);
        process_escape_sequences(BoundedVec::from_parts_unchecked(
            parsed_string,
            entry.json_length as u32,
        ))
    }

    /**
     * @brief if the root JSON is an object, get a nested string out of the JSON, which may be several keys deep
     **/
    pub(crate) fn get_string_from_path<let KeyBytes: u32, let StringBytes: u32, let PathDepth: u32>(
        self,
        keys: [BoundedVec<u8, KeyBytes>; PathDepth],
    ) -> Option<BoundedVec<u8, StringBytes>> {
        let mut target = self;
        let mut valid = true;
        for i in 0..PathDepth - 1 {
            let child = self.get_object_var(keys[i]);

            target = child.unwrap_unchecked();
            valid = valid & child.is_some();
        }

        let mut final = target.get_string_var(keys[PathDepth - 1]);
        if final.is_some() & valid {
            final
        } else {
            Option::none()
        }
    }

    /**
     * @brief if the root JSON is an object, extract a JSONValue given by `key`
     * @description returns an Option<JSONValue> which will be null if the key does not exist
     * @note the `StringBytes` parameter defines the maximum allowable length of the returned value
     **/
    pub(crate) fn get_value<let KeyBytes: u32, let StringBytes: u32>(
        self,
        key: [u8; KeyBytes],
    ) -> Option<JSONValue<StringBytes>> {
        let (exists, entry) = self.get_json_entry(key);
        let mut parsed_string: [u8; StringBytes] = self.extract_string_entry(entry);

        let parsed_string: BoundedVec<u8, StringBytes> =
            BoundedVec::from_parts_unchecked(parsed_string, entry.json_length as u32);

        if exists {
            Option::some(
                JSONValue { value: parsed_string, value_type: entry.entry_type },
            )
        } else {
            Option::none()
        }
    }

    /**
     * @brief if the root JSON is an object, extract a JSONValue given by `key`
     * @description will revert if the string does not exist
     * @note the `StringBytes` parameter defines the maximum allowable length of the returned value
     **/
    pub(crate) fn get_value_unchecked<let KeyBytes: u32, let StringBytes: u32>(
        self,
        key: [u8; KeyBytes],
    ) -> JSONValue<StringBytes> {
        let entry = self.get_json_entry_unchecked(key);
        JSONValue {
            value: BoundedVec::from_parts_unchecked(
                self.extract_string_entry(entry),
                entry.json_length as u32,
            ),
            value_type: entry.entry_type,
        }
    }

    /**
     * @brief same as `get_value` for where the key length may be less than KeyBytes
     **/
    pub(crate) fn get_value_var<let KeyBytes: u32, let StringBytes: u32>(
        self,
        key: BoundedVec<u8, KeyBytes>,
    ) -> Option<JSONValue<StringBytes>> {
        let (exists, entry) = self.get_json_entry_var(key);
        let mut parsed_string: [u8; StringBytes] = self.extract_string_entry(entry);

        let parsed_string: BoundedVec<u8, StringBytes> =
            BoundedVec::from_parts_unchecked(parsed_string, entry.json_length as u32);

        if exists {
            Option::some(
                JSONValue { value: parsed_string, value_type: entry.entry_type },
            )
        } else {
            Option::none()
        }
    }

    /**
     * @brief same as `get_value_unchecked` for where the key length may be less than KeyBytes
     **/
    pub(crate) fn get_value_unchecked_var<let KeyBytes: u32, let StringBytes: u32>(
        self,
        key: BoundedVec<u8, KeyBytes>,
    ) -> JSONValue<StringBytes> {
        let entry = self.get_json_entry_unchecked_var(key);
        JSONValue {
            value: BoundedVec::from_parts_unchecked(
                self.extract_string_entry(entry),
                entry.json_length as u32,
            ),
            value_type: entry.entry_type,
        }
    }

    /**
     * @brief if the root JSON is an array, extract a value given by the position of the target in the source array
     * @description returns an Option<BoundedVec> which will be null if the value does not exist
     **/
    pub(crate) fn get_value_from_array<let StringBytes: u32>(
        self,
        array_index: Field,
    ) -> Option<JSONValue<StringBytes>> {
        assert(
            self.layer_type_of_root == ARRAY_LAYER,
            "can only acceess array elements from array",
        );

        let parent_entry: JSONEntry =
            self.json_entries_packed[self.root_index_in_transcript].into();

        let valid = lt_field_16_bit(array_index, parent_entry.num_children);
        let entry_index = (parent_entry.child_pointer + array_index) * valid as Field;

        let entry: JSONEntry = self.json_entries_packed[cast_num_to_u32(entry_index)].into();
        if !valid {
            assert_eq(
                entry.entry_type,
                STRING_TOKEN as Field,
                "get_array_element_as_string: entry exists but is not a string!",
            );
        }

        let mut parsed_string: [u8; StringBytes] = self.extract_string_entry(entry);

        if valid {
            Option::some(
                JSONValue {
                    value: BoundedVec::from_parts_unchecked(
                        parsed_string,
                        entry.json_length as u32,
                    ),
                    value_type: entry.entry_type,
                },
            )
        } else {
            Option::none()
        }
    }

    /**
     * @brief if the root JSON is an array, extract a value given by the position of the target in the source array
     * @description will revert if the value does not exist
     **/
    pub(crate) fn get_value_from_array_unchecked<let StringBytes: u32>(
        self,
        array_index: Field,
    ) -> JSONValue<StringBytes> {
        assert(
            self.layer_type_of_root == ARRAY_LAYER,
            "can only acceess array elements from array",
        );

        let parent_entry: JSONEntry =
            self.json_entries_packed[self.root_index_in_transcript].into();

        let valid = lt_field_16_bit(array_index, parent_entry.num_children);
        assert(valid, "array overflow");
        let entry_index = (parent_entry.child_pointer + array_index);

        let entry: JSONEntry = self.json_entries_packed[cast_num_to_u32(entry_index)].into();

        assert(
            entry.entry_type == STRING_TOKEN as Field,
            "get_string_from_array_unchecked: entry exists but is not a string!",
        );

        let mut parsed_string: [u8; StringBytes] = self.extract_string_entry(entry);
        JSONValue {
            value: BoundedVec::from_parts_unchecked(parsed_string, entry.json_length as u32),
            value_type: entry.entry_type,
        }
    }

    /**
     * @brief if the root JSON is an object, get a nested value out of the JSON, which may be several keys deep
     **/
    pub(crate) fn get_value_from_path<let KeyBytes: u32, let StringBytes: u32, let PathDepth: u32>(
        self,
        keys: [BoundedVec<u8, KeyBytes>; PathDepth],
    ) -> Option<JSONValue<StringBytes>> {
        let mut target = self;
        let mut valid = true;
        for i in 0..PathDepth - 1 {
            let child = self.get_object_var(keys[i]);

            target = child.unwrap_unchecked();
            valid = valid & child.is_some();
        }

        let mut final = target.get_value_var(keys[PathDepth - 1]);
        if final.is_some() & valid {
            final
        } else {
            Option::none()
        }
    }
}
