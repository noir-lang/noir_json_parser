use crate::test_data::JSON_WITH_ARRAYS;
use crate::transcript_entry::TranscriptEntry;
use crate::json_entry::JSONEntry;
use crate::json::JSON;
use crate::lt::{lt_field_16_bit, assert_lt_240_bit, assert_gt_240_bit};
use crate::enums::Token::{NUMERIC_TOKEN, LITERAL_TOKEN, STRING_TOKEN};
use crate::enums::Layer::{OBJECT_LAYER, ARRAY_LAYER};
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
    value: BoundedVec<u8, MaxLength>,
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

/**
 * @brief helper methods for extracting data out of a processed JSON object
 **/
impl<let NumBytes: u32, let NumPackedFields: u16, let MaxNumTokens: u16, let MaxNumValues: u16> JSON<NumBytes,NumPackedFields, MaxNumTokens, MaxNumValues> {

    /**
     * @brief If the root JSON is an object, extract a JSONEntry that describes an array, object or value that maps to a given key
     * @description returns an Option<JSONEntry> which will be null if the entry does not exist  
     **/
    fn get_json_entry<let KeyBytes: u16>(self, key: [u8; KeyBytes]) -> (bool, JSONEntry) {
        // let key_index = self.find_key_in_map(keyhash);
        // assert(self.key_hashes[key_index] == keyhash);
        assert(self.layer_type_of_root != ARRAY_LAYER, "cannot extract array elements via a key");

        let (exists, key_index) = self.key_exists_impl(key, KeyBytes);
        let entry: JSONEntry = self.json_entries_packed[key_index].into();
        (exists, entry)
    }

    /**
     * @brief If the root JSON is an object, extract a JSONEntry that describes an array, object or value that maps to a given key
     * @note will revert if the key does not exist
     **/
    fn get_json_entry_unchecked<let KeyBytes: u16>(self, key: [u8; KeyBytes]) -> JSONEntry {
        assert(self.layer_type_of_root != ARRAY_LAYER, "cannot extract array elements via a key");

        let keyhash = get_keyhash(key, 0, KeyBytes);
        let two_pow_216 = 0x100000000000000000000000000000000000000000000000000000000;

        let keyhash = keyhash + self.root_id * two_pow_216;

        let key_index = self.find_key_in_map(keyhash);

        assert(self.key_hashes[key_index] == keyhash, "get_json_entry_unchecked: key not found");
        let entry: JSONEntry = self.json_entries_packed[key_index].into();

        entry
    }

    /**
     * @brief same as `get_json_entry` but the key length may be less than KeyBytes
     **/
    fn get_json_entry_var<let KeyBytes: u16>(self, key: [u8; KeyBytes], keylen: u16) -> (bool, JSONEntry) {
        // let key_index = self.find_key_in_map(keyhash);
        // assert(self.key_hashes[key_index] == keyhash);
        assert(self.layer_type_of_root != ARRAY_LAYER, "cannot extract array elements via a key");

        let (exists, key_index) = self.key_exists_impl(key, keylen);
        let entry: JSONEntry = self.json_entries_packed[key_index].into();
        (exists, entry)
    }

    /**
     * @brief same as `get_json_entry_unchecked` but the key length may be less than KeyBytes
     **/
    fn get_json_entry_unchecked_var<let KeyBytes: u16>(self, key: [u8; KeyBytes], keylen: u16) -> JSONEntry {
        assert(self.layer_type_of_root != ARRAY_LAYER, "cannot extract array elements via a key");

        let keyhash = get_keyhash(key, 0, keylen);
        let two_pow_216 = 0x100000000000000000000000000000000000000000000000000000000;

        let keyhash = keyhash + self.root_id * two_pow_216;

        let key_index = self.find_key_in_map(keyhash);

        assert(self.key_hashes[key_index] == keyhash, "get_json_entry_unchecked: key not found");
        let entry: JSONEntry = self.json_entries_packed[key_index].into();

        entry
    }

    /**
     * @brief same as `get_json_entry_unchecked_var` but also returns the position of the JSONEntry in `self.json_entries_packed`
     **/
    fn get_json_entry_unchecked_with_key_index_var<let KeyBytes: u16>(self, key: [u8; KeyBytes], keylen: u16) -> (JSONEntry, Field) {
        assert(self.layer_type_of_root != ARRAY_LAYER, "cannot extract array elements via a key");

        let keyhash = get_keyhash(key, 0, keylen);
        let two_pow_216 = 0x100000000000000000000000000000000000000000000000000000000;

        let keyhash = keyhash + self.root_id * two_pow_216;

        let key_index = self.find_key_in_map(keyhash);

        assert(self.key_hashes[key_index] == keyhash, "get_json_entry_unchecked: key not found");
        let entry: JSONEntry = self.json_entries_packed[key_index].into();

        (entry, key_index)
    }

    /**
     * @brief helper method that will extract an array of bytes that describes the value associated with a JSONEntry object
     * @description e.g. if the JSONEntry describes "foo" : "bar" in the JSON, `extract_string_entry` will return "foo"
     **/
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
            result = s.slice_string(self.json_packed, entry.json_pointer, entry.json_length);
        }
        else if (StringBytes <= 62)
        {
            let s: StringChopper<2> = StringChopper{};
            result = s.slice_string(self.json_packed, entry.json_pointer, entry.json_length);
        }
        else if (StringBytes <= 93)
        {
            let s: StringChopper<3> = StringChopper{};
            result = s.slice_string(self.json_packed, entry.json_pointer, entry.json_length);
        }
        else if (StringBytes <= 124)
        {
            let s: StringChopper<4> = StringChopper{};
            result = s.slice_string(self.json_packed, entry.json_pointer, entry.json_length);
        }
        else if (StringBytes <= 155)
        {
            let s: StringChopper<5> = StringChopper{};
            result = s.slice_string(self.json_packed, entry.json_pointer, entry.json_length);
        }
        else if (StringBytes <= 186)
        {
            let s: StringChopper<6> = StringChopper{};
            result = s.slice_string(self.json_packed, entry.json_pointer, entry.json_length);
        }
        else if (StringBytes <= 217)
        {
            let s: StringChopper<7> = StringChopper{};
            result = s.slice_string(self.json_packed, entry.json_pointer, entry.json_length);
        }
        else if (StringBytes <= 248) // 8
        {
            let s: StringChopper<8> = StringChopper{};
            result = s.slice_string(self.json_packed, entry.json_pointer, entry.json_length);
        }
        else if (StringBytes <= 496) // 16
        {
            let s: StringChopper<16> = StringChopper{};
            result = s.slice_string(self.json_packed, entry.json_pointer, entry.json_length);
        }
        else if (StringBytes <= 992) // 32
        {
            let s: StringChopper<32> = StringChopper{};
            result = s.slice_string(self.json_packed, entry.json_pointer, entry.json_length);
        }
        else if (StringBytes <= 1984)
        {
            let s: StringChopper<64> = StringChopper{};
            result = s.slice_string(self.json_packed, entry.json_pointer, entry.json_length);
        }
        else if (StringBytes <= 3968)
        {
            let s: StringChopper<128> = StringChopper{};
            result = s.slice_string(self.json_packed, entry.json_pointer, entry.json_length);
        }
        else if (StringBytes <= 7936)
        {
            let s: StringChopper<256> = StringChopper{};
            result = s.slice_string(self.json_packed, entry.json_pointer, entry.json_length);
        }
        else if (StringBytes <= 15872)
        {
            let s: StringChopper<512> = StringChopper{};
            result = s.slice_string(self.json_packed, entry.json_pointer, entry.json_length);
        }
        else if (StringBytes <= 31774)
        {
            let s: StringChopper<1024> = StringChopper{};
        result = s.slice_string(self.json_packed, entry.json_pointer, entry.json_length);
        }
        else
        {
            // max 16 bits = 65535 = 2115 31-byte slices
            let s: StringChopper<2115> = StringChopper{};
            result = s.slice_string(self.json_packed, entry.json_pointer, entry.json_length);

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

    /**
     * @brief returns a bool that describes whether a given key exists at the root of the JSON
     **/
    fn key_exists<let KeyBytes: u16>(self, key: [u8; KeyBytes], key_length: u16) -> bool {
        self.key_exists_impl(key, key_length).0
    }

    /**
     * @brief implementation of `key_exists`. returns both a boolean and also the position in `self.json_entries_packed` of the key
     * @description algorithm is O(1) because of the preprocessing we have done
     *              Method computes a key hash and checks whether key hash exists in the list of sorted preprocessed key hashes
     *              If it does *not* exist, we can find two adjacent entries in `key_hashes` where `key_hashes[i]` < target_key_hash < `key_hashes[i+1]`
     **/
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

        let keyhash = keyhash + self.root_id * two_pow_216;

        let search_result = self.search_for_key_in_map(keyhash);
        let found = search_result.found as Field;

        let target_lt_smallest_entry = search_result.target_lt_smallest_entry as Field;
        let target_gt_largest_entry = search_result.target_gt_largest_entry as Field;

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

        assert_gt_240_bit(keyhash, lhs);
        assert_lt_240_bit(keyhash, rhs);

        (search_result.found, search_result.lhs_index)
    }
}
