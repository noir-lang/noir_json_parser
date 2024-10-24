/**
 * @brief contains data we need to keep track when, in `create_json_entries`, we enter or exist from an object or array
 **/
struct JSONContextStackEntry {
    num_entries: Field,
    context: Field,
    current_key_index_and_length: Field,
    json_index: Field,
    current_identity: Field,
}
impl JSONContextStackEntry {
    unconstrained fn __from_field(f: Field) -> Self {
        let bytes: [u8; 11] = f.to_be_bytes();
        let context = bytes[0] as Field;
        let num_entries = bytes[1] as Field * 0x100 + bytes[2] as Field;
        let current_key_length = bytes[3] as Field * 0x100 + bytes[4] as Field;
        let current_key_index = bytes[5] as Field * 0x100 + bytes[6] as Field;
        let json_index = bytes[7] as Field * 0x100 + bytes[8] as Field;
        let current_identity = bytes[9] as Field * 0x100 + bytes[10] as Field;
        let current_key_index_and_length = current_key_index + current_key_length * 0x10000;
        JSONContextStackEntry {
            num_entries,
            context,
            current_key_index_and_length,
            json_index,
            current_identity,
        }
    }

    /**
     * @brief we pack multiple values into a Field element in order to reduce the number of array read/write queries we need
     *        (each query will be 3.5 gates as we read and write from/to unknown locations)
     * @note method cost = 9.5 gates
     **/
    fn from_field(f: Field) -> Self {
        let result = JSONContextStackEntry::__from_field(f);

        result.context.assert_max_bit_size::<8>(); // 1.25
        result.num_entries.assert_max_bit_size::<16>(); // 1.5
        result.current_key_index_and_length.assert_max_bit_size::<32>(); // 1.75
        result.json_index.assert_max_bit_size::<16>(); // 1.5
        result.current_identity.assert_max_bit_size::<16>(); // 1.5
        assert(result.to_field() == f); // 2
        result
    }

    /**
     * @brief we pack multiple values into a Field element in order to reduce the number of array read/write queries we need
     *        (each query will be 3.5 gates as we read and write from/to unknown locations)
     * @note method cost = 2 gates
     **/
    fn to_field(self) -> Field {
        self.current_identity
            + self.json_index * 0x10000
            + self.current_key_index_and_length * 0x100000000
            + self.num_entries * 0x10000000000000000
            + self.context * 0x100000000000000000000
    }
}

/**
 * @brief describes a single array, object or value within our JSON
 **/
struct JSONEntry {
    entry_type: Field, // is this an OBJECT_TOKEN, ARRAY_TOKEN, STRING_TOKEN, NUMERIC_TOKEN or LITERAL_TOKEN?
    id: Field, // if this is an object or array, describes the unique identifier assigned to this item
    parent_index: Field, // if parent is an object or array, describes the unique identifier assigned to our parent
    array_pointer: Field, // if parent is an array, where in the array are we?
    child_pointer: Field, // if this is an object or array, points to the location in `json_entries_packed` of this item's first child
    num_children: Field, // if this is an object or array, how many child elements do we contain?
    json_pointer: Field, // points to the json that describes the first byte of this entry
    json_length: Field, // how many bytes in the json describes this item? (only for strings, numbers or literals)
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
            id: 0,
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
    unconstrained fn __extract_entry_type_id_and_parent_index_from_field(
        f: Field,
    ) -> (Field, Field, Field, Field) {
        let entry = JSONEntry::from_field(f);
        let id = entry.id;
        let entry_type = entry.entry_type;
        let parent_index = entry.parent_index;
        let mid = (
            f - id - parent_index * 0x10000 - entry_type * 0x100000000000000000000000000000000000000
        )
            / 0x100000000;
        (id, parent_index, mid, entry_type)
    }

    // 11.75 gates
    fn extract_entry_type_id_and_parent_index_from_field(f: Field) -> (Field, Field, Field) {
        let (id, parent_index, mid, entry_type) =
            JSONEntry::__extract_entry_type_id_and_parent_index_from_field(f);
        id.assert_max_bit_size::<8>(); // 1.25
        parent_index.assert_max_bit_size::<16>(); // 1.5
        entry_type.assert_max_bit_size::<16>(); // 1.5
        mid.assert_max_bit_size::<136>(); // 5.5
        assert(
            id
                + parent_index * 0x10000
                + mid * 0x100000000
                + entry_type * 0x100000000000000000000000000000000000000
                == f,
        );

        (id, parent_index, entry_type)
    }
    fn extract_entry_type_and_id_from_field(f: Field) -> (Field, Field) {
        let (id, mid, entry_type) = JSONEntry::__extract_entry_type_and_id_from_field(f);
        id.assert_max_bit_size::<8>(); // 1.25
        entry_type.assert_max_bit_size::<16>(); // 1.5
        mid.assert_max_bit_size::<136>(); // 5.5
        assert(id + mid * 0x10000 + entry_type * 0x100000000000000000000000000000000000000 == f);
        (id, entry_type)
    }
    fn extract_parent_index_from_field(f: Field) -> Field {
        let (low, parent_index, hi) = JSONEntry::__extract_parent_index_from_field(f);

        low.assert_max_bit_size::<16>(); // 1.75
        hi.assert_max_bit_size::<128>(); // 5.5
        parent_index.assert_max_bit_size::<16>(); // 1.75
        assert(low + parent_index * 0x10000 + hi * 0x100000000 == f); // 1
        // 10 gates?
        parent_index
    }
    unconstrained fn __from_field(f: Field) -> Self {
        let bytes: [u8; 20] = f.to_be_bytes(); // 10.5 gates
        let entry_type = bytes[0] as Field;

        let json_length = bytes[2] as Field * 0x100 + bytes[3] as Field;
        let json_pointer = bytes[4] as Field * 0x100 + bytes[5] as Field;
        let num_children = bytes[6] as Field * 0x100 + bytes[7] as Field;
        let child_pointer = bytes[8] as Field * 0x100 + bytes[9] as Field;
        let array_pointer = bytes[10] as Field * 0x100 + bytes[11] as Field;
        let parent_index = bytes[16] as Field * 0x100 + bytes[17] as Field; // 6 gates
        let id = bytes[18] as Field * 0x100 + bytes[19] as Field; // 6 gates
        JSONEntry {
            array_pointer,
            child_pointer,
            num_children,
            json_pointer,
            json_length,
            entry_type,
            parent_index,
            id,
        }
    }

    fn to_field(self) -> Field {
        self.id
            + self.parent_index * 0x10000
            + self.array_pointer * 0x10000000000000000 // 2 bytes
            + self.child_pointer * 0x100000000000000000000 // 2 bytes
            + self.num_children * 0x1000000000000000000000000 // 2 bytes
            + self.json_pointer * 0x10000000000000000000000000000 // 2 bytes
            + self.json_length * 0x100000000000000000000000000000000 // 2 bytes
            + self.entry_type * 0x100000000000000000000000000000000000000 // 1 byte
        // 4 gates. oof
    }
    fn from_field(f: Field) -> Self {
        let result = JSONEntry::__from_field(f);
        result.entry_type.assert_max_bit_size::<8>();
        result.json_length.assert_max_bit_size::<16>();
        result.json_pointer.assert_max_bit_size::<16>();
        result.num_children.assert_max_bit_size::<16>();
        result.child_pointer.assert_max_bit_size::<16>();
        result.array_pointer.assert_max_bit_size::<16>();
        result.parent_index.assert_max_bit_size::<16>();
        result.id.assert_max_bit_size::<16>();
        assert(result.to_field() == f);
        result
    }
}

impl std::convert::From<JSONEntryPacked> for JSONEntry {
    fn from(JSONEntryPacked { value: f }: JSONEntryPacked) -> Self {
        let result = JSONEntry::__from_field(f);
        result.entry_type.assert_max_bit_size::<8>();
        result.json_length.assert_max_bit_size::<16>();
        result.json_pointer.assert_max_bit_size::<16>();
        result.num_children.assert_max_bit_size::<16>();
        result.child_pointer.assert_max_bit_size::<16>();
        result.array_pointer.assert_max_bit_size::<16>();
        result.parent_index.assert_max_bit_size::<16>();
        result.id.assert_max_bit_size::<16>();
        assert(result.to_field() == f);
        result
    }
}

impl std::cmp::Eq for JSONEntry {
    // N.B. used for testing
    fn eq(self, other: Self) -> bool {
        let array_ptr = (self.array_pointer == other.array_pointer);
        let entry = self.entry_type == other.entry_type;
        let child = (self.child_pointer == other.child_pointer);
        let num_children = (self.num_children == other.num_children);
        let json_pointer = (self.json_pointer == other.json_pointer);
        let json_length = (self.json_length == other.json_length);
        array_ptr | entry | child | num_children | json_pointer | json_length
    }
}

/**
 * @brief describes a JSONEntry object's data, but packed into a single field element.
 * @description We do this to minimize the number of array lookups we perform
 **/
struct JSONEntryPacked {
    value: Field,
}

impl std::cmp::Eq for JSONEntryPacked {
    fn eq(self, other: Self) -> bool {
        self.value == other.value
    }
}

impl std::default::Default for JSONEntryPacked {
    fn default() -> Self {
        JSONEntryPacked { value: 0 }
    }
}
