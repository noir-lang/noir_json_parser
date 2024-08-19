struct JSONEntry {
    key_pointer: Field,
    key_length: Field,
    array_pointer: Field,
    entry_type: Field,
    child_pointer: Field,
    num_children: Field,
    json_pointer: Field,
    json_length: Field,
    depth: Field,
    parent_index: Field,
    id: Field
}
impl JSONEntry {
    fn new() -> Self {
        JSONEntry {
            key_pointer: 0,
            key_length: 0,
            array_pointer: 0,
            entry_type: 0,
            child_pointer: 0,
            num_children: 0,
            json_pointer: 0,
            json_length: 0,
            depth: 0,
            parent_index: 0,
            id: 0
        }
    }

    fn to_field(self) -> Field {
        self.id +
        self.parent_index *    0x10000+
        self.key_length *      0x100000000 +
        self.key_pointer *     0x1000000000000                                     // 2 bytes
        + self.array_pointer * 0x10000000000000000                          // 2 bytes
        + self.child_pointer * 0x100000000000000000000                      // 2 bytes
        + self.num_children *  0x1000000000000000000000000                  // 2 bytes
        + self.json_pointer *  0x10000000000000000000000000000              // 2 bytes
        + self.json_length *   0x100000000000000000000000000000000          // 2 bytes
        + self.depth *         0x1000000000000000000000000000000000000      // 1 byte
        + self.entry_type *    0x100000000000000000000000000000000000000 // 1 byte
        // 4 gates. oof
    }

    fn from_field(f: Field) -> Self {
        let bytes: [u8; 20] = f.to_be_bytes(20).as_array(); // 10.5 gates

        let entry_type = bytes[0] as Field;
        let depth = bytes[1] as Field;

        let json_length = bytes[2] as Field * 0x100 + bytes[3] as Field;
        let json_pointer = bytes[4] as Field * 0x100 + bytes[5] as Field;
        let num_children = bytes[6] as Field * 0x100 + bytes[7] as Field;
        let child_pointer = bytes[8] as Field * 0x100 + bytes[9] as Field;
        let array_pointer = bytes[10] as Field * 0x100 + bytes[11] as Field;
        let key_pointer = bytes[12] as Field * 0x100 + bytes[13] as Field; // 6 gates
        let key_length = bytes[14] as Field * 0x100 + bytes[15] as Field; // 6 gates
        let parent_index = bytes[16] as Field * 0x100 + bytes[17] as Field; // 6 gates
        let id = bytes[18] as Field * 0x100 + bytes[19] as Field; // 6 gates

        // this might cost 17 gates? oof
        JSONEntry {
            key_pointer,
            array_pointer,
            child_pointer,
            num_children,
            json_pointer,
            json_length,
            depth,
            entry_type,
            key_length,
            parent_index,
            id
        }
    }
}

impl std::cmp::Eq for JSONEntry {

    fn eq(self, other: Self) -> bool {
        let key = (self.key_pointer == other.key_pointer);
        assert(key == true, "key pointer bad");
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
        let depth = (self.depth == other.depth);
        assert(depth == true, "depth bad");
        true
    }
}
