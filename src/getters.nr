use crate::_comparison_tools::lt::{assert_gt_240_bit, assert_lt_240_bit, lt_field_16_bit};
use crate::_string_tools::string_chopper::slice_string;
use crate::enums::Layer::ARRAY_LAYER;
use crate::json::JSON;
use crate::json_entry::{JSONEntry, JSONEntryPacked};
use crate::keyhash::ByteHasher;
use crate::keymap::KeyIndexData;
use crate::utils::cast_num_to_u32;

/// records data used to reason about whether a key exists in a json blob
pub struct KeySearchResult {
    found: bool, // does the key exist?
    target_lt_smallest_entry: bool, // is the target keyhash smaller than the smallest keyhash in self.key_hashes?
    target_gt_largest_entry: bool, // is the target keyhash larger than the largest keyhash in self.key_hashes?
    lhs_index: u32, // either the index of the key being searched for, or the index of the keyhash in self.key_hashes that is closest to keyhash (hash > lhs_index_hash)
    rhs_index: u32, // either the index of the key being searched for, or the index of the keyhash in self.key_hashes that is closest to keyhash (hash < rhs_index_hash)
}

pub trait KeyHashable {
    fn get_keyhash<let MaxKeyFields: u32>(self) -> Field;
}

impl<let N: u32> KeyHashable for [u8; N] {

    fn get_keyhash<let MaxKeyFields: u32>(self) -> Field {
        let hasher: ByteHasher<MaxKeyFields> = ByteHasher {};
        hasher.get_keyhash_var(self, 0, N)
    }
}

impl<let N: u32> KeyHashable for BoundedVec<u8, N> {
    fn get_keyhash<let MaxKeyFields: u32>(self) -> Field {
        let hasher: ByteHasher<MaxKeyFields> = ByteHasher {};
        hasher.get_keyhash_var(self.storage(), 0, self.len())
    }
}

impl<let N: u32> KeyHashable for str<N> {
    fn get_keyhash<let MaxKeyFields: u32>(self) -> Field {
        let hasher: ByteHasher<MaxKeyFields> = ByteHasher {};
        hasher.get_keyhash_var(self.as_bytes(), 0, N)
    }
}

/// helper methods for extracting data out of a processed JSON object
impl<let NumBytes: u32, let NumPackedFields: u32, let MaxNumTokens: u32, let MaxNumValues: u32, let MaxKeyFields: u32> JSON<NumBytes, NumPackedFields, MaxNumTokens, MaxNumValues, MaxKeyFields> {

    /// same as `get_json_entry` but the key length may be less than KeyBytes
    pub(crate) fn get_json_entry_var<K>(self, key: K) -> (bool, JSONEntry, u32)
    where
        K: KeyHashable,
    {
        assert(self.layer_type_of_root != ARRAY_LAYER, "cannot extract array elements via a key");

        let (exists, key_index) = self.key_exists_impl(key);
        let entry: JSONEntry = self.json_entries_packed[key_index].into();
        (exists, entry, key_index)
    }

    /**
    *
     * @brief If the root JSON is an object, extract a JSONEntry that describes an array, object or value that maps to a given key
     * @note will revert if the key does not exist
     *
     * @brief same as `get_json_entry_unchecked` but the key length may be less than KeyBytes
     **/
    pub(crate) fn get_json_entry_unchecked<K>(self, key: K) -> JSONEntry
    where
        K: KeyHashable,
    {
        assert(self.layer_type_of_root != ARRAY_LAYER, "cannot extract array elements via a key");
        let keyhash = key.get_keyhash::<MaxKeyFields>();
        let two_pow_216 = 0x100000000000000000000000000000000000000000000000000000000;

        let keyhash = keyhash + self.root_id * two_pow_216;

        // Safety: The assertion below checks that the keyhash is stored in the the index returned by the unconstrained function
        let key_index = unsafe { find_key_in_map::<MaxNumValues>(self.key_hashes, keyhash) };

        assert_eq(self.key_hashes[key_index], keyhash, "get_json_entry_unchecked: key not found");
        let entry: JSONEntry = self.json_entries_packed[key_index].into();

        entry
    }

    /// same as `get_json_entry_unchecked_var` but also returns the position of the JSONEntry in `self.json_entries_packed`
    pub(crate) fn get_json_entry_unchecked_with_key_index<K>(self, key: K) -> (JSONEntry, u32)
    where
        K: KeyHashable,
    {
        assert(self.layer_type_of_root != ARRAY_LAYER, "cannot extract array elements via a key");
        let keyhash = key.get_keyhash::<MaxKeyFields>();
        let two_pow_216 = 0x100000000000000000000000000000000000000000000000000000000;

        let keyhash = keyhash + self.root_id * two_pow_216;

        // Safety: The assertion below checks that the keyhash is stored in the the index returned by the unconstrained function
        let key_index = unsafe { find_key_in_map::<MaxNumValues>(self.key_hashes, keyhash) };

        assert_eq(self.key_hashes[key_index], keyhash, "get_json_entry_unchecked: key not found");
        let entry: JSONEntry = self.json_entries_packed[key_index].into();

        (entry, key_index)
    }

    /// helper method that will extract an array of bytes that describes the value associated with a JSONEntry object
    ///
    /// e.g. if the JSONEntry describes "foo" : "bar" in the JSON, `extract_string_entry` will return "foo"
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

        let result: [u8; StringBytes] =
            slice_string(self.json_packed, entry.json_pointer, entry.json_length);

        result
    }

    /// returns a bool that describes whether a given key exists at the root of the JSON
    pub(crate) fn key_exists<K>(self, key: K) -> bool
    where
        K: KeyHashable,
    {
        self.key_exists_impl(key).0
    }

    /// implementation of `key_exists`. returns both a boolean and also the position in `self.json_entries_packed` of the key
    ///
    /// algorithm is O(1) because of the preprocessing we have done
    /// Method computes a key hash and checks whether key hash exists in the list of sorted preprocessed key hashes
    /// If it does *not* exist, we can find two adjacent entries in `key_hashes` where `key_hashes[i]` < target_key_hash < `key_hashes[i+1]`
    pub(crate) fn key_exists_impl<K>(self, key: K) -> (bool, u32)
    where
        K: KeyHashable,
    {
        /*
            Option A: key exists
            Option B: key does NOT exist
        If key does NOT exist. 3 cases
            case 1: keyhash < first entry
            case 2: keyhash > last entry
            case 3: entry A > keyhash > entryB
        */
        let keyhash = key.get_keyhash::<MaxKeyFields>();
        let HASH_MAXIMUM = 0x1000000000000000000000000000000000000000000000000000000000000 - 1;
        let two_pow_216 = 0x100000000000000000000000000000000000000000000000000000000;

        let keyhash = keyhash + self.root_id * two_pow_216;

        // Safety: the assertion (search_result.lhs_index - search_result.rhs_index) * found == 0 constraints this function
        let search_result =
            unsafe { search_for_key_in_map::<MaxNumValues>(self.key_hashes, keyhash) };
        if search_result.found {
            assert_eq(search_result.lhs_index, search_result.rhs_index);
        }

        let found = search_result.found as Field;
        let target_lt_smallest_entry = search_result.target_lt_smallest_entry;
        let target_gt_largest_entry = search_result.target_gt_largest_entry;

        // only one of "found", "target_lt_smallest_entry", "target_gt_largest_entry" can be true
        let exclusion_test =
            found + (target_gt_largest_entry as Field) + (target_lt_smallest_entry as Field);
        exclusion_test.assert_max_bit_size::<1>();

        // case where hash < self.key_hashes[0]
        // 0 < hash < hashes[0]
        let lhs = self.key_hashes[search_result.lhs_index];
        let mut lhs = if target_lt_smallest_entry { 0 } else { lhs };

        // case where hash > self.key_hashes[last]
        // largest < x < -1
        let rhs = self.key_hashes[search_result.rhs_index];
        let mut rhs = if target_gt_largest_entry {
            HASH_MAXIMUM
        } else {
            rhs
        };

        // case where hash == self.key_hashes[found_index]
        lhs -= found;
        rhs += found;

        assert_gt_240_bit(keyhash, lhs);
        assert_lt_240_bit(keyhash, rhs);

        (search_result.found, search_result.lhs_index)
    }

    pub(crate) fn get_keys_at_root<let MaxNumKeys: u32, let MaxKeyBytes: u32>(
        self,
    ) -> BoundedVec<BoundedVec<u8, MaxKeyBytes>, MaxNumKeys> {
        let root_object: JSONEntry =
            JSONEntry::from(self.json_entries_packed[self.root_index_in_transcript]);
        // Safety: the length of the index is constrained later.
        let key_indices: BoundedVec<Field, MaxNumKeys> = unsafe {
            __get_keys_at_root::<MaxNumKeys, MaxNumValues>(
                self.root_id,
                self.root_index_in_transcript,
                self.json_entries_packed,
                self.unsorted_json_entries_packed,
            )
        };

        assert(key_indices.len() as Field == root_object.num_children);

        let mut result: [BoundedVec<u8, MaxKeyBytes>; MaxNumKeys] = [BoundedVec::new(); MaxNumKeys];
        for i in 0..MaxNumKeys {
            let key = KeyIndexData::from_field(
                self.key_data[cast_num_to_u32(key_indices.get_unchecked(i))],
            );
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

    /// Helper function to get an entry from an array at a given index
    ///
    /// # Arguments
    ///
    /// * `array_index` - The index within the array
    ///
    /// # Returns
    ///
    /// (entry, valid, entry_index) where:
    ///   - entry: The JSONEntry at the given index
    ///   - valid: Indicates if the index is within bounds
    ///   - entry_index: The actual index in json_entries_packed where the entry is stored
    pub(crate) fn get_entry_from_array(self, array_index: Field) -> (JSONEntry, bool, u32) {
        assert_eq(
            self.layer_type_of_root,
            ARRAY_LAYER,
            "can only access array elements from array",
        );

        let parent_entry: JSONEntry =
            self.json_entries_packed[self.root_index_in_transcript].into();

        let valid = lt_field_16_bit(array_index, parent_entry.num_children);
        let entry_index = (parent_entry.child_pointer + array_index) * valid as Field;

        let entry: JSONEntry = self.json_entries_packed[cast_num_to_u32(entry_index)].into();

        (entry, valid, cast_num_to_u32(entry_index))
    }
}

unconstrained fn find_key_in_map<let MaxNumValues: u32>(
    key_hashes: [Field; MaxNumValues],
    target: Field,
) -> u32 {
    let mut found_index: u32 = 0;
    let mut found: bool = false;
    for i in 0..MaxNumValues {
        let key_hash = key_hashes[i];
        if (key_hash == target) {
            found_index = i;
            found = true;
            break;
        }
    }
    assert(found, "find_key_in_map, key not found");
    found_index
}

/// figures out if `target` exists as a key in `self.key_hashes`
///
/// if `target` does not exist, we return the two indicies of adjacent
/// entries in `self.key_hashes`, lhs_index, rhs_index, where
/// lhs_index < key_hash < rhs_index
unconstrained fn search_for_key_in_map<let MaxNumValues: u32>(
    key_hashes: [Field; MaxNumValues],
    target: Field,
) -> KeySearchResult {
    let mut found_index: Field = 0;
    let mut found: bool = false;

    let mut lhs_maximum: Field = 0;
    let mut rhs_minimum: Field = -1;
    let mut lhs_maximum_index: Field = 0;
    let mut rhs_minimum_index: Field = 0;
    for i in 0..MaxNumValues {
        let key_hash = key_hashes[i];
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
    let target_lt_smallest_entry = target.lt(key_hashes[0]);
    let target_gt_largest_entry = key_hashes[MaxNumValues - 1].lt(target);

    let result_not_first_or_last = !target_lt_smallest_entry & !target_gt_largest_entry & !found;

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
        lhs_index: lhs_index as u32,
        rhs_index: rhs_index as u32,
    }
}

unconstrained fn __get_keys_at_root<let MaxNumKeys: u32, let MaxNumValues: u32>(
    root_id: Field,
    root_index_in_transcript: u32,
    json_entries_packed: [JSONEntryPacked; MaxNumValues],
    unsorted_json_entries_packed: [JSONEntryPacked; MaxNumValues],
) -> BoundedVec<Field, MaxNumKeys> {
    let root_object: JSONEntry = JSONEntry::from(json_entries_packed[root_index_in_transcript]);

    let mut result_ptr = 0;
    let mut result: [Field; MaxNumKeys] = [0; MaxNumKeys];
    for i in 0..MaxNumValues {
        let target_entry: JSONEntry = JSONEntry::from(unsorted_json_entries_packed[i]);
        if (target_entry.parent_index == root_id) {
            result[result_ptr] = i as Field;
            result_ptr += 1;
        }
    }
    assert_eq(result_ptr as Field, root_object.num_children);

    BoundedVec::from_parts_unchecked(result, result_ptr as u32)
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
