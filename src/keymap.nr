use crate::redux::JSON;
use crate::json_entry::JSONEntry;
use crate::lt::lt_field_16_bit;
use crate::lt::lte_field_240_bit;
use crate::lt::assert_lte_240_bit;
use crate::redux::BEGIN_OBJECT_TOKEN;
use crate::redux::BEGIN_ARRAY_TOKEN;
use crate::keyhash::get_keyhash_old;
use crate::keyhash::get_keyhash;
use crate::keyhash::get_keyhash_chunky;

use dep::noir_sort;

use dep::std::hash::poseidon2;
struct KeyIndexData {
    json_index: u16,
    json_length: u16,
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

    fn from_field(packed: Field) -> Self {
        let unpacked = packed.to_be_bytes(8);
        let array_index: Field = unpacked[1] as Field + unpacked[0] as Field * 0x100;
        let json_length: u16 = unpacked[3] as u16 + unpacked[2] as u16 * 0x100;
        let json_index: u16 = unpacked[5] as u16 + unpacked[4] as u16 * 0x100;
        let parent_id: Field = unpacked[7] as Field + unpacked[6] as Field * 0x100;
        KeyIndexData { json_index, json_length, parent_id, array_index }
    }
}

fn fakehash<let N: u32>(input: [u8; N]) -> [u8; 32] {
    let mut r = 0;
    for i in 0..N {
        r *= 0x100;
        r += input[i] as Field;
    }
    r *= 0xffee134029374623874;
    r.to_be_bytes(32).as_array()
}

global KeyLen = 32; // todo make param

// global BYTE_MULTIPLIERS: [Field; 31] = [
//     1,
//     0x100,
//     0x10000,
//     0x1000000,
//     0x100000000,
//     0x10000000000,
//     0x1000000000000,
//     0x100000000000000,
//     0x10000000000000
// ]

impl<let NumBytes: u32, let NumPackedFields: u16, let TranscriptEntries: u32> JSON<NumBytes, NumPackedFields, TranscriptEntries> {
    // 101,105
    // 56,876
    // 44,229 cost
    // 700 per iteration
    // TODO: is poseidon2 cheap??? sounds like
    fn compute_keyhash_and_sort_json_entries(&mut self) {
        let mut hashlist: [Field; TranscriptEntries] = [0; TranscriptEntries];

        let two_pow_200 = 0x10000000000000000000000000000000000000000000000000000;
        let two_pow_216 = 0x100000000000000000000000000000000000000000000000000000000;
        for i in 0..TranscriptEntries {
            let KeyIndexData{ json_index, json_length, parent_id, array_index } = KeyIndexData::from_field(self.key_data[i]);
            hashlist[i] = get_keyhash_chunky(self.json, json_index, json_length) + array_index * two_pow_200 + parent_id * two_pow_216;
        }
        // ok the next pile of bullshit follows
        // we need to sort the JSON entries accordingf to the keyhash sort pattern
        // once we do that we can *finally* move on to extracting data from the json, maybe
        //  = self.json_entries;
        // TODO THIS SHOULD NOT BE HERE, MESSY
        // let mut parent_indices: [Field; TranscriptEntries] = [0; TranscriptEntries];
        // for i in 0..TranscriptEntries {
        //     let E = self.json_entries[i];
        //     if (E.child_pointer != 0) {
        //         let child_idx = E.child_pointer;
        //         let parent_identity = self.json_entries[child_idx].parent_index;
        //         parent_indices[parent_identity] = child_idx;
        //     }
        // }
        // we want a list that maps parent ID to json entry
        // if I know that parent id 5 maps to idx 19 that is important
        // ok so now we have, for ONE child, the location of the parent
        //

        let sort_result = noir_sort::sort_advanced(hashlist, lte_field_240_bit, assert_lte_240_bit);
        let mut sorted_entries: [Field; TranscriptEntries] = [0; TranscriptEntries];

        for i in 0..TranscriptEntries {
            sorted_entries[sort_result.sort_indices[i]] = self.packed_json_entries[i];
        }

        let mut identity_to_json_map: [Field; TranscriptEntries] = [0; TranscriptEntries];
        for i in 0..TranscriptEntries {
            let E = JSONEntry::from_field(sorted_entries[i]);
            //let update = ((E.entry_type == BEGIN_OBJECT_TOKEN) | (E.entry_type == BEGIN_ARRAY_TOKEN));
            // NOTE THIS RELIES ON TRANSCRIPTENTRIES ACTUALLY DESCRIBING NUMTRANSCRIPTENTRIES + 1
            // let index = (E.id - (TranscriptEntries as Field - 1)) * update as Field
            //     + (TranscriptEntries as Field - 1);
            // identity_to_json_map[index] = i as Field;
            if ((E.entry_type == BEGIN_OBJECT_TOKEN) | (E.entry_type == BEGIN_ARRAY_TOKEN)) {
                identity_to_json_map[E.id] = i as Field;
            }
        }

        for i in 0..TranscriptEntries - 1 {
            let parent_identity_pre = JSONEntry::from_field(sorted_entries[i]).parent_index;
            let parent_identity_post = JSONEntry::from_field(sorted_entries[i + 1]).parent_index;
            // if the parent identity changes,
            let new_parent = parent_identity_post != parent_identity_pre;

            let index_of_parent = identity_to_json_map[parent_identity_post];
            // let mut updated = JSONEntry::from_field(sorted_entries[index_of_parent]);
            // updated.child_pointer = i as Field + 1;

            // // RELIES ON THE SMALLEST ENTRY IN THE SORTED LIST BEING EMPTY
            // let index = ((index_of_parent - 0) * new_parent as Field) + 0;

            // sorted_entries[index] = updated.to_field();
            if (new_parent) {
                let index_of_parent = identity_to_json_map[parent_identity_post];
                let mut updated = JSONEntry::from_field(sorted_entries[index_of_parent]);
                updated.child_pointer = i as Field + 1;
                sorted_entries[index_of_parent] = updated.to_field();
            }
            // i + 1 is the starting index of a new set of children
        }

        // phew need to consolidate.
        // 1: throw unused code in a scrapbook
        // 2: tidy data structures and remove unused fluff
        // 3: add metadata to JSON objeect so that we can query internal parts

        // 4: do we need a different interface for a JSON Object vs JSON Array?
        // for i in 0..TranscriptEntries {
        //     let old_child_pointer = sorted_entries[i].child_pointer;

        //     let new_child_pointer = sort_result.sort_indices[old_child_pointer];
        //     // TODO: hacky workaround, fix
        //     if (old_child_pointer != 0) {
        //         sorted_entries[i].child_pointer = new_child_pointer;
        //     }
        // }
        self.packed_json_entries = sorted_entries;

        self.key_hashes = sort_result.sorted;
    }
}

