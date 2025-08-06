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

    pub(crate) fn from_field(f: Field) -> Self {
        // 10 gates
        // Safety: check the comments below
        let r = unsafe { TokenFlags::__from_field(f) };

        // asserts the relation of r and f
        assert(r.to_field() == f);
        r
    }

    // 4 gates
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
