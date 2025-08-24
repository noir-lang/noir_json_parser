use crate::enums::Token::LITERAL_TOKEN;
use crate::getters::KeyHashable;
use crate::json::JSON;
use crate::utils::cast_num_to_u32;

global MAX_LITERAL_LENGTH_AS_STRING: u32 = 5;
global LITERAL_OFFSET_SHIFT: [Field; 6] =
    [0x10000000000, 0x100000000, 0x1000000, 0x10000, 0x100, 1];

/// a JSON "literal" type has 3 states: "true", "false", "null".
/// As such we can't directly convert to a bool and cover all possible cases
pub struct JSONLiteral {
    pub(crate) value: Field,
}

impl JSONLiteral {
    pub(crate) fn new(is_true: bool, is_false: bool, is_null: bool) -> Self {
        assert(
            is_false as Field + is_null as Field + is_true as Field == 1,
            "parse literal: invalid entry",
        );
        JSONLiteral { value: is_true as Field * 2 + is_null as Field }
    }
    pub(crate) fn is_true(self) -> bool {
        self.value == 2
    }
    pub(crate) fn is_null(self) -> bool {
        self.value == 1
    }
    pub(crate) fn is_false(self) -> bool {
        self.value == 0
    }
    pub(crate) fn to_bool(self) -> bool {
        self.value == 2
    }
}

/// given an input array, return a JSONLiteral depending on whether the array says "true", "false" or "null"
fn extract_literal_from_array(
    arr: [u8; MAX_LITERAL_LENGTH_AS_STRING],
    json_length: Field,
) -> JSONLiteral {
    let false_field = 0x66616c7365;
    let true_field = 0x74727565;
    let null_field = 0x6e756c6c;

    let mut parsed_literal: Field = 0;
    for i in 0..MAX_LITERAL_LENGTH_AS_STRING {
        parsed_literal *= 0x100;

        let value = arr[i] as Field;
        parsed_literal += value;
    }
    parsed_literal /= LITERAL_OFFSET_SHIFT[cast_num_to_u32(json_length)];
    let is_false = parsed_literal == false_field;
    let is_null = parsed_literal == null_field;
    let is_true = parsed_literal == true_field;
    JSONLiteral::new(is_true, is_false, is_null)
}

/// getter methods for extracting literal values out of a JSON struct
impl<let NumBytes: u32, let NumPackedFields: u32, let MaxNumTokens: u32, let MaxNumValues: u32, let MaxKeyFields: u32> JSON<NumBytes, NumPackedFields, MaxNumTokens, MaxNumValues, MaxKeyFields> {

    /// if the root JSON is an object, extract a literal value given by `key`
    ///
    /// returns an Option<JSONLiteral> which will be null if the literal does not exist
    pub(crate) fn get_literal<K>(self, key: K) -> Option<JSONLiteral>
    where
        K: KeyHashable,
    {
        let (exists, entry, _) = self.get_json_entry(key);
        assert(
            (entry.entry_type - LITERAL_TOKEN as Field) * exists as Field == 0,
            "get_literal_var: entry exists but is not a literal!",
        );
        let mut parsed_string: [u8; MAX_LITERAL_LENGTH_AS_STRING] =
            self.extract_string_entry(entry);

        if exists {
            Option::some(extract_literal_from_array(parsed_string, entry.json_length))
        } else {
            Option::none()
        }
    }

    /**
     * @brief same as `get_literal_unchecked` for where the key length may be less than KeyBytes
     **/
    pub(crate) fn get_literal_unchecked<K>(self, key: K) -> JSONLiteral
    where
        K: KeyHashable,
    {
        let entry = self.get_json_entry_unchecked(key);
        assert(
            entry.entry_type == LITERAL_TOKEN as Field,
            "get_literal_unchecked: entry exists but is not a literal!",
        );
        let mut parsed_string: [u8; MAX_LITERAL_LENGTH_AS_STRING] =
            self.extract_string_entry(entry);

        extract_literal_from_array(parsed_string, entry.json_length)
    }

    /// if the root JSON is an array, extract a literal given by the position of the target in the source array
    ///
    /// returns an Option<JSONLiteral> which will be null if the literal does not exist
    pub fn get_literal_from_array(self, array_index: Field) -> Option<JSONLiteral> {
        let (entry, valid, _) = self.get_entry_from_array(array_index);
        if valid {
            assert_eq(
                entry.entry_type,
                LITERAL_TOKEN as Field,
                "get_literal_from_array: entry exists but is not a literal!",
            );
        }

        let mut parsed_string: [u8; MAX_LITERAL_LENGTH_AS_STRING] =
            self.extract_string_entry(entry);
        let result = extract_literal_from_array(parsed_string, entry.json_length);

        if valid {
            Option::some(result)
        } else {
            Option::none()
        }
    }

    /// if the root JSON is an array, extract a literal given by the position of the target in the source array
    ///
    /// will revert if the literal does not exist
    fn get_literal_from_array_unchecked(self, array_index: Field) -> JSONLiteral {
        let result = self.get_literal_from_array(array_index);
        result.expect(f"array index out of bounds")
    }
}
