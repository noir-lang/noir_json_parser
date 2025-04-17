pub(crate) struct TokenFlags {
    pub(crate) create_json_entry: Field,
    pub(crate) is_end_of_object_or_array: Field,
    pub(crate) is_start_of_object_or_array: Field,
    pub(crate) new_context: Field,
    pub(crate) is_key_token: Field,
    pub(crate) is_value_token: Field,
    pub(crate) preserve_num_entries: Field,
}

impl TokenFlags {

    unconstrained fn __from_field(f: Field) -> Self {
        let bytes: [u8; 7] = f.to_be_bytes();
        let create_json_entry = bytes[0] as Field;
        let is_end_of_object_or_array = bytes[1] as Field;
        let is_start_of_object_or_array = bytes[2] as Field;
        let new_context = bytes[3] as Field;
        let is_key_token = bytes[4] as Field;
        let is_value_token = bytes[5] as Field;
        let preserve_num_entries = bytes[6] as Field;

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

        // checks that the flags are binary
        assert(r.create_json_entry * r.create_json_entry == r.create_json_entry);
        assert(
            r.is_end_of_object_or_array * r.is_end_of_object_or_array
                == r.is_end_of_object_or_array,
        );
        assert(
            r.is_start_of_object_or_array * r.is_start_of_object_or_array
                == r.is_start_of_object_or_array,
        );
        assert(r.new_context * r.new_context == r.new_context);
        assert(r.is_key_token * r.is_key_token == r.is_key_token);
        assert(r.is_value_token * r.is_value_token == r.is_value_token);
        assert(r.preserve_num_entries * r.preserve_num_entries == r.preserve_num_entries);

        // asserts the relation of r and f
        assert(r.to_field() == f);
        r
    }

    // 4 gates
    pub(crate) fn to_field(self) -> Field {
        self.preserve_num_entries
            + self.is_value_token * 0x100
            + self.is_key_token * 0x10000
            + self.new_context * 0x1000000
            + self.is_start_of_object_or_array * 0x100000000
            + self.is_end_of_object_or_array * 0x10000000000
            + self.create_json_entry * 0x1000000000000
    }

    pub(crate) fn default() -> Self {
        TokenFlags {
            create_json_entry: 0,
            is_end_of_object_or_array: 0,
            is_start_of_object_or_array: 0,
            new_context: 0,
            is_key_token: 0,
            preserve_num_entries: 0,
            is_value_token: 0,
        }
    }
}
