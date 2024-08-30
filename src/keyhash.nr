use crate::slice_field::slice_fields;

global MaxKeyBytes: u16 = 32; // todo make parameter

global PLO: Field = 0x2833E84879B9709143E1F593F0000001;
global PHI: Field = 0x30644E72E131A029B85045B68181585D;

global PLO_200_felt: Field = 0x29B85045B68181585D2833E84879B9709143E1F593F0000001;
global PHI_54_felt: Field = 0x30644E72E131A0;
global TWO_POW_200 = 0x100000000000000000000000000000000000000000000000000;
struct Slice200 {
    hihi: u64, // 7 bytes
    hilo: u64, // 7 bytes
    lohi: u64, // 7 bytes
    lolo: u32 // 4 bytes 
}

// todo try to remove this bit
global BYTE_SHIFT: [Field; 32] = [
        0x100000000000000000000000000000000000000000000000000000000000000,
        0x1000000000000000000000000000000000000000000000000000000000000,
        0x10000000000000000000000000000000000000000000000000000000000,
        0x100000000000000000000000000000000000000000000000000000000,
        0x1000000000000000000000000000000000000000000000000000000,
        0x10000000000000000000000000000000000000000000000000000,
        0x100000000000000000000000000000000000000000000000000,
        0x1000000000000000000000000000000000000000000000000,
        0x10000000000000000000000000000000000000000000000,
        0x100000000000000000000000000000000000000000000,
        0x1000000000000000000000000000000000000000000,
        0x10000000000000000000000000000000000000000,
        0x100000000000000000000000000000000000000,
        0x1000000000000000000000000000000000000,
        0x10000000000000000000000000000000000,
        0x100000000000000000000000000000000,
        0x1000000000000000000000000000000,
        0x10000000000000000000000000000,
        0x100000000000000000000000000,
        0x1000000000000000000000000,
        0x10000000000000000000000,
        0x100000000000000000000,
        0x1000000000000000000,
        0x10000000000000000,
        0x100000000000000,
        0x1000000000000,
        0x10000000000,
        0x100000000,
        0x1000000,
        0x10000,
        0x100,
        1
    ];

global PATH_LOOKUP: [[bool; 5]; 32] = [
        [false, false, false, false, false],
        [true, false, false, false, false],
        [false, true, false, false, false],
        [true, true, false, false, false],
        [false, false, true, false, false],
        [true, false, true, false, false],
        [false, true, true, false, false],
        [true, true, true, false, false],
        [false, false, false, true, false],
        [true, false, false, true, false],
        [false, true, false, true, false],
        [true, true, false, true, false],
        [false, false, true, true, false],
        [true, false, true, true, false],
        [false, true, true, true, false],
        [true, true, true, true, false],
        [false, false, false, false, true],
        [true, false, false, false, true],
        [false, true, false, false, true],
        [true, true, false, false, true],
        [false, false, true, false, true],
        [true, false, true, false, true],
        [false, true, true, false, true],
        [true, true, true, false, true],
        [false, false, false, true, true],
        [true, false, false, true, true],
        [false, true, false, true, true],
        [true, true, false, true, true],
        [false, false, true, true, true],
        [true, false, true, true, true],
        [false, true, true, true, true],
        [true, true, true, true, true]
    ];

unconstrained fn get_path(idx: Field) -> [bool; 5] {
    PATH_LOOKUP[idx]
}

global PHI_54: u64 = 0x30644E72E131A0;
global PLO_200: Slice200 = Slice200 {
    hihi: 0x29B85045B68181,
    hilo: 0x585D2833E84879,
    lohi: 0xB9709143E1F593,
    lolo: 0xF0000001,
};

unconstrained fn __slice_200_bits_from_field(f: Field) -> (Field, Field, bool) {
    let b = f.to_be_bytes(32);

    let mut res200: Slice200 = Slice200 { hihi: 0, hilo: 0, lohi: 0, lolo: 0 };
    let mut res54: u64 = 0;
    for i in 0..7 {
        res200.hihi <<= 8;
        res200.hilo <<= 8;
        res200.lohi <<= 8;
        res200.hihi += b[i + 7] as u64;
        res200.hilo += b[i + 14] as u64;
        res200.lohi += b[i + 21] as u64;
    }
    for i in 0..4 {
        res200.lolo <<= 8;
        res200.lolo += b[28 + i] as u32;
    }
    for i in 0..7 {
        res54 <<= 8;
        res54 += b[i] as u64;
    }

    let mut lo: Field = res200.hihi as Field; // 56 bits
    lo *= 0x100000000000000; // 56 + 56 bits
    lo += res200.hilo as Field; // 56 + 56 bits
    lo *= 0x100000000000000; // 56 + 56 + 56 bits
    lo += res200.lohi as Field; // 56 + 56 + 56 bits = 168 bits
    lo *= 0x100000000; // 56 + 56 + 56 + 32 bits = 200 bits?
    lo += res200.lolo as Field;

    // lolo
    // lohi * 4
    // hilo * 4 + 7
    let mut hi = res54 as Field;

    let mut PLO = PLO_200;
    let mut borrow: bool = false;
    // p - x
    borrow = PLO.lolo < res200.lolo;
    PLO.lohi -= borrow as u64;
    borrow = PLO.lohi < res200.lohi;
    PLO.hilo -= borrow as u64;
    borrow = PLO.hilo < res200.hilo;
    PLO.hihi -= borrow as u64;
    borrow = PLO.hihi < res200.hihi;
    let mut PHI = PHI_54 - borrow as u64;
    assert(PHI > res54, "slice failed? this shouldn't happen!");
    (lo, hi, borrow)
}

fn slice_200_bits_from_field(f: Field) -> Field {
    let (lo, hi, borrow) = __slice_200_bits_from_field(f);
    assert(hi * TWO_POW_200 + lo == f);
    lo.assert_max_bit_size(200);
    hi.assert_max_bit_size(56);
    let lo_diff = PLO_200_felt - lo + (borrow as Field * TWO_POW_200);
    let hi_diff = PHI_54_felt - hi - borrow as Field;
    lo_diff.assert_max_bit_size(200);
    hi_diff.assert_max_bit_size(56);
    lo
}

global tail_path_multipliers_chunk3: [Field; 32] = [0x0100000000000000000000000000000000, 0x0100000000000000000000000000000000, 0x0100000000000000000000000000000000, 0x0100000000000000000000000000000000, 0x0100000000000000000000000000000000, 0x0100000000000000000000000000000000, 0x0100000000000000000000000000000000, 0x0100000000000000000000000000000000, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00];
global tail_path_multipliers_chunk2: [Field; 32] = [0x01000000000000000000000000000000000000000000000000, 0x01000000000000000000000000000000000000000000000000, 0x01000000000000000000000000000000000000000000000000, 0x01000000000000000000000000000000000000000000000000, 0x00, 0x00, 0x00, 0x00, 0x0100000000000000000000000000000000, 0x0100000000000000000000000000000000, 0x0100000000000000000000000000000000, 0x0100000000000000000000000000000000, 0x00, 0x00, 0x00, 0x00, 0x010000000000000000, 0x010000000000000000, 0x010000000000000000, 0x010000000000000000, 0x00, 0x00, 0x00, 0x00, 0x01, 0x01, 0x01, 0x01, 0x00, 0x00, 0x00, 0x00];
global tail_path_multipliers_chunk1: [Field; 32] = [0x0100000000000000000000000000000000000000000000000000000000, 0x0100000000000000000000000000000000000000000000000000000000, 0x00, 0x00, 0x01000000000000000000000000000000000000000000000000, 0x01000000000000000000000000000000000000000000000000, 0x00, 0x00, 0x010000000000000000000000000000000000000000, 0x010000000000000000000000000000000000000000, 0x00, 0x00, 0x0100000000000000000000000000000000, 0x0100000000000000000000000000000000, 0x00, 0x00, 0x01000000000000000000000000, 0x01000000000000000000000000, 0x00, 0x00, 0x010000000000000000, 0x010000000000000000, 0x00, 0x00, 0x0100000000, 0x0100000000, 0x00, 0x00, 0x01, 0x01, 0x00, 0x00];
global tail_path_multipliers_chunk0: [Field; 32] = [0x01000000000000000000000000000000000000000000000000000000000000, 0x00, 0x0100000000000000000000000000000000000000000000000000000000, 0x00, 0x010000000000000000000000000000000000000000000000000000, 0x00, 0x01000000000000000000000000000000000000000000000000, 0x00, 0x0100000000000000000000000000000000000000000000, 0x00, 0x010000000000000000000000000000000000000000, 0x00, 0x01000000000000000000000000000000000000, 0x00, 0x0100000000000000000000000000000000, 0x00, 0x010000000000000000000000000000, 0x00, 0x01000000000000000000000000, 0x00, 0x0100000000000000000000, 0x00, 0x010000000000000000, 0x00, 0x01000000000000, 0x00, 0x0100000000, 0x00, 0x010000, 0x00, 0x01, 0x00];

fn sum_var_bytes_into_field<let N: u32>(body_text: [u8; N], body_index: Field, num_bytes: Field) -> Field {
    let path = get_path(num_bytes); // 5 gates
    let path_f: [Field; 5] = [path[0] as Field, path[1] as Field, path[2] as Field, path[3] as Field, path[4] as Field];

    assert(path_f[0] + path_f[1] * 2 + path_f[2] * 4 + path_f[3] * 8 + path_f[4] * 16 == num_bytes as Field);

    let mut idx: Field = body_index as Field;

    let mut chunks: [Field; 5] = [0; 5];

    chunks[0] = body_text[idx] as Field;
    idx += path_f[0];

    chunks[1] = body_text[idx] as Field * 0x100 + body_text[idx + 1] as Field;
    idx += path_f[1] * 2;

    chunks[2] = body_text[idx] as Field * 0x1000000 + body_text[idx + 1] as Field * 0x10000
    + body_text[idx + 2] as Field * 0x100 + body_text[idx + 3] as Field;
    idx += path_f[2] * 4;

    chunks[3] = body_text[idx] as Field * 0x100000000000000 + body_text[idx + 1] as Field * 0x1000000000000
    + body_text[idx + 2] as Field       * 0x10000000000 + body_text[idx + 3] as Field     * 0x100000000
    + body_text[idx + 4] as Field       * 0x1000000 + body_text[idx + 5] as Field         * 0x10000
    + body_text[idx + 6] as Field       * 0x100 + body_text[idx + 7] as Field;
    idx += path_f[3] * 8;

    chunks[4] = body_text[idx] as Field * 0x1000000000000000000000000000000 + body_text[idx + 1] as Field * 0x1000000000000000000000000000
    + body_text[idx + 2] as Field * 0x100000000000000000000000000 + body_text[idx + 3] as Field * 0x1000000000000000000000000 
    + body_text[idx + 4] as Field * 0x10000000000000000000000 + body_text[idx + 5] as Field * 0x100000000000000000000
    + body_text[idx + 6] as Field * 0x1000000000000000000 + body_text[idx + 7] as Field * 0000000000000000
    + body_text[idx + 8] as Field * 0x100000000000000 + body_text[idx + 9] as Field * 0x100000000000
    + body_text[idx + 10] as Field * 0x10000000000 + body_text[idx + 11] as Field * 0x100000000
    + body_text[idx + 12] as Field * 0x1000000 + body_text[idx + 13] as Field * 0x10000
    + body_text[idx + 14] as Field * 0x100 + body_text[idx + 15] as Field;

    chunks[0] *= path_f[0];
    chunks[1] *= path_f[1];
    chunks[2] *= path_f[2];
    chunks[3] *= path_f[3];
    chunks[4] *= path_f[4];

    let mut sum: Field = 0;

    let mut multiplicand: Field = 1;
    sum += chunks[4];
    multiplicand *= (0x100000000000000000000000000000000 * path_f[4]) + (1 - path_f[4]);
    sum += chunks[3] * multiplicand;
    multiplicand *= (0x10000000000000000 * path_f[3]) + (1 - path_f[3]);
    sum += chunks[2] * multiplicand;
    multiplicand *= (0x100000000 * path_f[2]) + (1 - path_f[2]);
    sum += chunks[1] * multiplicand;
    multiplicand *= (0x10000 * path_f[1]) + (1 - path_f[1]);
    sum += chunks[0] * multiplicand;
    sum
}

fn get_keyhash_chunky<let N: u32>(body_text: [u8; N], body_index: u16, key_length: u16) -> Field {
    assert(key_length < MaxKeyBytes, "key too large");
    let mut key_fields: [Field; 10] = [0; 10];

    let mut key_idx: u16 = 0;
    let num_limbs = (MaxKeyBytes / 31) + 1; // N.B. will be funky if MaxKeyBytes is multiple of 31

    for j in 0..num_limbs {
        let full_limb = (key_idx + j * num_limbs) + 31 <= key_length;
        let diff = key_length as Field - (key_idx as Field + j as Field * num_limbs as Field);
        let no_bytes = (key_idx + j * num_limbs) >= key_length;
        let mut limb_length = full_limb as Field * 31 + (1 - full_limb as Field) * (diff as Field);
        limb_length = limb_length * (1 - no_bytes as Field);
        key_fields[j] = sum_var_bytes_into_field(
            body_text,
            body_index as Field + (j as Field * 31),
            limb_length
        );
        key_idx += 31;
    }
    // let hashed_full = dep::std::hash::poseidon2::Poseidon2::hash(key_fields, num_limbs as u32);
    let hashed_full: Field = key_fields[0] + key_fields[1] + key_fields[2];
    let r: Field = slice_200_bits_from_field(hashed_full);
    std::as_witness(r);
    // println(f"chunky result {r}");
    r
}

struct Hasher<let KeyFields: u16>
{}

impl<let KeyFields: u16> Hasher<KeyFields> {

    fn get_keyhash<let NumPackedFields: u16>(_: Self, packed_fields: [Field; NumPackedFields], body_index: Field, key_length: Field) -> Field {
        let key_fields: [Field; KeyFields] = slice_fields(packed_fields, body_index, key_length);
        let hashed = dep::std::hash::poseidon2::Poseidon2::hash(key_fields, KeyFields as u32);
        slice_200_bits_from_field(hashed)
    }
}

global KeyFieldsTemp = 2; // TODO replace
fn get_keyhash<let N: u32>(body_text: [u8; N], body_index: u16, key_length: u16) -> Field {
    assert(key_length < MaxKeyBytes, "key too large"); // todo fix cast
    //  assert(lt_field_16_bit(key_length, 32), "key too large");
    let mut key_fields: [Field; KeyFieldsTemp] = [0; KeyFieldsTemp];

    let mut key_idx: u16 = 0;
    let num_limbs = (MaxKeyBytes / 31) + 1; // N.B. will be funky if MaxKeyBytes is multiple of 31
    let mut limb = 0;

    for j in 0..num_limbs {
        limb = 0;

        for _ in 0..31 {
            let valid = (key_idx < key_length) as Field;
            limb *= 0x100;
            let byte_index = (body_index as Field + key_idx as Field) * valid;
            let byte = body_text[byte_index] as Field;
            limb += byte * valid;
            key_idx += 1;
        }
        key_fields[j] = limb;
    }

    let hashed_full = dep::std::hash::poseidon2::Poseidon2::hash(key_fields, KeyFieldsTemp as u32);

    let mut r = slice_200_bits_from_field(hashed_full);
    // println(f"old result {r}");
    r
}
