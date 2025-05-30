use crate::_comparison_tools::lt::{assert_gt_240_bit, assert_lt_240_bit, lt_field_16_bit};
use crate::_string_tools::string_chopper::StringChopper;
use crate::enums::Layer::ARRAY_LAYER;
use crate::json::JSON;
use crate::json_entry::JSONEntry;
use crate::keyhash::ByteHasher;
use crate::keymap::KeyIndexData;
/**
 * @brief records data used to reason about whether a key exists in a json blob
 **/
pub struct KeySearchResult {
    found: bool, // does the key exist?
    target_lt_smallest_entry: bool, // is the target keyhash smaller than the smallest keyhash in self.key_hashes?
    target_gt_largest_entry: bool, // is the target keyhash larger than the largest keyhash in self.key_hashes?
    lhs_index: Field, // either the index of the key being searched for, or the index of the keyhash in self.key_hashes that is closest to keyhash (hash > lhs_index_hash)
    rhs_index: Field, // either the index of the key being searched for, or the index of the keyhash in self.key_hashes that is closest to keyhash (hash < rhs_index_hash)
}

/**
 * @brief helper methods for extracting data out of a processed JSON object
 **/
impl<let NumBytes: u32, let NumPackedFields: u32, let MaxNumTokens: u32, let MaxNumValues: u32, let MaxKeyFields: u32> JSON<NumBytes, NumPackedFields, MaxNumTokens, MaxNumValues, MaxKeyFields> {

    /**
     * @brief If the root JSON is an object, extract a JSONEntry that describes an array, object or value that maps to a given key
     * @description returns an Option<JSONEntry> which will be null if the entry does not exist
     **/
    pub(crate) fn get_json_entry<let KeyBytes: u32>(
        self,
        key: [u8; KeyBytes],
    ) -> (bool, JSONEntry) {
        // let key_index = self.find_key_in_map(keyhash);
        // assert(self.key_hashes[key_index] == keyhash);
        assert(self.layer_type_of_root != ARRAY_LAYER, "cannot extract array elements via a key");

        let (exists, key_index) = self.key_exists_impl(key);
        let entry: JSONEntry = self.json_entries_packed[key_index].into();
        (exists, entry)
    }

    /**
     * @brief If the root JSON is an object, extract a JSONEntry that describes an array, object or value that maps to a given key
     * @note will revert if the key does not exist
     **/
    pub(crate) fn get_json_entry_unchecked<let KeyBytes: u32>(
        self,
        key: [u8; KeyBytes],
    ) -> JSONEntry {
        assert(self.layer_type_of_root != ARRAY_LAYER, "cannot extract array elements via a key");

        let hasher: ByteHasher<MaxKeyFields> = ByteHasher {};
        let keyhash = hasher.get_keyhash_var(key, 0, KeyBytes);
        let two_pow_216 = 0x100000000000000000000000000000000000000000000000000000000;

        let keyhash = keyhash + self.root_id * two_pow_216;

        // Safety: The assertion below checks that the keyhash is stored in the the index returned by the unconstrained function
        let key_index = unsafe { self.find_key_in_map(keyhash) };

        assert(self.key_hashes[key_index] == keyhash, "get_json_entry_unchecked: key not found");
        let entry: JSONEntry = self.json_entries_packed[key_index].into();

        entry
    }

    /**
     * @brief same as `get_json_entry` but the key length may be less than KeyBytes
     **/
    pub(crate) fn get_json_entry_var<let KeyBytes: u32>(
        self,
        key: BoundedVec<u8, KeyBytes>,
    ) -> (bool, JSONEntry) {
        // let key_index = self.find_key_in_map(keyhash);
        // assert(self.key_hashes[key_index] == keyhash);
        assert(self.layer_type_of_root != ARRAY_LAYER, "cannot extract array elements via a key");

        let (exists, key_index) = self.key_exists_impl_var(key);
        let entry: JSONEntry = self.json_entries_packed[key_index].into();
        (exists, entry)
    }

    /**
     * @brief same as `get_json_entry_unchecked` but the key length may be less than KeyBytes
     **/
    pub(crate) fn get_json_entry_unchecked_var<let KeyBytes: u32>(
        self,
        key: BoundedVec<u8, KeyBytes>,
    ) -> JSONEntry {
        assert(self.layer_type_of_root != ARRAY_LAYER, "cannot extract array elements via a key");

        let hasher: ByteHasher<MaxKeyFields> = ByteHasher {};
        let keyhash = hasher.get_keyhash_var(key.storage(), 0, key.len() as u32);
        let two_pow_216 = 0x100000000000000000000000000000000000000000000000000000000;

        let keyhash = keyhash + self.root_id * two_pow_216;

        // Safety: The assertion below checks that the keyhash is stored in the the index returned by the unconstrained function
        let key_index = unsafe { self.find_key_in_map(keyhash) };

        assert(self.key_hashes[key_index] == keyhash, "get_json_entry_unchecked: key not found");
        let entry: JSONEntry = self.json_entries_packed[key_index].into();

        entry
    }

    /**
     * @brief same as `get_json_entry_unchecked_var` but also returns the position of the JSONEntry in `self.json_entries_packed`
     **/
    pub(crate) fn get_json_entry_unchecked_with_key_index<let KeyBytes: u32>(
        self,
        key: [u8; KeyBytes],
    ) -> (JSONEntry, Field) {
        assert(self.layer_type_of_root != ARRAY_LAYER, "cannot extract array elements via a key");

        let hasher: ByteHasher<MaxKeyFields> = ByteHasher {};
        let keyhash = hasher.get_keyhash_var(key, 0, KeyBytes);
        let two_pow_216 = 0x100000000000000000000000000000000000000000000000000000000;

        let keyhash = keyhash + self.root_id * two_pow_216;

        // Safety: The assertion below checks that the keyhash is stored in the the index returned by the unconstrained function
        let key_index = unsafe { self.find_key_in_map(keyhash) };

        assert(self.key_hashes[key_index] == keyhash, "get_json_entry_unchecked: key not found");
        let entry: JSONEntry = self.json_entries_packed[key_index].into();

        (entry, key_index)
    }
    /**
     * @brief same as `get_json_entry_unchecked_var` but also returns the position of the JSONEntry in `self.json_entries_packed`
     **/
    pub(crate) fn get_json_entry_unchecked_with_key_index_var<let KeyBytes: u32>(
        self,
        key: BoundedVec<u8, KeyBytes>,
    ) -> (JSONEntry, Field) {
        assert(self.layer_type_of_root != ARRAY_LAYER, "cannot extract array elements via a key");

        let hasher: ByteHasher<MaxKeyFields> = ByteHasher {};
        let keyhash = hasher.get_keyhash_var(key.storage(), 0, key.len() as u32);
        let two_pow_216 = 0x100000000000000000000000000000000000000000000000000000000;

        let keyhash = keyhash + self.root_id * two_pow_216;

        // Safety: The assertion below checks that the keyhash is stored in the the index returned by the unconstrained function
        let key_index = unsafe { self.find_key_in_map(keyhash) };

        assert(self.key_hashes[key_index] == keyhash, "get_json_entry_unchecked: key not found");
        let entry: JSONEntry = self.json_entries_packed[key_index].into();

        (entry, key_index)
    }

    /**
     * @brief helper method that will extract an array of bytes that describes the value associated with a JSONEntry object
     * @description e.g. if the JSONEntry describes "foo" : "bar" in the JSON, `extract_string_entry` will return "foo"
     **/
    pub(crate) fn extract_string_entry<let StringBytes: u32>(
        self,
        entry: JSONEntry,
    ) -> [u8; StringBytes] {
        // todo can we make this faster? witness gen for this method is slow
        // TODO: document that StringBytes parameter includes non-escaped characters
        assert(
            lt_field_16_bit(entry.json_length, StringBytes as Field + 1),
            "get_string, string size is larger than StringBytes",
        );

        let mut result: [u8; StringBytes] = [0; StringBytes];
        if (StringBytes <= 31) {
            let s: StringChopper<1> = StringChopper {};
            result = s.slice_string(self.json_packed, entry.json_pointer, entry.json_length);
        } else if (StringBytes <= 62) {
            let s: StringChopper<2> = StringChopper {};
            result = s.slice_string(self.json_packed, entry.json_pointer, entry.json_length);
        } else if (StringBytes <= 93) {
            let s: StringChopper<3> = StringChopper {};
            result = s.slice_string(self.json_packed, entry.json_pointer, entry.json_length);
        } else if (StringBytes <= 124) {
            let s: StringChopper<4> = StringChopper {};
            result = s.slice_string(self.json_packed, entry.json_pointer, entry.json_length);
        } else if (StringBytes <= 155) {
            let s: StringChopper<5> = StringChopper {};
            result = s.slice_string(self.json_packed, entry.json_pointer, entry.json_length);
        } else if (StringBytes <= 186) {
            let s: StringChopper<6> = StringChopper {};
            result = s.slice_string(self.json_packed, entry.json_pointer, entry.json_length);
        } else if (StringBytes <= 217) {
            let s: StringChopper<7> = StringChopper {};
            result = s.slice_string(self.json_packed, entry.json_pointer, entry.json_length);
        } else if (StringBytes <= 248) // 8
        {
            let s: StringChopper<8> = StringChopper {};
            result = s.slice_string(self.json_packed, entry.json_pointer, entry.json_length);
        } else if (StringBytes <= 496) // 16
        {
            let s: StringChopper<16> = StringChopper {};
            result = s.slice_string(self.json_packed, entry.json_pointer, entry.json_length);
        } else if (StringBytes <= 992) // 32
        {
            let s: StringChopper<32> = StringChopper {};
            result = s.slice_string(self.json_packed, entry.json_pointer, entry.json_length);
        } else if (StringBytes <= 1984) {
            let s: StringChopper<64> = StringChopper {};
            result = s.slice_string(self.json_packed, entry.json_pointer, entry.json_length);
        } else if (StringBytes <= 3968) {
            let s: StringChopper<128> = StringChopper {};
            result = s.slice_string(self.json_packed, entry.json_pointer, entry.json_length);
        } else if (StringBytes <= 7936) {
            let s: StringChopper<256> = StringChopper {};
            result = s.slice_string(self.json_packed, entry.json_pointer, entry.json_length);
        } else if (StringBytes <= 15872) {
            let s: StringChopper<512> = StringChopper {};
            result = s.slice_string(self.json_packed, entry.json_pointer, entry.json_length);
        } else if (StringBytes <= 31774) {
            let s: StringChopper<1024> = StringChopper {};
            result = s.slice_string(self.json_packed, entry.json_pointer, entry.json_length);
        } else {
            // max 16 bits = 65535 = 2115 31-byte slices
            let s: StringChopper<2115> = StringChopper {};
            result = s.slice_string(self.json_packed, entry.json_pointer, entry.json_length);
        }
        result
    }

    pub(crate) unconstrained fn find_key_in_map(self, target: Field) -> Field {
        let mut found_index: Field = 0;
        let mut found: bool = false;
        for i in 0..MaxNumValues {
            let key_hash = self.key_hashes[i];
            if (key_hash == target) {
                found_index = i as Field;
                found = true;
                break;
            }
        }
        assert(found, "find_key_in_map, key not found");
        found_index
    }

    /**
     * @brief figures out if `target` exists as a key in `self.key_hashes`
     * @details if `target` does not exist, we return the two indicies of adjacent
     *          entries in `self.key_hashes`, lhs_index, rhs_index, where
     *          lhs_index < key_hash < rhs_index
     **/
    pub(crate) unconstrained fn search_for_key_in_map(self, target: Field) -> KeySearchResult {
        let mut found_index: Field = 0;
        let mut found: bool = false;

        let mut lhs_maximum: Field = 0;
        let mut rhs_minimum: Field = -1;
        let mut lhs_maximum_index: Field = 0;
        let mut rhs_minimum_index: Field = 0;
        for i in 0..MaxNumValues {
            let key_hash = self.key_hashes[i];
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

        let result_not_first_or_last =
            !target_lt_smallest_entry & !target_gt_largest_entry & !found;

        let mut lhs_index = result_not_first_or_last as Field * lhs_maximum_index;
        let mut rhs_index = result_not_first_or_last as Field * rhs_minimum_index;

        // if target_lt_smallest_entry, rhs_index = 0
        // if target_gt_largest_entry, lhs_index = TranscriptEntries - 1
        rhs_index = rhs_index * (1 - target_lt_smallest_entry as Field);

        // we rely here on the fact that target_gt_largest_entry and result_not_first_or_last are mutually exclusive
        lhs_index = lhs_index + target_gt_largest_entry as Field * (MaxNumValues as Field - 1);

        // If target is FOUND, we want the following:
        // keyhash[target_index] - 1 < hash < keyhash[target_index] + 1
        lhs_index = lhs_index + found as Field * found_index;
        rhs_index = rhs_index + found as Field * found_index;

        KeySearchResult {
            found,
            target_lt_smallest_entry,
            target_gt_largest_entry,
            lhs_index,
            rhs_index,
        }
    }

    /**
     * @brief returns a bool that describes whether a given key exists at the root of the JSON
     **/
    fn key_exists<let KeyBytes: u32>(self, key: BoundedVec<u8, KeyBytes>) -> bool {
        self.key_exists_impl_var(key).0
    }

    /**
     * @brief implementation of `key_exists`. returns both a boolean and also the position in `self.json_entries_packed` of the key
     * @description algorithm is O(1) because of the preprocessing we have done
     *              Method computes a key hash and checks whether key hash exists in the list of sorted preprocessed key hashes
     *              If it does *not* exist, we can find two adjacent entries in `key_hashes` where `key_hashes[i]` < target_key_hash < `key_hashes[i+1]`
     **/
    pub(crate) fn key_exists_impl<let KeyBytes: u32>(self, key: [u8; KeyBytes]) -> (bool, Field) {
        /*
            Option A: key exists
            Option B: key does NOT exist
        If key does NOT exist. 3 cases
            case 1: keyhash < first entry
            case 2: keyhash > last entry
            case 3: entry A > keyhash > entryB
        */
        let hasher: ByteHasher<MaxKeyFields> = ByteHasher {};
        let keyhash = hasher.get_keyhash_var(key, 0, KeyBytes);

        let HASH_MAXIMUM = 0x1000000000000000000000000000000000000000000000000000000000000 - 1;
        let two_pow_216 = 0x100000000000000000000000000000000000000000000000000000000;

        let keyhash = keyhash + self.root_id * two_pow_216;

        // Safety: The assertion below checks that the keyhash is stored in the the index returned by the unconstrained function
        let search_result = unsafe { self.search_for_key_in_map(keyhash) };
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

    /**
     * @brief implementation of `key_exists`. returns both a boolean and also the position in `self.json_entries_packed` of the key
     * @description algorithm is O(1) because of the preprocessing we have done
     *              Method computes a key hash and checks whether key hash exists in the list of sorted preprocessed key hashes
     *              If it does *not* exist, we can find two adjacent entries in `key_hashes` where `key_hashes[i]` < target_key_hash < `key_hashes[i+1]`
     **/
    pub(crate) fn key_exists_impl_var<let KeyBytes: u32>(
        self,
        key: BoundedVec<u8, KeyBytes>,
    ) -> (bool, Field) {
        /*
            Option A: key exists
            Option B: key does NOT exist
        If key does NOT exist. 3 cases
            case 1: keyhash < first entry
            case 2: keyhash > last entry
            case 3: entry A > keyhash > entryB
        */
        let hasher: ByteHasher<MaxKeyFields> = ByteHasher {};
        let keyhash = hasher.get_keyhash_var(key.storage(), 0, key.len() as u32);

        let HASH_MAXIMUM = 0x1000000000000000000000000000000000000000000000000000000000000 - 1;
        let two_pow_216 = 0x100000000000000000000000000000000000000000000000000000000;

        let keyhash = keyhash + self.root_id * two_pow_216;

        // Safety: the assertion (search_result.lhs_index - search_result.rhs_index) * found == 0 constraints this function
        let search_result = unsafe { self.search_for_key_in_map(keyhash) };
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

    pub(crate) unconstrained fn __get_keys_at_root<let MaxNumKeys: u32>(
        self,
    ) -> BoundedVec<Field, MaxNumKeys> {
        let root_object: JSONEntry =
            JSONEntry::from(self.json_entries_packed[self.root_index_in_transcript]);

        let mut result_ptr = 0;
        let mut result: [Field; MaxNumKeys] = [0; MaxNumKeys];
        for i in 0..MaxNumValues {
            let target_entry: JSONEntry = JSONEntry::from(self.unsorted_json_entries_packed[i]);
            if (target_entry.parent_index == self.root_id) {
                result[result_ptr] = i as Field;
                result_ptr += 1;
            }
        }
        assert_eq(result_ptr as Field, root_object.num_children);

        BoundedVec::from_parts_unchecked(result, result_ptr as u32)
    }

    pub(crate) fn get_keys_at_root<let MaxNumKeys: u32, let MaxKeyBytes: u32>(
        self,
    ) -> BoundedVec<BoundedVec<u8, MaxKeyBytes>, MaxNumKeys> {
        let root_object: JSONEntry =
            JSONEntry::from(self.json_entries_packed[self.root_index_in_transcript]);
        // Safety: the length of the index is constrained later.
        let key_indices: BoundedVec<Field, MaxNumKeys> = unsafe { self.__get_keys_at_root() };

        assert(key_indices.len() as Field == root_object.num_children);

        let mut result: [BoundedVec<u8, MaxKeyBytes>; MaxNumKeys] = [BoundedVec::new(); MaxNumKeys];
        for i in 0..MaxNumKeys {
            let key = KeyIndexData::from_field(self.key_data[key_indices.get_unchecked(i)]);
            // just a workaround to the interface for `extract_string_entry`
            let mut fake_entry = JSONEntry::new();
            fake_entry.json_pointer = key.json_index;
            fake_entry.json_length = key.json_length;
            result[i] = BoundedVec::from_parts_unchecked(
                self.extract_string_entry(fake_entry),
                key.json_length as u32,
            );
        }
        BoundedVec::from_parts_unchecked(result, key_indices.len())
    }
}

#[test]
fn test_get_keys_at_root() {
    let s = "{ \"A\": 1, \"foo\": false, \"bar\": { \"one\" : \"A\", \"two\" : \"B\"}, \"baz\": \"12345\"  }";

    let json: JSON<77, 6, 30, 30, 2> = JSON::parse_json_from_string(s);

    let keys: BoundedVec<BoundedVec<u8, 5>, 5> = json.get_keys_at_root();

    assert(keys.len() == 4);
    assert(keys.get_unchecked(0) == BoundedVec::from_array("A".as_bytes()));
    assert(keys.get_unchecked(1) == BoundedVec::from_array("foo".as_bytes()));
    assert(keys.get_unchecked(2) == BoundedVec::from_array("bar".as_bytes()));
    assert(keys.get_unchecked(3) == BoundedVec::from_array("baz".as_bytes()));
}
