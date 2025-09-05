/// Describes information extracted from [TOKEN_FLAGS_TABLE], given a [Token] enum and a layer type (todo more data)
/// * `create_json_entry` : is this token linked to the creating of a [JSONEntry] object?
///     - we generate corresponding [JSONEntry] objects for `STRING_TOKEN`, `NUMERIC_TOKEN`, `LITERAL_TOKEN`, `END_OBJECT_TOKEN`, `END_ARRAY_TOKEN`
/// * `is_end_of_object_or_array`: `token == END_OBJECT_TOKEN || token == END_ARRAY_TOKEN`
/// * `is_start_of_object_or_array`: `token == START_OBJECT_TOKEN || token == `START_ARRAY_TOKEN`
/// * `new_context`: describes whether the next token being scanned belongs to an object or array
///     - `new_context` updates whenever we parse a `START_OBJECT_TOKEN` or `START_ARRAY_TOKEN`
///     - we are utilizing the TOKEN_FLAGS_TABLE to execute the following (equivalent) logic for cheap:
///     - `if (token == START_OBJECT_TOKEN) { new_context = OBJECT_LAYER; } else if (token == START_ARRAY_TOKEN { new_context = ARRAY_LAYER; })
/// * `is_key_token`: `token == KEY_TOKEN`
/// * `is_value_token`: `token == STRING_TOKEN || token == NUMERIC_TOKEN || token == LITERAL_TOKEN`
/// * `preserve_num_entries`: `!(is_start_of_object_or_array || is_end_of_object_or_array)`
/// *   - as we parse our tokens, we keep track of how many children the current parent object contains.
///     - when `preserve_num_entries == 1` implies the current parent object has not changed (could do with renaming this variable)
pub(crate) struct TokenFlags {
    pub(crate) create_json_entry: bool,
    pub(crate) is_end_of_object_or_array: bool,
    pub(crate) is_start_of_object_or_array: bool,
    pub(crate) new_context: bool,
    pub(crate) is_key_token: bool,
    pub(crate) is_value_token: bool,
    pub(crate) preserve_num_entries: bool,
}

impl TokenFlags {

    /// Convert a Field element that contains a packed TokenFlags object into a real TokenFlags object
    /// Note: when accessing these objects from lookup tables, it is much more efficient to represent a TokenFlags object by a single Field element,
    /// so only 1 lookup operation is required (vs 1 per struct member)
    /// This is an unconstrained fn which the `from_field` method uses for witness generation
    /// (fewer constraints required to validate the result of `__from_field` vs applying `__from_field` logic directly in a constrained fn)
    /// Note: code would be much more readable if we had an explicit PackedTokenFlags struct that wrapped a Field element
    unconstrained fn __from_field(f: Field) -> Self {
        let bytes: [u8; 7] = f.to_be_bytes();
        let create_json_entry = bytes[0] != 0;
        let is_end_of_object_or_array = bytes[1] != 0;
        let is_start_of_object_or_array = bytes[2] != 0;
        let new_context = bytes[3] != 0;
        let is_key_token = bytes[4] != 0;
        let is_value_token = bytes[5] != 0;
        let preserve_num_entries = bytes[6] != 0;

        TokenFlags {
            create_json_entry,
            is_end_of_object_or_array,
            is_start_of_object_or_array,
            new_context,
            is_key_token,
            is_value_token,
            preserve_num_entries,
        }
    }

    /// Convert a Field element that contains a packed TokenFlags object into a real TokenFlags object
    pub(crate) fn from_field(f: Field) -> Self {
        // 10 gates
        // Safety: check the comments below
        let r = unsafe { TokenFlags::__from_field(f) };
        // asserts the relation of r and f
        assert(r.to_field() == f);
        r
    }

    /// Pack a TokenFlags object into a Field element
    /// 4 gates
    pub(crate) fn to_field(self) -> Field {
        (self.preserve_num_entries as Field)
            + (self.is_value_token as Field) * 0x100
            + (self.is_key_token as Field) * 0x10000
            + (self.new_context as Field) * 0x1000000
            + (self.is_start_of_object_or_array as Field) * 0x100000000
            + (self.is_end_of_object_or_array as Field) * 0x10000000000
            + (self.create_json_entry as Field) * 0x1000000000000
    }
}
