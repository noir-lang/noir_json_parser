use crate::redux::JSON;
use crate::json_entry::JSONEntry;
use crate::lt::lt_field_16_bit;
use crate::lt::lte_field_240_bit;
use crate::lt::assert_lte_240_bit;
use crate::redux_tables::{TOKEN_BEGINS_OBJECT_OR_ARRAY, BEGIN_OBJECT_TOKEN, BEGIN_ARRAY_TOKEN};
use crate::keyhash::get_keyhash_chunky;
use crate::keyhash::get_keyhash;
use crate::keyhash::slice_200_bits_from_field;
use crate::slice_field::slice_fields;
use crate::keyhash::Hasher;

use dep::noir_sort;

use dep::std::hash::poseidon2;
struct KeyIndexData {
    json_index: Field,
    json_length: Field,
    parent_id: Field,
    array_index: Field,
}

impl KeyIndexData {
    fn to_field(self) -> Field {
        self.parent_id
            + self.json_index as Field * 0x10000
            + self.json_length as Field * 0x100000000
            + self.array_index * 0x1000000000000
    }

    unconstrained fn __from_field(packed: Field) -> Self {
        let unpacked = packed.to_be_bytes(8);
        let array_index: Field = unpacked[1] as Field + unpacked[0] as Field * 0x100;
        let json_length: Field = unpacked[3] as Field + unpacked[2] as Field * 0x100;
        let json_index: Field = unpacked[5] as Field + unpacked[4] as Field * 0x100;
        let parent_id: Field = unpacked[7] as Field + unpacked[6] as Field * 0x100;
        KeyIndexData { json_index, json_length, parent_id, array_index }
    }

    fn from_field(packed: Field) -> Self {
        let result = KeyIndexData::__from_field(packed);
        result.array_index.assert_max_bit_size(16);
        result.json_length.assert_max_bit_size(16);
        result.json_index.assert_max_bit_size(16);
        result.parent_id.assert_max_bit_size(16);
        assert(result.to_field() == packed);
        result
    }
}

impl<let NumBytes: u32, let NumPackedFields: u16, let MaxNumTokens: u16, let MaxNumValues: u16> JSON<NumBytes, NumPackedFields, MaxNumTokens, MaxNumValues> {
    fn compute_keyhash_and_sort_json_entries(&mut self) {
        let hasher: Hasher<2> = Hasher {};

        let mut hashlist: [Field; MaxNumValues] = [0; MaxNumValues];

        let two_pow_200 = 0x10000000000000000000000000000000000000000000000000000;
        let two_pow_216 = 0x100000000000000000000000000000000000000000000000000000000;
        for i in 0..MaxNumValues {
            let KeyIndexData{ json_index, json_length, parent_id, array_index } = KeyIndexData::from_field(self.key_data[i]);
            let hash = hasher.get_keyhash(self.packed_json, json_index, json_length);
            hashlist[i] = hash + array_index * two_pow_200 + parent_id * two_pow_216;
        }

        hashlist[MaxNumValues - 1] = 0; // we always ensure the last (unused hopefully!) entry goes first.

        self.packed_json_entries[MaxNumValues - 1] = 0;
        // when updating identity_to_json_map we are relying on the fact that we can update sorted entry 0? maybe? oof document better
        let sort_result = noir_sort::sort_advanced(hashlist, lte_field_240_bit, assert_lte_240_bit);

        let mut sorted_entries: [Field; MaxNumValues] = [0; MaxNumValues];

        for i in 0..MaxNumValues {
            sorted_entries[sort_result.sort_indices[i]] = self.packed_json_entries[i];
        }

        let mut ids: [Field; MaxNumValues] = [0; MaxNumValues];
        let mut parent_indices: [Field; MaxNumValues] = [0; MaxNumValues];
        let mut entry_types: [Field; MaxNumValues] = [0; MaxNumValues];

        for i in 0..MaxNumValues {
            // 11.75 + 3.5 = 15.25 gates per iteration
            let (id, parent_index, entry_type) = JSONEntry::extract_entry_type_id_and_parent_index_from_field(sorted_entries[i]);
            ids[i] = id;
            parent_indices[i] = parent_index;
            entry_types[i] = entry_type;
        }

        let mut identity_to_json_map: [Field; MaxNumValues] = [0; MaxNumValues];
        // 6.5 gates per iteration
        for i in 0..MaxNumValues {
            let id = ids[i];
            let entry_type = entry_types[i];
            // 2 gates
            let update = TOKEN_BEGINS_OBJECT_OR_ARRAY[entry_type];
            // NOTE THIS RELIES ON MaxNumValues ACTUALLY DESCRIBING NUMMaxNumValues + 1
            // 1 gate
            let index = (id - (MaxNumValues as Field - 1)) * update + (MaxNumValues as Field - 1);
            // 3.5 gates
            identity_to_json_map[index] = i as Field;
        }

        // 13.5 gates per iteration
        let mut parent_identity_pre = parent_indices[0];
        for i in 1..MaxNumValues {
            let parent_identity_post = parent_indices[i];
            // if the parent identity changes,

            // the list is sorted according to parent_ideneity,
            // so parent_identity increments in steps of 0 or 1
            // 1 gate
            let new_parent = parent_identity_post - parent_identity_pre;

            // 3.5 gates
            let index_of_parent = identity_to_json_map[parent_identity_post];

            // 1 gate + 3.5 gates
            let updated = JSONEntry::add_child_pointer_into_field(sorted_entries[index_of_parent], i as Field);

            // RELIES ON THE SMALLEST ENTRY IN THE SORTED LIST BEING EMPTY
            // 1 gate
            let index = (index_of_parent * new_parent);
            // 3.5 gates
            sorted_entries[index] = updated;

            parent_identity_pre = parent_identity_post;
        }
        sorted_entries[0] = 0; // TODO document why we want to always make 0 a dead entry
        self.packed_json_entries = sorted_entries;
        self.key_hashes = sort_result.sorted;
        self.set_root_entry();
    }

    unconstrained fn __find_root_entry(self) -> Field {
        let mut found_index = 0;
        for i in 0..MaxNumValues {
            let entry = JSONEntry::from_field(self.packed_json_entries[i]);
            if (entry.parent_index == 0) & (self.packed_json_entries[i] != 0) {
                found_index = i as Field;
                break;
            }
        }
        found_index
    }

    fn set_root_entry(&mut self) {
        let root_index = self.__find_root_entry();

        let packed_entry = self.packed_json_entries[root_index];
        let entry = JSONEntry::from_field(packed_entry);

        assert(packed_entry != 0);
        assert(entry.parent_index == 0);
        self.layer_index_in_transcript = root_index;
    }
}

// 68002
