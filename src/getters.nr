use crate::test_data::JSON_WITH_ARRAYS;
use dep::noir_sort;
use crate::transcript_entry::TranscriptEntry;
use crate::json_entry::JSONEntry;
use crate::redux::JSON;
use crate::keymap;
use crate::lt::{lt_field_8_bit, lt_field_16_bit, assert_lt_240_bit, assert_gt_240_bit};
use crate::redux_tables::{
    OBJECT_LAYER, ARRAY_LAYER, NUMERIC_TOKEN, LITERAL_TOKEN, STRING_TOKEN, BEGIN_OBJECT_TOKEN,
    BEGIN_ARRAY_TOKEN, ASCII_TO_NUMBER
};
use crate::keyhash::Hasher;
use crate::keyhash::get_keyhash;
use crate::slice_field::slice_fields;

struct KeySearchResult {
    found: bool,
    target_lt_smallest_entry: bool,
    target_gt_largest_entry: bool,
    lhs_index: Field,
    rhs_index: Field,
}

struct JSONValue<let MaxLength: u32> {
    length: Field,
    value: [u8; MaxLength],
    value_type: Field
}
// struct JSONLiteral {
//     value: Field,
// }

impl<let MaxLength: u32> JSONValue<MaxLength> {
    fn is_string(self) -> bool {
        self.value_type == STRING_TOKEN
    }
    fn is_number(self) -> bool {
        self.value_type == NUMERIC_TOKEN
    }
    fn is_literal(self) -> bool {
        self.value_type == LITERAL_TOKEN
    }
}

// impl JSONLiteral {
//     fn is_true(self) -> bool {
//         self.value == 2
//     }
//     fn is_null(self) -> bool {
//         self.value == 1
//     }
//     fn is_false(self) -> bool {
//         self.value == 0
//     }
//     fn to_bool(self) -> bool {
//         self.value == 2
//     }
// }

struct StringChopper<let NeedlePackedFields: u16> {

}

impl<let NeedlePackedFields: u16> StringChopper<NeedlePackedFields> {
    fn slice_string<let StringBytes: u16, let HaystackPackedFields: u16>(
        _: Self,
        haystack: [Field; HaystackPackedFields],
        start_bytes: Field,
        num_bytes: Field
    ) -> [u8; StringBytes] {
        let mut parsed_string: [u8; StringBytes] = [0; StringBytes];

        let sliced: [Field; NeedlePackedFields] = slice_fields(haystack, start_bytes, num_bytes);

        let sliced_bytes = sliced.map(|x: Field| { let r: [u8; 31] = x.to_be_bytes(31).as_array(); r });

        let num_slices = StringBytes / 31;
        let overflow = StringBytes % 31;
        for i in 0..num_slices {
            for j in 0..31 {
                parsed_string[i * 31 + j] = sliced_bytes[i][j];
            }
        }
        for j in 0..overflow {
            parsed_string[num_slices * 31 + j] = sliced_bytes[num_slices][j];
        }
        parsed_string
    }
}

impl<let NumBytes: u32, let NumPackedFields: u16, let MaxNumTokens: u16, let MaxNumValues: u16> JSON<NumBytes,NumPackedFields, MaxNumTokens, MaxNumValues> {

    fn get_json_entry_unchecked<let KeyBytes: u16>(self, key: [u8; KeyBytes]) -> JSONEntry {
        assert(self.layer_context != ARRAY_LAYER, "cannot extract array elements via a key");

        let keyhash = get_keyhash(key, 0, KeyBytes);
        let two_pow_216 = 0x100000000000000000000000000000000000000000000000000000000;

        let keyhash = keyhash + (self.layer_id + 1) * two_pow_216;

        let key_index = self.find_key_in_map(keyhash);

        assert(self.key_hashes[key_index] == keyhash, "get_json_entry_unchecked: key not found");
        let entry: JSONEntry = JSONEntry::from_field(self.packed_json_entries[key_index]);

        entry
    }

    fn get_json_entry_unchecked_var<let KeyBytes: u16>(self, key: [u8; KeyBytes], keylen: u16) -> JSONEntry {
        assert(self.layer_context != ARRAY_LAYER, "cannot extract array elements via a key");

        let keyhash = get_keyhash(key, 0, keylen);
        let two_pow_216 = 0x100000000000000000000000000000000000000000000000000000000;

        let keyhash = keyhash + (self.layer_id + 1) * two_pow_216;

        let key_index = self.find_key_in_map(keyhash);

        assert(self.key_hashes[key_index] == keyhash, "get_json_entry_unchecked: key not found");
        let entry: JSONEntry = JSONEntry::from_field(self.packed_json_entries[key_index]);

        entry
    }

    fn get_json_entry_unchecked_with_key_index_var<let KeyBytes: u16>(self, key: [u8; KeyBytes], keylen: u16) -> (JSONEntry, Field) {
        assert(self.layer_context != ARRAY_LAYER, "cannot extract array elements via a key");

        let keyhash = get_keyhash(key, 0, keylen);
        let two_pow_216 = 0x100000000000000000000000000000000000000000000000000000000;

        let keyhash = keyhash + (self.layer_id + 1) * two_pow_216;

        let key_index = self.find_key_in_map(keyhash);

        assert(self.key_hashes[key_index] == keyhash, "get_json_entry_unchecked: key not found");
        let entry: JSONEntry = JSONEntry::from_field(self.packed_json_entries[key_index]);

        (entry, key_index)
    }

    fn get_json_entry<let KeyBytes: u16>(self, key: [u8; KeyBytes]) -> (bool, JSONEntry) {
        // let key_index = self.find_key_in_map(keyhash);
        // assert(self.key_hashes[key_index] == keyhash);
        assert(self.layer_context != ARRAY_LAYER, "cannot extract array elements via a key");

        let (exists, key_index) = self.key_exists_impl(key, KeyBytes);
        let entry: JSONEntry = JSONEntry::from_field(self.packed_json_entries[key_index]);
        (exists, entry)
    }

    fn get_json_entry_var<let KeyBytes: u16>(self, key: [u8; KeyBytes], keylen: u16) -> (bool, JSONEntry) {
        // let key_index = self.find_key_in_map(keyhash);
        // assert(self.key_hashes[key_index] == keyhash);
        assert(self.layer_context != ARRAY_LAYER, "cannot extract array elements via a key");

        let (exists, key_index) = self.key_exists_impl(key, keylen);
        let entry: JSONEntry = JSONEntry::from_field(self.packed_json_entries[key_index]);
        (exists, entry)
    }

    fn extract_string_entry<let StringBytes: u16>(self, entry: JSONEntry) -> [u8; StringBytes] {
        // todo can we make this faster? witness gen for this method is slow
        // TODO: document that StringBytes parameter includes non-escaped characters
        assert(
            lt_field_16_bit(entry.json_length, StringBytes as Field + 1), "get_string, string size is larger than StringBytes"
        );

        let mut result: [u8; StringBytes] = [0; StringBytes];
        if (StringBytes <= 31)
        {
            let s: StringChopper<1> = StringChopper{};
            result = s.slice_string(self.packed_json, entry.json_pointer, entry.json_length);
        }
        else if (StringBytes <= 62)
        {
            let s: StringChopper<2> = StringChopper{};
            result = s.slice_string(self.packed_json, entry.json_pointer, entry.json_length);
        }
        else if (StringBytes <= 93)
        {
            let s: StringChopper<3> = StringChopper{};
            result = s.slice_string(self.packed_json, entry.json_pointer, entry.json_length);
        }
        else if (StringBytes <= 124)
        {
            let s: StringChopper<4> = StringChopper{};
            result = s.slice_string(self.packed_json, entry.json_pointer, entry.json_length);
        }
        else if (StringBytes <= 155)
        {
            let s: StringChopper<5> = StringChopper{};
            result = s.slice_string(self.packed_json, entry.json_pointer, entry.json_length);
        }
        else if (StringBytes <= 186)
        {
            let s: StringChopper<6> = StringChopper{};
            result = s.slice_string(self.packed_json, entry.json_pointer, entry.json_length);
        }
        else if (StringBytes <= 217)
        {
            let s: StringChopper<7> = StringChopper{};
            result = s.slice_string(self.packed_json, entry.json_pointer, entry.json_length);
        }
        else if (StringBytes <= 248) // 8
        {
            let s: StringChopper<8> = StringChopper{};
            result = s.slice_string(self.packed_json, entry.json_pointer, entry.json_length);
        }
        else if (StringBytes <= 496) // 16
        {
            let s: StringChopper<16> = StringChopper{};
            result = s.slice_string(self.packed_json, entry.json_pointer, entry.json_length);
        }
        else if (StringBytes <= 992) // 32
        {
            let s: StringChopper<32> = StringChopper{};
            result = s.slice_string(self.packed_json, entry.json_pointer, entry.json_length);
        }
        else if (StringBytes <= 1984)
        {
            let s: StringChopper<64> = StringChopper{};
            result = s.slice_string(self.packed_json, entry.json_pointer, entry.json_length);
        }
        else if (StringBytes <= 3968)
        {
            let s: StringChopper<128> = StringChopper{};
            result = s.slice_string(self.packed_json, entry.json_pointer, entry.json_length);
        }
        else if (StringBytes <= 7936)
        {
            let s: StringChopper<256> = StringChopper{};
            result = s.slice_string(self.packed_json, entry.json_pointer, entry.json_length);
        }
        else if (StringBytes <= 15872)
        {
            let s: StringChopper<512> = StringChopper{};
            result = s.slice_string(self.packed_json, entry.json_pointer, entry.json_length);
        }
        else if (StringBytes <= 31774)
        {
            let s: StringChopper<1024> = StringChopper{};
        result = s.slice_string(self.packed_json, entry.json_pointer, entry.json_length);
        }
        else
        {
            // max 16 bits = 65535 = 2115 31-byte slices
            let s: StringChopper<2115> = StringChopper{};
            result = s.slice_string(self.packed_json, entry.json_pointer, entry.json_length);

        }
        result
    }

    unconstrained fn find_key_in_map(self, target: Field) -> Field {
        let mut found_index: Field = 0;
        let mut found: bool = false;
        for i in 0..MaxNumValues {
            let key_hash= self.key_hashes[i];
            if (key_hash == target) {
                found_index = i as Field;
                found = true;
                break;
            }
        }
        assert(found, "find_key_in_map, key not found");
        found_index
    }

    unconstrained fn search_for_key_in_map(self, target: Field) -> KeySearchResult {
        let mut found_index: Field = 0;
        let mut found: bool = false;

        let mut lhs_maximum: Field = 0;
        let mut rhs_minimum: Field = -1;
        let mut lhs_maximum_index: Field = 0;
        let mut rhs_minimum_index: Field = 0;
        for i in 0..MaxNumValues {
            let key_hash= self.key_hashes[i];
            if (key_hash == target) {
                found_index = i as Field;
                found = true;
                break;
            } else {
                if key_hash.lt(target) & (lhs_maximum.lt(key_hash)) {
                    lhs_maximum = key_hash;
                    lhs_maximum_index = i as Field;
                }
                if (target.lt(key_hash)) & (key_hash.lt(rhs_minimum)) {
                    rhs_minimum = key_hash;
                    rhs_minimum_index = i as Field;
                }
            }
        }
        let target_lt_smallest_entry = target.lt(self.key_hashes[0]);
        let target_gt_largest_entry = self.key_hashes[MaxNumValues - 1].lt(target);

        let result_not_first_or_last = !target_lt_smallest_entry & !target_gt_largest_entry & !found;

        let mut lhs_index = result_not_first_or_last as Field * lhs_maximum_index;
        let mut rhs_index = result_not_first_or_last as Field * rhs_minimum_index;

        // if target_lt_smallest_entry, rhs_index = 0
        // if target_gt_largest_entry, lhs_index = TranscriptEntries - 1
        rhs_index = rhs_index * (1 - target_lt_smallest_entry as Field);

        // we rely here on the fact that target_gt_largest_entry and result_not_first_or_last are mutually exclusive
        lhs_index = lhs_index  + target_gt_largest_entry as Field * (MaxNumValues as Field - 1);

        // If target is FOUND, we want the following:
        // keyhash[target_index] - 1 < hash < keyhash[target_index] + 1
        lhs_index = lhs_index  + found as Field * found_index;
        rhs_index = rhs_index  + found as Field * found_index;

        KeySearchResult { found, target_lt_smallest_entry, target_gt_largest_entry, lhs_index, rhs_index }
    }

    // fn get_length(self) -> u32 {
    //     assert(self.layer_context == ARRAY_LAYER, "can only get length of an array type");
    //     let parent_entry = JSONEntry::from_field(self.packed_json_entries[self.layer_index_in_transcript]);
    //     parent_entry.num_children as u32
    // }

    // fn get_array<let KeyBytes: u16>(self, key: [u8; KeyBytes], key_length: u16) -> Option<Self> {
    //     assert(self.layer_context != ARRAY_LAYER, "cannot extract array elements via a key");
    //     let (exists, key_index) = self.key_exists_impl(key, key_length);
    //     let entry: JSONEntry = JSONEntry::from_field(self.packed_json_entries[key_index]);

    //     // TODO: ADD A layer_context VARIABLE INTO JSON WHICH DESCRIBES WHETHER WE ARE AN OBJECT, ARRAY OR SINGLE VALUE
    //     assert(entry.entry_type == BEGIN_ARRAY_TOKEN, "key does not describe an object");

    //     let mut result: Option<JSON<NumBytes, NumPackedFields, MaxNumTokens, MaxNumValues>> = Option::none();
    //     if (exists) {
    //         let mut r = self;
    //         r.layer_id = entry.parent_index;
    //         r.layer_context = ARRAY_LAYER;
    //         r.layer_index_in_transcript = key_index;
    //         result = Option::some(r);
    //     }
    //     result
    // }

    // fn get_array_element_as_number(self, array_index: Field) -> u64 {
    //     assert(self.layer_context == ARRAY_LAYER, "can only acceess array elements from array");

    //     let parent_entry = JSONEntry::from_field(self.packed_json_entries[self.layer_index_in_transcript]);

    //     let valid = lt_field_16_bit(array_index, parent_entry.num_children);
    //     let entry_index = (parent_entry.child_pointer + array_index) * valid as Field;

    //     let entry = JSONEntry::from_field(self.packed_json_entries[entry_index]);

    //     assert(entry.entry_type == NUMERIC_TOKEN, "get_number: entry exists but is not a number!");
    //     // TODO replace with something more efficient
    //     assert(
    //         lt_field_16_bit(entry.json_length, 9), "get_number: number exceeds u64 size. Not currently supported."
    //     );

    //     let mut parsed_number: Field = 0;
    //     for i in 0..8 {
    //         let valid = lt_field_16_bit(i as Field, entry.json_length);

    //         parsed_number *= (10 * valid as Field + (1 - valid as Field));

    //         // n.b. conditionally setting index to 0 can be removed if we ensure json is padded such that this index does not overflow json bytes
    //         let byte = self.json[(entry.json_pointer + i as Field) * valid as Field];
    //         let value = ASCII_TO_NUMBER[byte] as Field * valid as Field;
    //         parsed_number += value;
    //     }

    //     // todo find cheaper way of converting
    //     parsed_number as u64
    // }

    // fn map<U, let MaxElements: u32, let MaxElementBytes: u32>(
    //     self,
    //     f: fn(JSONValue<MaxElementBytes>) -> U
    // ) -> [U; MaxElements] where U: std::default::Default {
    //     assert(self.layer_context == ARRAY_LAYER, "can only call map on an array");

    //     let entry = JSONEntry::from_field(self.packed_json_entries[self.layer_index_in_transcript]);

    //     let num_children = entry.num_children;
    //     let mut r: [U; MaxElements] = [U::default(); MaxElements];

    //     for i in 0..MaxElements {
    //         let valid = lt_field_16_bit(i as Field, num_children);
    //         let entry_index = (entry.child_pointer + i as Field) * valid as Field;
    //         let child_entry = JSONEntry::from_field(self.packed_json_entries[entry_index]);

    //         let mut parsed_string: [u8; MaxElementBytes] = [0; MaxElementBytes];
    //         for j in 0..MaxElementBytes {
    //             let byte_valid = lt_field_16_bit(j as Field, child_entry.json_length);
    //             // n.b. conditionally setting index to 0 can be removed if we ensure json is padded such that this index does not overflow json bytes
    //             let byte = self.json[(child_entry.json_pointer + i as Field) * valid as Field];
    //             // TODO improve efficiency? measure...
    //             if (byte_valid) {
    //                 parsed_string[i] = byte;
    //             }
    //         }

    //         if (valid) {
    //             r[i] = f(
    //                 JSONValue { length: child_entry.json_length, value: parsed_string, value_type: child_entry.entry_type }
    //             );
    //         }
    //     }
    //     r
    // }

    fn assert_key_exists_with_known_length<let KeyBytes: u16>(self, key: [u8; KeyBytes]) {
        let keyhash = get_keyhash(key, 0, KeyBytes);
        let two_pow_216 = 0x100000000000000000000000000000000000000000000000000000000;

        let keyhash = keyhash + (self.layer_id + 1) * two_pow_216;

        let key_index = self.find_key_in_map(keyhash);

        assert(self.key_hashes[key_index] == keyhash);
    }

    fn key_exists<let KeyBytes: u16>(self, key: [u8; KeyBytes], key_length: u16) -> bool {
        self.key_exists_impl(key, key_length).0
    }
    fn key_exists_impl<let KeyBytes: u16>(
        self,
        key: [u8; KeyBytes],
        key_length: u16
    ) -> (bool, Field) {
        /*
            Option A: key exists
            Option B: key does NOT exist

            If key does NOT exist. 3 cases
            case 1: keyhash < first entry
            case 2: keyhash > last entry
            case 3: entry A > keyhash > entryB 

        */
        let keyhash = get_keyhash(key, 0, key_length);

        let HASH_MAXIMUM = 0x1000000000000000000000000000000000000000000000000000000000000 - 1;
        let two_pow_216 = 0x100000000000000000000000000000000000000000000000000000000;

        let keyhash = keyhash + (self.layer_id + 1) * two_pow_216;

        let search_result = self.search_for_key_in_map(keyhash);
        let found = search_result.found as Field;

        let target_lt_smallest_entry = search_result.target_lt_smallest_entry as Field;
        let target_gt_largest_entry = search_result.target_gt_largest_entry as Field;
        // if does NOT exist. I want result in the following relation:

        // X < keyhash < Y

        // if case 1. X = 0, Y = first entry
        // if case 2. X = last_entry, Y = -1
        // if case 3: X = A, Y = B (from hash map)

        // TODO: all of this logic to compute lhs_index, rhs_index can be shoved into unconstrained fn
        // let mut lhs_index = result_not_first_or_last * search_result.lhs_maximum_index;
        // let mut rhs_index = result_not_first_or_last * search_result.rhs_minimum_index;

        // // if target_lt_smallest_entry, rhs_index = 0
        // // if target_gt_largest_entry, lhs_index = TranscriptEntries - 1
        // rhs_index = rhs_index * (1 - search_result.target_lt_smallest_entry);

        // // we rely here on the fact that target_gt_largest_entry and result_not_first_or_last are mutually exclusive
        // lhs_index = lhs_index  + search_result.target_gt_largest_entry * (TranscriptEntries as Field - 1);

        // // If target is FOUND, we want the following:
        // // keyhash[target_index] - 1 < hash < keyhash[target_index] + 1
        // lhs_index = lhs_index  + search_result.found as Field * search_result.found_index;
        // rhs_index = rhs_index  + search_result.found as Field * search_result.found_index;
        // If search_result.found, assert lhs == rhs
        // assert target_lt_smallest_entry , target_gt_largest_entry, search_result.found are exclusive
        assert(((search_result.lhs_index - search_result.rhs_index) * found) == 0);

        // only one of "found", "target_lt_smallest_entry", "target_gt_largest_entry" can be true
        let exclusion_test = found + target_gt_largest_entry + target_lt_smallest_entry;
        assert(exclusion_test * exclusion_test == exclusion_test);

        let mut lhs = self.key_hashes[search_result.lhs_index];
        let mut rhs = self.key_hashes[search_result.rhs_index];

        // case where hash < self.key_hashes[0]
        // 0 < hash < hashes[0]
        lhs = lhs * (1 - target_lt_smallest_entry);

        // case where hash > self.key_hashes[last]
        // largest < x < -1
        rhs = rhs * (1 - target_gt_largest_entry) + target_gt_largest_entry * HASH_MAXIMUM;

        // case where hash == self.key_hashes[found_index]
        lhs = lhs - found;
        rhs = rhs + found;

        /*
            if target_gt_largest_entry
            we want lhs < hash < 2^240 - 1?

        */
        // 1 gate to update lhs
        // 1 gate to update rhs
        // 2 gates to read lhs (3.5?)
        // 2 gates to read rhs (3.5?)
        // 2 gates to assert lhs_index == rhs_index if found == true
        // 2 gates for exclusion test
        // 3 gates for bools returned by unconstrained fn
        // 1 gate to update keyhash
        // 23 gates: 240 bit range checks * 2 (18 14-bit slices = 6 gates + 4.5 range checks + 1 for diff = 11.5 * 2 = 23)
        // ?? gates for keyhash

        // 14 gates for logic + 23 gates for range checks + keyhash gates (0 if constant?)
        // 37 gates? not the worst in the world
        // If target is FOUND, then keyhash == entry
        // to massage into X < keyhash < Y
        // we make relation equivalent to 0 < 1 < 2
        // lhs = lhs * (1 - found as Field);
        // rhs = rhs * (1 - found as Field) + 2 * (found as Field);
        // let search_target = keyhash * (1 - found as Field) + found as Field;
        assert_gt_240_bit(keyhash, lhs);
        assert_lt_240_bit(keyhash, rhs);

        // If keyhash == target
        // let target_index = search_result.found as Field * search_result.found_index;
        // let target_hash = self.key_hashes[target_index];

        // assert((target_hash - keyhash) * search_result.found as Field == 0);

        (search_result.found, search_result.lhs_index)
    }
}
