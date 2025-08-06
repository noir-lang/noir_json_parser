use crate::_string_tools::slice_field::slice_200_bits_from_field;
use crate::_string_tools::slice_packed_field::slice_fields;
use crate::utils::cast_num_to_u32;

/**
 * @brief utility struct that computes a 200-bit Poseidon hash of some bytes,
 *        when the bytes are represented as packed 31 byte Field elements
 * @note we wrap `get_keyhash` in a struct so that the KeyFields parameter can be defined ahead of time
 **/
pub(crate) struct FieldHasher<let KeyFields: u32> {}

impl<let KeyFields: u32> FieldHasher<KeyFields> {

    pub(crate) fn get_keyhash<let NumPackedFields: u32>(
        _: Self,
        packed_fields: [Field; NumPackedFields],
        body_index: Field,
        key_length: Field,
    ) -> Field {
        let key_fields: [Field; KeyFields] = slice_fields(packed_fields, body_index, key_length);
        let hashed = poseidon::poseidon2::Poseidon2::hash(key_fields, KeyFields);
        slice_200_bits_from_field(hashed)
    }
}

/**
 * @brief utility struct that computes a 200-bit Poseidon hash of some bytes,
 *        when the bytes are represented as a substring in a byte array
 * @note we wrap `get_keyhash` in a struct so that the KeyFields parameter can be defined ahead of time
 * @note produces identical hash outputs when compared w. FieldHasher
 **/
pub(crate) struct ByteHasher<let KeyFields: u32> {}

impl<let KeyFields: u32> ByteHasher<KeyFields> {

    pub(crate) fn get_keyhash_var<let N: u32>(
        _: Self,
        body_text: [u8; N],
        body_index: u32,
        key_length: u32,
    ) -> Field {
        assert(key_length < KeyFields * 31, "key too large");

        let mut key_fields: [Field; KeyFields] = [0; KeyFields];

        let mut key_idx: u32 = 0;
        let mut limb = 0;

        for j in 0..KeyFields {
            limb = 0;

            for _ in 0..31 {
                let valid = (key_idx < key_length) as Field;
                limb *= 0x100;
                let byte_index = (body_index as Field + key_idx as Field) * valid;
                let byte = body_text[cast_num_to_u32(byte_index)];
                limb += byte as Field * valid;
                key_idx += 1;
            }
            key_fields[j] = limb;
        }

        let hashed_full = poseidon::poseidon2::Poseidon2::hash(key_fields, KeyFields);

        let mut r = slice_200_bits_from_field(hashed_full);
        r
    }
}
