struct JSONContextStackEntry {
    num_entries: Field,
    context: Field,
    current_key_length: Field,
    current_key_index: Field,
    json_index: Field,
    entry_pointer: Field,
    current_identity: Field
}
impl JSONContextStackEntry {
    unconstrained fn __from_field(f: Field) -> Self {
        // 19 + 6 = 25
        let bytes = f.to_be_bytes(13);
        let context = bytes[0] as Field;
        let num_entries = bytes[1] as Field * 0x100 + bytes[2] as Field;
        let current_key_length = bytes[3] as Field * 0x100 + bytes[4] as Field;
        let current_key_index = bytes[5] as Field * 0x100 + bytes[6] as Field;
        let json_index = bytes[7] as Field * 0x100 + bytes[8] as Field;
        let entry_pointer = bytes[9] as Field * 0x100 + bytes[10] as Field;
        let current_identity = bytes[11] as Field * 0x100 + bytes[12] as Field;
        JSONContextStackEntry { num_entries, context, current_key_length, current_key_index, json_index, entry_pointer, current_identity }
    }

    fn from_field(f: Field) -> Self {
        let result = JSONContextStackEntry::__from_field(f);

        result.context.assert_max_bit_size(8);
        result.num_entries.assert_max_bit_size(16);
        result.current_key_length.assert_max_bit_size(16);
        result.current_key_index.assert_max_bit_size(16);
        result.json_index.assert_max_bit_size(16);
        result.entry_pointer.assert_max_bit_size(16);
        result.current_identity.assert_max_bit_size(16);
        assert(result.to_field() == f); // 3
        result
    }

    fn to_field(self) -> Field {
        self.current_identity
            + self.entry_pointer * 0x10000
            + self.json_index * 0x100000000
            + self.current_key_index * 0x1000000000000
            + self.current_key_length * 0x10000000000000000
            + self.num_entries * 0x100000000000000000000
            + self.context * 0x1000000000000000000000000
    }
}

struct JSONEntry {
    array_pointer: Field,
    entry_type: Field,
    child_pointer: Field,
    num_children: Field,
    json_pointer: Field,
    json_length: Field,
    parent_index: Field,
    id: Field
}
impl JSONEntry {
    fn new() -> Self {
        JSONEntry {
            array_pointer: 0,
            entry_type: 0,
            child_pointer: 0,
            num_children: 0,
            json_pointer: 0,
            json_length: 0,
            parent_index: 0,
            id: 0
        }
    }

    unconstrained fn __extract_parent_index_from_field(f: Field) -> (Field, Field, Field) {
        let entry = JSONEntry::from_field(f);
        let low = entry.id;
        let mid = entry.parent_index;
        let hi = (f - low - mid * 0x10000) / 0x100000000;
        (low, mid, hi)
    }

    fn add_child_pointer_into_field(f: Field, child_pointer: Field) -> Field {
        f + child_pointer * 0x100000000000000000000
    }
    unconstrained fn __extract_entry_type_and_id_from_field(f: Field) -> (Field, Field, Field) {
        let entry = JSONEntry::from_field(f);
        let id = entry.id;
        let entry_type = entry.entry_type;
        let mid = (f - id - entry_type * 0x100000000000000000000000000000000000000) / 0x10000;
        (id, mid, entry_type)
    }
    unconstrained fn __extract_entry_type_id_and_parent_index_from_field(f: Field) -> (Field, Field, Field, Field) {
        let entry = JSONEntry::from_field(f);
        let id = entry.id;
        let entry_type = entry.entry_type;
        let parent_index = entry.parent_index;
        let mid = (f - id - parent_index * 0x10000 - entry_type * 0x100000000000000000000000000000000000000)
            / 0x100000000;
        (id, parent_index, mid, entry_type)
    }

    // 11.75 gates
    fn extract_entry_type_id_and_parent_index_from_field(f: Field) -> (Field, Field, Field) {
        let (id, parent_index, mid, entry_type) = JSONEntry::__extract_entry_type_id_and_parent_index_from_field(f);
        id.assert_max_bit_size(8); // 1.25
        parent_index.assert_max_bit_size(16); // 1.5
        entry_type.assert_max_bit_size(16); // 1.5
        mid.assert_max_bit_size(136); // 5.5

        assert(
            id
            + parent_index * 0x10000
            + mid * 0x100000000
            + entry_type * 0x100000000000000000000000000000000000000
            == f
        );

        (id, parent_index, entry_type)
    }
    fn extract_entry_type_and_id_from_field(f: Field) -> (Field, Field) {
        let (id, mid, entry_type) = JSONEntry::__extract_entry_type_and_id_from_field(f);
        id.assert_max_bit_size(8); // 1.25
        entry_type.assert_max_bit_size(16); // 1.5
        mid.assert_max_bit_size(136); // 5.5

        assert(id + mid * 0x10000 + entry_type * 0x100000000000000000000000000000000000000 == f);
        (id, entry_type)
    }
    fn extract_parent_index_from_field(f: Field) -> Field {
        let (low, parent_index, hi) = JSONEntry::__extract_parent_index_from_field(f);

        low.assert_max_bit_size(16); // 1.75
        hi.assert_max_bit_size(128); // 5.5
        parent_index.assert_max_bit_size(16); // 1.75
        assert(low + parent_index * 0x10000 + hi * 0x100000000 == f); // 1
        // 10 gates?
        parent_index
    }
    unconstrained fn __from_field(f: Field) -> Self {
        let bytes: [u8; 20] = f.to_be_bytes(20).as_array(); // 10.5 gates

        let entry_type = bytes[0] as Field;

        let json_length = bytes[2] as Field * 0x100 + bytes[3] as Field;
        let json_pointer = bytes[4] as Field * 0x100 + bytes[5] as Field;
        let num_children = bytes[6] as Field * 0x100 + bytes[7] as Field;
        let child_pointer = bytes[8] as Field * 0x100 + bytes[9] as Field;
        let array_pointer = bytes[10] as Field * 0x100 + bytes[11] as Field;
        let parent_index = bytes[16] as Field * 0x100 + bytes[17] as Field; // 6 gates
        let id = bytes[18] as Field * 0x100 + bytes[19] as Field; // 6 gates

        // this might cost 17 gates? oof
        JSONEntry { array_pointer, child_pointer, num_children, json_pointer, json_length, entry_type, parent_index, id }
    }

    fn to_field(self) -> Field {
        self.id +
        self.parent_index *    0x10000
        + self.array_pointer * 0x10000000000000000                          // 2 bytes
        + self.child_pointer * 0x100000000000000000000                      // 2 bytes
        + self.num_children *  0x1000000000000000000000000                  // 2 bytes
        + self.json_pointer *  0x10000000000000000000000000000              // 2 bytes
        + self.json_length *   0x100000000000000000000000000000000          // 2 bytes
        + self.entry_type *    0x100000000000000000000000000000000000000 // 1 byte
        // 4 gates. oof
    }
    fn from_field(f: Field) -> Self {
        let result = JSONEntry::__from_field(f);
        result.entry_type.assert_max_bit_size(8);
        result.json_length.assert_max_bit_size(16);
        result.json_pointer.assert_max_bit_size(16);
        result.num_children.assert_max_bit_size(16);
        result.child_pointer.assert_max_bit_size(16);
        result.array_pointer.assert_max_bit_size(16);
        result.parent_index.assert_max_bit_size(16);
        result.id.assert_max_bit_size(16);
        assert(result.to_field() == f);
        result
    }
}

impl std::cmp::Eq for JSONEntry {

    fn eq(self, other: Self) -> bool {
        let array_ptr = (self.array_pointer == other.array_pointer);
        assert(array_ptr == true, "array pointer bad");
        let entry = self.entry_type == other.entry_type;
        assert(entry == true, "entry type bad");
        let child = (self.child_pointer == other.child_pointer);
        assert(child == true, "child pointer bad");
        let num_children = (self.num_children == other.num_children);
        assert(num_children == true, "num children bad");

       let json_pointer = (self.json_pointer == other.json_pointer);
       assert(json_pointer == true, "json pointer bad");
        
        let json_length = (self.json_length == other.json_length);
        assert(json_length == true, "json length bad");
        true
    }
}
