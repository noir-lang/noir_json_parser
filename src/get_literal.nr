use crate::_comparison_tools::lt::lt_field_16_bit;
use crate::enums::Layer::ARRAY_LAYER;
use crate::enums::Token::LITERAL_TOKEN;
use crate::json::JSON;
use crate::json_entry::JSONEntry;
use crate::utils::cast_num_to_u32;

global MAX_LITERAL_LENGTH_AS_STRING: u32 = 5;
global LITERAL_OFFSET_SHIFT: [Field; 6] =
    [0x10000000000, 0x100000000, 0x1000000, 0x10000, 0x100, 1];

/**
 * @brief a JSON "literal" type has 3 states: "true", "false", "null".
 *        As such we can't directly convert to a bool and cover all possible cases
 **/
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

/**
 * @brief given an input array, return a JSONLiteral depending on whether the array says "true", "false" or "null"
 **/
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

/**
 * @brief getter methods for extracting literal values out of a JSON struct
 * @description iterals are the JSON keywords `true`, `false`, and `null`. They are represented by `JSONLiteral`, which supports: `is_true()`, `is_false()`, `is_null()`, `to_bool()` (maps `true` to `true`, `false`/`null` to `false`)
 **/
impl<let NumBytes: u32, let NumPackedFields: u32, let MaxNumTokens: u32, let MaxNumValues: u32, let MaxKeyFields: u32> JSON<NumBytes, NumPackedFields, MaxNumTokens, MaxNumValues, MaxKeyFields> {

    /**
     * @brief if the root JSON is an object, extract a literal value given by `key`
     * @description From an object root, returns `Some(JSONLiteral)` if `key` exists and is a literal; `None` if `key` is missing; errors if `key` exists but is not a literal, or if called when the current root is an array.
     **/
<<<<<<< HEAD
    pub fn get_literal<let KeyBytes: u32>(self, key: [u8; KeyBytes]) -> Option<JSONLiteral> {
        assert(self.layer_type_of_root != ARRAY_LAYER, "cannot extract array elements via a key");

        let (exists, entry) = self.get_json_entry(key);
        assert(
            (entry.entry_type - LITERAL_TOKEN as Field) * exists as Field == 0,
            "get_literal: entry exists but is not a literal!",
        );
        let mut parsed_string: [u8; MAX_LITERAL_LENGTH_AS_STRING] =
            self.extract_string_entry(entry);

        if exists {
            Option::some(extract_literal_from_array(parsed_string, entry.json_length))
        } else {
            Option::none()
        }
=======
    pub(crate) fn get_literal<let KeyBytes: u32>(self, key: [u8; KeyBytes]) -> Option<JSONLiteral> {
        self.get_literal_var(BoundedVec::from_parts_unchecked(key, KeyBytes))
>>>>>>> 33bf55427694301d3630c946f35ac049c5563092
    }

    /**
     * @brief if the root JSON is an object, extract a literal value given by `key`
     * @description From an object root, returns the literal at `key`; errors if the key is missing, not a literal, or if called when the current root is an array.
     **/
<<<<<<< HEAD
    pub fn get_literal_unchecked<let KeyBytes: u32>(self, key: [u8; KeyBytes]) -> JSONLiteral {
        assert(self.layer_type_of_root != ARRAY_LAYER, "cannot extract array elements via a key");

        let entry = self.get_json_entry_unchecked(key);
        assert(
            entry.entry_type == LITERAL_TOKEN as Field,
            "get_literal_unchecked_var: entry exists but is not a literal!",
        );
        let mut parsed_string: [u8; MAX_LITERAL_LENGTH_AS_STRING] =
            self.extract_string_entry(entry);

        extract_literal_from_array(parsed_string, entry.json_length)
=======
    fn get_literal_unchecked<let KeyBytes: u32>(self, key: [u8; KeyBytes]) -> JSONLiteral {
        self.get_literal_unchecked_var(BoundedVec::from_parts_unchecked(key, KeyBytes))
>>>>>>> 33bf55427694301d3630c946f35ac049c5563092
    }

    /**
     * @brief Same as `get_literal`, but accepts a variable-length key up to `KeyBytes`.
     **/
<<<<<<< HEAD
    pub fn get_literal_var<let KeyBytes: u32>(
=======
    pub(crate) fn get_literal_var<let KeyBytes: u32>(
>>>>>>> 33bf55427694301d3630c946f35ac049c5563092
        self,
        key: BoundedVec<u8, KeyBytes>,
    ) -> Option<JSONLiteral> {
        assert(self.layer_type_of_root != ARRAY_LAYER, "cannot extract array elements via a key");

        let (exists, entry) = self.get_json_entry_var(key);
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
     * @brief Same as `get_literal_unchecked`, with a variable-length key.
     **/
<<<<<<< HEAD
    pub fn get_literal_unchecked_var<let KeyBytes: u32>(
=======
    pub(crate) fn get_literal_unchecked_var<let KeyBytes: u32>(
>>>>>>> 33bf55427694301d3630c946f35ac049c5563092
        self,
        key: BoundedVec<u8, KeyBytes>,
    ) -> JSONLiteral {
        assert(self.layer_type_of_root != ARRAY_LAYER, "cannot extract array elements via a key");

        let entry = self.get_json_entry_unchecked_var(key);
        assert(
            entry.entry_type == LITERAL_TOKEN as Field,
            "get_literal_unchecked_var: entry exists but is not a literal!",
        );
        let mut parsed_string: [u8; MAX_LITERAL_LENGTH_AS_STRING] =
            self.extract_string_entry(entry);

        extract_literal_from_array(parsed_string, entry.json_length)
    }

    /**
     * @brief if the root JSON is an array, extract a literal given by the position of the target in the source array
     * @description When the current root is an array, returns the literal at `index` wrapped in `Option`. Returns `None` if `index` is out of bounds; errors if in-bounds but the element at `index` is not a literal.
     **/
    fn get_literal_from_array(self, array_index: Field) -> Option<JSONLiteral> {
        assert(
            self.layer_type_of_root == ARRAY_LAYER,
            "can only acceess array elements from array",
        );

        let parent_entry: JSONEntry =
            self.json_entries_packed[self.root_index_in_transcript].into();

        let valid = lt_field_16_bit(array_index, parent_entry.num_children);
        let entry_index = (parent_entry.child_pointer + array_index) * valid as Field;

        let entry: JSONEntry = self.json_entries_packed[cast_num_to_u32(entry_index)].into();
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

    /**
     * @brief if the root JSON is an array, extract a literal given by the position of the target in the source array
     * @description When the current root is an array, returns the literal at `index`; errors if `index` is out of bounds or the element is not a literal.
     **/
    pub fn get_literal_from_array_unchecked(self, array_index: Field) -> JSONLiteral {
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
            entry.entry_type == LITERAL_TOKEN as Field,
            "get_literal_from_array_unchecked: entry exists but is not a literal!",
        );

        let mut parsed_string: [u8; MAX_LITERAL_LENGTH_AS_STRING] =
            self.extract_string_entry(entry);
        extract_literal_from_array(parsed_string, entry.json_length)
    }
}
