use crate::_comparison_tools::lt::assert_lte_240_bit;
use crate::_comparison_tools::lt::lte_field_240_bit;
use crate::json::JSON;
use crate::json_entry::{JSONEntry, JSONEntryPacked};
use crate::json_tables::TOKEN_ENDS_OBJECT_OR_ARRAY;
use crate::keyhash::FieldHasher;

use crate::utils::cast_num_to_u32;
use dep::noir_sort;

pub(crate) struct KeyIndexData {
    pub(crate) json_index: Field,
    pub(crate) json_length: Field,
    pub(crate) parent_id: Field,
    pub(crate) array_index: Field,
}

impl KeyIndexData {
    pub(crate) fn to_field(self) -> Field {
        self.parent_id
            + self.json_index as Field * 0x10000
            + self.json_length as Field * 0x100000000
            + self.array_index * 0x1000000000000
    }

    unconstrained fn __from_field(packed: Field) -> Self {
        let unpacked: [u8; 8] = packed.to_be_bytes();
        let array_index: Field = unpacked[1] as Field + unpacked[0] as Field * 0x100;
        let json_length: Field = unpacked[3] as Field + unpacked[2] as Field * 0x100;
        let json_index: Field = unpacked[5] as Field + unpacked[4] as Field * 0x100;
        let parent_id: Field = unpacked[7] as Field + unpacked[6] as Field * 0x100;
        KeyIndexData { json_index, json_length, parent_id, array_index }
    }

    pub(crate) fn from_field(packed: Field) -> Self {
        // Safety: check the comments below
        let result = unsafe { KeyIndexData::__from_field(packed) };
        // checks that array_index is in range
        result.array_index.assert_max_bit_size::<16>();
        // checks that json_length is in range
        result.json_length.assert_max_bit_size::<16>();
        // checks that json_index is in range
        result.json_index.assert_max_bit_size::<16>();
        // checks that parent_id is in range
        result.parent_id.assert_max_bit_size::<16>();
        // checks that the input is a valid combination of the outputs of the decomposition
        assert(result.to_field() == packed);
        result
    }
}

impl<let NumBytes: u32, let NumPackedFields: u32, let MaxNumTokens: u32, let MaxNumValues: u32, let MaxKeyFields: u32> JSON<NumBytes, NumPackedFields, MaxNumTokens, MaxNumValues, MaxKeyFields> {
    fn compute_keyhash_and_sort_json_entries(&mut self) {
        let hasher: FieldHasher<MaxKeyFields> = FieldHasher {};

        let mut hashlist: [Field; MaxNumValues] = [0; MaxNumValues];

        let two_pow_200 = 0x10000000000000000000000000000000000000000000000000000;
        let two_pow_216 = 0x100000000000000000000000000000000000000000000000000000000;
        for i in 0..MaxNumValues {
            let KeyIndexData { json_index, json_length, parent_id, array_index } =
                KeyIndexData::from_field(self.key_data[i]);
            let hash = hasher.get_keyhash(self.json_packed, json_index, json_length);
            //ensures hash:0-199 bits, array_index:200-215 bits, parent_id: 216-239 bits
            hashlist[i] = hash + array_index * two_pow_200 + parent_id * two_pow_216;
        }

        hashlist[MaxNumValues - 1] = 0; // we always ensure the last (unused hopefully!) entry goes first.
        self.json_entries_packed[MaxNumValues - 1] = JSONEntryPacked::default();
        // when updating identity_to_json_map we are relying on the fact that we can update sorted entry 0? maybe? oof document better
        let sort_result = noir_sort::sort_advanced(hashlist, lte_field_240_bit, assert_lte_240_bit);

        let mut sorted_entries: [JSONEntryPacked; MaxNumValues] =
            [JSONEntryPacked::default(); MaxNumValues];

        for i in 0..MaxNumValues {
            sorted_entries[sort_result.sort_indices[i]] = self.json_entries_packed[i];
        }

        let mut parent_indices: [u32; MaxNumValues] = [0; MaxNumValues];

        let mut identity_to_json_map: [u32; MaxNumValues] = [0; MaxNumValues];
        for i in 0..MaxNumValues {
            // 11.75 + 3.5 = 15.25 gates per iteration
            let (id, parent_index, entry_type) = JSONEntry::extract_entry_type_id_and_parent_index_from_field(
                sorted_entries[i].value,
            );
            parent_indices[i] = cast_num_to_u32(parent_index);
            // 2 gates
            // update is 1 for end of object/array, 0 for other
            let update = TOKEN_ENDS_OBJECT_OR_ARRAY[cast_num_to_u32(entry_type)];
            // NOTE THIS RELIES ON MaxNumValues ACTUALLY DESCRIBING NUMMaxNumValues + 1
            let index = if update {
                cast_num_to_u32(id)
            } else {
                MaxNumValues - 1
            };
            // 3.5 gates
            identity_to_json_map[index] = i;
        }
        // 13.5 gates per iteration
        let mut parent_identity_pre = parent_indices[0];
        for i in 1..MaxNumValues {
            let parent_identity_post = parent_indices[i];
            // if the parent identity changes,
            // 3.5 gate
            // the list is sorted according to parent_identity,
            // n.b. parent_identity_post - parent_identity_pre is not necessarily 0 or 1 (can be larger)
            //      due to empty objects and arrays increasing identity value without creating associated child json entries
            let new_parent = parent_identity_pre < parent_identity_post;
            // 3.5 gates
            let index_of_parent = identity_to_json_map[parent_identity_post];
            // 1 gate + 3.5 gates
            let updated = JSONEntry::add_child_pointer_into_field(
                sorted_entries[index_of_parent].value,
                i as Field,
            );

            // RELIES ON THE SMALLEST ENTRY IN THE SORTED LIST BEING EMPTY
            // 1 gate
            let index = if new_parent { index_of_parent } else { 0 };
            // 3.5 gates
            //index is just 0 if new_parent is false, so sorted_entries[0] is useless info
            sorted_entries[index] = JSONEntryPacked { value: updated };

            parent_identity_pre = parent_identity_post;
        }
        sorted_entries[0] = JSONEntryPacked::default();
        self.unsorted_json_entries_packed = self.json_entries_packed;
        self.json_entries_packed = sorted_entries;
        self.key_hashes = sort_result.sorted;
        self.set_root_entry();
    }

    pub(crate) fn set_root_entry(&mut self) {
        // Safety: check the comments below
        let root_index = unsafe { __find_root_entry::<MaxNumValues>(self.json_entries_packed) };

        let packed_entry = self.json_entries_packed[root_index];
        let entry: JSONEntry = packed_entry.into();

        // checks that the entry is not empty
        assert(packed_entry.value != 0);
        // checks that the parent index is 0
        assert(entry.parent_index == 0);
        self.root_index_in_transcript = root_index;
    }
}

unconstrained fn __find_root_entry<let MaxNumValues: u32>(
    json_entries_packed: [JSONEntryPacked; MaxNumValues],
) -> u32 {
    let mut found_index = 0;
    for i in 0..MaxNumValues {
        let entry: JSONEntry = json_entries_packed[i].into();
        if (entry.parent_index == 0) & (json_entries_packed[i].value != 0) {
            found_index = i;
            break;
        }
    }
    found_index
}
