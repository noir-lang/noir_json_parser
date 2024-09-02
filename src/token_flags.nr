struct TokenFlags {
    create_json_entry: Field,
    json_entry_type: Field,
    is_end_of_object_or_array: Field,
    is_start_of_object_or_array: Field,
    new_context: Field,
    is_key_token: Field,
    is_value_token: Field,
    preserve_num_entries: Field,
}

impl TokenFlags {

    unconstrained fn __from_field(f: Field) -> Self {
        // 14 gates
        let bytes = f.to_be_bytes(8);
        let create_json_entry = bytes[0] as Field;
        let json_entry_type = bytes[1] as Field;
        let is_end_of_object_or_array = bytes[2] as Field;
        let is_start_of_object_or_array = bytes[3] as Field;
        let new_context = bytes[4] as Field;
        let is_key_token = bytes[5] as Field;
        let is_value_token = bytes[6] as Field;
        let preserve_num_entries = bytes[7] as Field;

        TokenFlags {
            create_json_entry,
            json_entry_type,
            is_end_of_object_or_array,
            is_start_of_object_or_array,
            new_context,
            is_key_token,
            is_value_token,
            preserve_num_entries
        }
    }

    fn from_field(f: Field) -> Self {
        // 14 gates
        let r = TokenFlags::__from_field(f);

        assert(r.create_json_entry * r.create_json_entry == r.create_json_entry);
        assert(r.is_end_of_object_or_array * r.is_end_of_object_or_array == r.is_end_of_object_or_array);
        assert(
            r.is_start_of_object_or_array * r.is_start_of_object_or_array
            == r.is_start_of_object_or_array
        );
        assert(r.new_context * r.new_context == r.new_context);
        assert(r.is_key_token * r.is_key_token == r.is_key_token);
        assert(r.is_value_token * r.is_value_token == r.is_value_token);
        assert(r.preserve_num_entries * r.preserve_num_entries == r.preserve_num_entries);
        r.json_entry_type.assert_max_bit_size(8);

        assert(r.to_field() == f);
        r
    }

    // 4 gates
    fn to_field(self) -> Field {
        self.preserve_num_entries
            + self.is_value_token * 0x100
            + self.is_key_token * 0x10000
            + self.new_context * 0x1000000
            + self.is_start_of_object_or_array * 0x100000000
            + self.is_end_of_object_or_array * 0x10000000000
            + self.json_entry_type * 0x1000000000000
            + self.create_json_entry * 0x100000000000000
    }

    fn default() -> Self {
        TokenFlags {
            create_json_entry: 0,
            json_entry_type: 0,
            is_end_of_object_or_array: 0,
            is_start_of_object_or_array: 0,
            new_context: 0,
            is_key_token: 0,
            preserve_num_entries: 0,
            is_value_token: 0
        }
    }
}
