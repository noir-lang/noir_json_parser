use crate::redux::JSON;
use crate::json_entry::JSONEntry;
use crate::lt::lt_field_16_bit;
use crate::lt::lte_field_240_bit;
use crate::lt::assert_lte_240_bit;
use crate::redux::BEGIN_OBJECT_TOKEN;
use crate::redux::BEGIN_ARRAY_TOKEN;

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
            + self.json_index * 0x10000
            + self.json_length * 0x100000000
            + self.array_index * 0x1000000000000
    }

    fn from_field(packed: Field) -> Self {
        let unpacked = packed.to_be_bytes(8);
        let array_index: Field = unpacked[1] as Field + unpacked[0] as Field * 0x100;
        let json_length: Field = unpacked[3] as Field + unpacked[2] as Field * 0x100;
        let json_index: Field = unpacked[5] as Field + unpacked[4] as Field * 0x100;
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
impl<let NumBytes: u32, let TranscriptEntries: u32> JSON<NumBytes, TranscriptEntries> {

    fn get_keyhash(self, json_index: Field, json_length: Field) -> Field {
        let mut result: [u8; KeyLen] = [0; KeyLen];

        let key_length = json_length;
        println(f"json len = {json_length}");
        assert(key_length as u32 < 32, "key too large"); // todo fix cast
        //  assert(lt_field_16_bit(key_length, 32), "key too large");
        for i in 0..32 {
            if (i < key_length as u32) { // TODO fix cast
                //  if lt_field_16_bit(i as Field, key_length) {
                let byte = self.json[json_index + i as Field as Field];
                result[i] = byte;
            }
        }
        println(f"TRANSCRIPT KEY HASH PREIMAGE {result}");
        // TGODO replace with cheaper hash!
        let hashed= dep::std::hash::blake2s(result);
        //    let hashed = fakehash(result); // dep::std::hash::blake2s(result);

        let mut result: Field = 0;
        // 200 bits
        for i in 0..25 {
            result *= 0x100;
            result += hashed[25 - i] as Field;
        }
        // let key_len = entry.
        result
    }

    fn compute_keyhash_and_sort_json_entries(&mut self) {
        let mut hashlist: [Field; TranscriptEntries] = [0; TranscriptEntries];

        let two_pow_200 = 0x10000000000000000000000000000000000000000000000000000;
        let two_pow_216 = 0x100000000000000000000000000000000000000000000000000000000;
        for i in 0..TranscriptEntries {
            let KeyIndexData{ json_index, json_length, parent_id, array_index } = KeyIndexData::from_field(self.key_data[i]);
            println(f"i = {i}, JSON LENGTH  = {json_length}");
            let ff = self.get_keyhash(json_index, json_length);
            hashlist[i] = self.get_keyhash(json_index, json_length) + array_index * two_pow_200 + parent_id * two_pow_216;
            println(
                f"HASHLIST[{i}], BASE KEYHASH = {ff}, JSON_INDEX = {json_index}, JSON_LENGTH = {json_length}, ARRAY_INDEX = {array_index}, PARENT_ID = {parent_id}"
            );
            let woo = KeyIndexData::from_field(self.key_data[i]);
            let hashx = hashlist[i];
            println(f"key data[{i}] = {woo}, hash = {hashx}");
        }

        // ok the next pile of bullshit follows
        // we need to sort the JSON entries accordingf to the keyhash sort pattern
        // once we do that we can *finally* move on to extracting data from the json, maybe
        let sort_result = noir_sort::sort_advanced(hashlist, lte_field_240_bit, assert_lte_240_bit);
        for i in 0..TranscriptEntries {
            let xx = hashlist[i];
            println(f"original[{i}] = {xx}");
        }
        for i in 0..TranscriptEntries {
            let xx = sort_result.sorted[i];
            println(f"sorted[{i}] = {xx}");
        }
        let ff = sort_result.sort_indices;
        let mut x: [u32; TranscriptEntries] = [0; TranscriptEntries];
        for i in 0..TranscriptEntries {
            x[i] = ff[i] as u32;
        }
        println(f"sort indices = {x}");
        let mut sorted_entries: [JSONEntry; TranscriptEntries] = [JSONEntry::new(); TranscriptEntries];
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
        for i in 0..TranscriptEntries {
            sorted_entries[sort_result.sort_indices[i]] = self.json_entries[i];
        }

        let mut identity_to_json_map: [Field; TranscriptEntries] = [0; TranscriptEntries];
        for i in 0..TranscriptEntries {
            let E = sorted_entries[i];
            if ((E.entry_type == BEGIN_OBJECT_TOKEN) | (E.entry_type == BEGIN_ARRAY_TOKEN)) {
                identity_to_json_map[E.id] = i as Field;
            }
        }
        for i in 0..TranscriptEntries - 1 {
            let parent_identity_pre = sorted_entries[i].parent_index;
            let parent_identity_post = sorted_entries[i + 1].parent_index;
            // if the parent identity changes,
            let new_parent = parent_identity_post != parent_identity_pre;
            if (new_parent) {
                let index_of_parent = identity_to_json_map[parent_identity_post];
                println(
                    f"found parent. child is i = {i}, index of parent = {index_of_parent}, parent identity = {parent_identity_post}"
                );

                sorted_entries[index_of_parent].child_pointer = i as Field + 1;
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
        self.json_entries = sorted_entries;
        for i in 0..TranscriptEntries {
            let xx = sorted_entries[i];
            println(f"sortd entries[{i}] = {xx}");
        }
        self.key_hashes = sort_result.sorted;
    }
}

