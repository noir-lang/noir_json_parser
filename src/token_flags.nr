struct TokenFlags {
    create_json_entry: Field,
    json_entry_type: Field,
    is_end_of_object_or_array: Field,
    is_start_of_object_or_array: Field,
    new_context: Field,
    is_key_token: Field,
    is_value_token: Field,
    is_value_token_in_array_context: Field,
    create_key_entry: Field,
    is_end_of_object_or_array_in_array_context: Field,
    preserve_identity_value: Field,
    preserve_num_entries: Field,
}

impl TokenFlags {

    fn from_field(f: Field) -> Self {
        // 21 gates!
        let bytes = f.to_be_bytes(12);
        let create_json_entry = bytes[0] as Field;
        let json_entry_type = bytes[1] as Field;
        let is_end_of_object_or_array = bytes[2] as Field;
        let is_start_of_object_or_array = bytes[3] as Field;
        let new_context = bytes[4] as Field;
        let is_key_token = bytes[5] as Field;

        let is_value_token = bytes[6] as Field;
        let is_value_token_in_array_context = bytes[7] as Field;
        let create_key_entry = bytes[8] as Field;
        let is_end_of_object_or_array_in_array_context = bytes[9] as Field;
        let preserve_identity_value = bytes[10] as Field;
        let preserve_num_entries = bytes[11] as Field;

        TokenFlags {
            create_json_entry,
            json_entry_type,
            is_end_of_object_or_array,
            is_start_of_object_or_array,
            new_context,
            is_key_token,
            is_value_token,
            is_value_token_in_array_context,
            create_key_entry,
            is_end_of_object_or_array_in_array_context,
            preserve_identity_value,
            preserve_num_entries
        }
    }

    fn to_field(self) -> Field {
        self.preserve_num_entries
            + self.preserve_identity_value * 0x100
            + self.is_end_of_object_or_array_in_array_context * 0x10000
            + self.create_key_entry * 0x1000000
            + self.is_value_token_in_array_context * 0x100000000
            + self.is_value_token * 0x10000000000
            + self.is_key_token * 0x1000000000000
            + self.new_context * 0x100000000000000
            + self.is_start_of_object_or_array * 0x10000000000000000
            + self.is_end_of_object_or_array * 0x1000000000000000000
            + self.json_entry_type * 0x100000000000000000000
            + self.create_json_entry
                                                        * 0x10000000000000000000000
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
            preserve_identity_value: 0,
            is_end_of_object_or_array_in_array_context: 0,
            create_key_entry: 0,
            is_value_token_in_array_context: 0,
            is_value_token: 0
        }
    }
}
