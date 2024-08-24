global MaxKeyBytes: u16 = 32; // todo make parameter

global PLO: Field = 0x2833E84879B9709143E1F593F0000001;
global PHI: Field = 0x30644E72E131A029B85045B68181585D;
// 29B85045B68181585D

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
/*


0x29B85045B6818158
0x5D2833E84879B970
0x9143E1F593F00000
0x01
*/
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
    let u = PLO.hihi as Field;
    let v = res200.hihi as Field;
    println(f"ptop vs rtop = {u} : {v}");
    // 0x29b85045b6818158
    // 0xc7411d9450cce4
    let k = PLO_200_felt;
    println(f"lo vs p = {lo} : {k}");
    let mut PHI = PHI_54 - borrow as u64;
    assert(PHI > res54, "slice failed? this shouldn't happen!");
    // 0xc7411d9450cce4f0881a2ac0a346f02e1aa1d499535e33336c
    // 0x29b85045b68181585d2833e84879b9709143e1f593f0000001
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
// TESTS PASS WITH THIS ONE, NEED TO CHANGE TEST EXPECTS TO MATCH NEW REORDERING
fn get_keyhash_old<let N: u32>(body_text: [u8; N], body_index: u16, key_length: u16) -> Field {
    assert(key_length < MaxKeyBytes, "key too large"); // todo fix cast
    //  assert(lt_field_16_bit(key_length, 32), "key too large");
    let mut key_fields: [Field; 10] = [0; 10];
    let mut result: [u8; MaxKeyBytes] = [0; MaxKeyBytes];

    let mut key_idx: u16 = 0;
    let num_limbs = (MaxKeyBytes / 31) + 1; // N.B. will be funky if MaxKeyBytes is multiple of 31

    for j in 0..num_limbs {
        let mut limb = 0;
        for i in 0..31 {
            limb *= 0x100;

            let valid = (key_idx < key_length) as Field;
            let byte_index = (body_index as Field + key_idx as Field) * valid;
            let byte = body_text[byte_index] as Field;
            limb += byte * valid;
            if (key_idx < key_length) { // TODO fix cast
                //  if lt_field_16_bit(i as Field, key_length) {
                let byte = body_text[body_index as Field + key_idx as Field];
                result[key_idx] = byte;
            }
            key_idx += 1;
        }
        key_fields[j] = limb;
    }

    // 101355
    // 116413
    // ok. 243 gates per hash really sucks
    // 99,548 if hash size is 1
    // 116,413 if hash size is 2
    // 121,483 if hash size is 3
    // 121,483 if hash size is 4
    // what the fuck?
    // poseidon2 has t=4. 1 permutation should cover 3 fields
    // TGODO replace with cheaper hash!
    // let hashed_full = dep::std::hash::poseidon2::Poseidon2::hash(key_fields, 3);
    let hashed_bytes= dep::std::hash::blake2s(result);
    //    let hashed = fakehash(result); // dep::std::hash::blake2s(result);

    // let hashed_bytes = hashed_full.to_be_bytes(32);
    let mut result: Field = 0;
    // 200 bits
    for i in 0..25 {
        result *= 0x100;
        result += hashed_bytes[7 + i] as Field;
    }
    println(f"old result {result}");
    // let key_len = entry.
    result
}

unconstrained fn reverse(x: [Field; 32]) -> [Field; 32] {
    let mut r: [Field; 32] = [0; 32];

    for i in 0..32 {
        r[i] = x[31 - i];
    }

    println(f"{r}");
    r
}
// this represents an 8 byte chunk. what do we multiply by?

global tail_path_multipliers_chunk3: [Field; 32] = [0x0100000000000000000000000000000000, 0x0100000000000000000000000000000000, 0x0100000000000000000000000000000000, 0x0100000000000000000000000000000000, 0x0100000000000000000000000000000000, 0x0100000000000000000000000000000000, 0x0100000000000000000000000000000000, 0x0100000000000000000000000000000000, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00];
global tail_path_multipliers_chunk2: [Field; 32] = [0x01000000000000000000000000000000000000000000000000, 0x01000000000000000000000000000000000000000000000000, 0x01000000000000000000000000000000000000000000000000, 0x01000000000000000000000000000000000000000000000000, 0x00, 0x00, 0x00, 0x00, 0x0100000000000000000000000000000000, 0x0100000000000000000000000000000000, 0x0100000000000000000000000000000000, 0x0100000000000000000000000000000000, 0x00, 0x00, 0x00, 0x00, 0x010000000000000000, 0x010000000000000000, 0x010000000000000000, 0x010000000000000000, 0x00, 0x00, 0x00, 0x00, 0x01, 0x01, 0x01, 0x01, 0x00, 0x00, 0x00, 0x00];
global tail_path_multipliers_chunk1: [Field; 32] = [0x0100000000000000000000000000000000000000000000000000000000, 0x0100000000000000000000000000000000000000000000000000000000, 0x00, 0x00, 0x01000000000000000000000000000000000000000000000000, 0x01000000000000000000000000000000000000000000000000, 0x00, 0x00, 0x010000000000000000000000000000000000000000, 0x010000000000000000000000000000000000000000, 0x00, 0x00, 0x0100000000000000000000000000000000, 0x0100000000000000000000000000000000, 0x00, 0x00, 0x01000000000000000000000000, 0x01000000000000000000000000, 0x00, 0x00, 0x010000000000000000, 0x010000000000000000, 0x00, 0x00, 0x0100000000, 0x0100000000, 0x00, 0x00, 0x01, 0x01, 0x00, 0x00];
global tail_path_multipliers_chunk0: [Field; 32] = [0x01000000000000000000000000000000000000000000000000000000000000, 0x00, 0x0100000000000000000000000000000000000000000000000000000000, 0x00, 0x010000000000000000000000000000000000000000000000000000, 0x00, 0x01000000000000000000000000000000000000000000000000, 0x00, 0x0100000000000000000000000000000000000000000000, 0x00, 0x010000000000000000000000000000000000000000, 0x00, 0x01000000000000000000000000000000000000, 0x00, 0x0100000000000000000000000000000000, 0x00, 0x010000000000000000000000000000, 0x00, 0x01000000000000000000000000, 0x00, 0x0100000000000000000000, 0x00, 0x010000000000000000, 0x00, 0x01000000000000, 0x00, 0x0100000000, 0x00, 0x010000, 0x00, 0x01, 0x00];
// // what do we multiply 4 byte chunk by
// global tail_path_multipliers_chunk2: [Field; 32] = [
//     /* 0  (00000) */ 0,
//     /* 1  (00001) */ 0,
//     /* 2  (00010) */ 0,
//     /* 3  (00011) */ 0,
//     /* 4  (00100) */ 1,
//     /* 5  (00101) */ 1,
//     /* 6  (00110) */ 1,
//     /* 7  (00111) */ 1,
//     /* 8  (01000) */ 0,
//     /* 9  (01001) */ 0,
//     /* 10 (01010) */ 0,
//     /* 11 (01011) */ 0,
//     /* 12 (01100) */ two_pow_64,
//     /* 13 (01101) */ two_pow_64,
//     /* 14 (01110) */ two_pow_64,
//     /* 15 (01111) */ two_pow_64,
//     /* 16 (10000) */ 0,
//     /* 17 (10001) */ 0,
//     /* 18 (10010) */ 0,
//     /* 19 (10011) */ 0,
//     /* 20 (10100) */ two_pow_128,
//     /* 21 (10101) */ two_pow_128,
//     /* 22 (10110) */ two_pow_128,
//     /* 23 (10111) */ two_pow_128,
//     /* 24 (11000) */ 0,
//     /* 25 (11001) */ 0,
//     /* 26 (11010) */ 0,
//     /* 27 (11011) */ 0,
//     /* 28 (11100) */ two_pow_128 * two_pow_64,
//     /* 29 (11101) */ two_pow_128 * two_pow_64,
//     /* 30 (11110) */ two_pow_128 * two_pow_64,
//     /* 31 (11111) */ two_pow_128 * two_pow_64
// ];

// // what do we multiply 2 byte chunk by
// global tail_path_multipliers_chunk1: [Field; 32] = [
//     /* 0  (00000) */ 0,
//     /* 1  (00001) */ 0,
//     /* 2  (00010) */ 1,
//     /* 3  (00011) */ 1,
//     /* 4  (00100) */ 0,
//     /* 5  (00101) */ 0,
//     /* 6  (00110) */ two_pow_32,
//     /* 7  (00111) */ two_pow_32,
//     /* 8  (01000) */ 0,
//     /* 9  (01001) */ 0,
//     /* 10 (01010) */ two_pow_64,
//     /* 11 (01011) */ two_pow_64,
//     /* 12 (01100) */ 0,
//     /* 13 (01101) */ 0,
//     /* 14 (01110) */ two_pow_64 * two_pow_32,
//     /* 15 (01111) */ two_pow_64 * two_pow_32,
//     /* 16 (10000) */ 0,
//     /* 17 (10001) */ 0,
//     /* 18 (10010) */ two_pow_128,
//     /* 19 (10011) */ two_pow_128,
//     /* 20 (10100) */ 0,
//     /* 21 (10101) */ 0,
//     /* 22 (10110) */ two_pow_128 * two_pow_32,
//     /* 23 (10111) */ two_pow_128 * two_pow_32,
//     /* 24 (11000) */ 0,
//     /* 25 (11001) */ 0,
//     /* 26 (11010) */ two_pow_128 * two_pow_64,
//     /* 27 (11011) */ two_pow_128 * two_pow_64,
//     /* 28 (11100) */ 0,
//     /* 29 (11101) */ 0,
//     /* 30 (11110) */ two_pow_128 * two_pow_64 * two_pow_32,
//     /* 31 (11111) */ two_pow_128 * two_pow_64 * two_pow_32
// ];

// // what do we multiply 1 byte chunk by
// global tail_path_multipliers_chunk0: [Field; 32] = [
//     /* 0  (00000) */ 0,
//     /* 1  (00001) */ 1,
//     /* 2  (00010) */ 0,
//     /* 3  (00011) */ two_pow_16,
//     /* 4  (00100) */ 0,
//     /* 5  (00101) */ two_pow_32,
//     /* 6  (00110) */ 0,
//     /* 7  (00111) */ two_pow_16 * two_pow_32,
//     /* 8  (01000) */ 0,
//     /* 9  (01001) */ two_pow_64,
//     /* 10 (01010) */ 0,
//     /* 11 (01011) */ two_pow_64 * two_pow_16,
//     /* 12 (01100) */ 0,
//     /* 13 (01101) */ two_pow_64 * two_pow_32,
//     /* 14 (01110) */ 0,
//     /* 15 (01111) */ two_pow_64 * two_pow_32 * two_pow_16,
//     /* 16 (10000) */ 0,
//     /* 17 (10001) */ two_pow_128,
//     /* 18 (10010) */ 0,
//     /* 19 (10011) */ two_pow_128 * two_pow_16,
//     /* 20 (10100) */ 0,
//     /* 21 (10101) */ two_pow_128 * two_pow_32,
//     /* 22 (10110) */ 0,
//     /* 23 (10111) */ two_pow_128 * two_pow_32 * two_pow_16,
//     /* 24 (11000) */ 0,
//     /* 25 (11001) */ two_pow_128 * two_pow_64,
//     /* 26 (11010) */ 0,
//     /* 27 (11011) */ two_pow_128 * two_pow_64 * two_pow_16,
//     /* 28 (11100) */ 0,
//     /* 29 (11101) */ two_pow_128 * two_pow_64 * two_pow_32,
//     /* 30 (11110) */ 0,
//     /* 31 (11111) */ two_pow_128 * two_pow_64 * two_pow_32 * two_pow_16
// ];

fn sum_var_bytes_into_field<let N: u32>(
    body_text: [u8; N],
    body_index: Field,
    num_bytes: Field
) -> Field {
    let path = get_path(num_bytes); // 5 gates
    let path_f: [Field; 5] = [path[0] as Field, path[1] as Field, path[2] as Field, path[3] as Field, path[4] as Field];

    //   println(f"path = {path}");
    // 3 gates (2 if we improve copy constraints in noir)
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

    chunks[3] = body_text[idx] as Field * 0x100000000000000 + body_text[idx + 1] as Field * 0x100000000000
    + body_text[idx + 2] as Field * 0x10000000000 + body_text[idx + 3] as Field * 0x100000000
    + body_text[idx + 4] as Field * 0x1000000 + body_text[idx + 5] as Field * 0x10000
    + body_text[idx + 6] as Field * 0x100 + body_text[idx + 7] as Field;
    idx += path_f[3] * 8;

    chunks[4] = body_text[idx] as Field * 0x1000000000000000000000000000000 + body_text[idx + 1] as Field * 0x1000000000000000000000000000
    + body_text[idx + 2] as Field * 0x100000000000000000000000000 + body_text[idx + 3] as Field * 0x1000000000000000000000000 
    + body_text[idx + 4] as Field * 0x10000000000000000000000 + body_text[idx + 5] as Field * 0x100000000000000000000
    + body_text[idx + 6] as Field * 0x1000000000000000000 + body_text[idx + 7] as Field * 0000000000000000
    + body_text[idx + 8] as Field * 0x100000000000000 + body_text[idx + 9] as Field * 0x100000000000
    + body_text[idx + 10] as Field * 0x10000000000 + body_text[idx + 11] as Field * 0x100000000
    + body_text[idx + 12] as Field * 0x1000000 + body_text[idx + 13] as Field * 0x10000
    + body_text[idx + 14] as Field * 0x100 + body_text[idx + 15] as Field;

    //chunks[4] = chunks[3] * chunks[3];
    chunks[0] *= path_f[0];
    chunks[1] *= path_f[1];
    chunks[2] *= path_f[2];
    chunks[3] *= path_f[3];
    chunks[4] *= path_f[4];

    let mut sum: Field = 0;

    // if 0 0 1 1

    // if 0 1 0 1 (little endian)
    // we have chunk[1] and chunk[3]
    // therefore we need chunk[1] * 8^16
    // if 0 1 1 1 (little endian)
    // we need chunk[2] * 8^16, chunk[3] * 8^24
    let mut multiplicand: Field = 1;
    // println(f"chunks = {chunks}");
    sum += chunks[4];
    multiplicand *= (0x100000000000000000000000000000000 * path_f[4]) + (1 - path_f[4]);
    sum += chunks[3] * multiplicand;
    multiplicand *= (0x10000000000000000 * path_f[3]) + (1 - path_f[3]);
    sum += chunks[2] * multiplicand;
    multiplicand *= (0x100000000 * path_f[2]) + (1 - path_f[2]);
    sum += chunks[1] * multiplicand;
    multiplicand *= (0x10000 * path_f[1]) + (1 - path_f[1]);
    sum += chunks[0] * multiplicand;

    //  sum *= BYTE_SHIFT[num_bytes];
    // 0x74657374410000000000000000000000000000000000000000000000000000
    // 0x74657374410000000000000000000000000000000000000000000000000000
    // length = l, byte_shift = (31 - l)
    sum
}
// 0x74657374410000000000000000000000000000000000000000000000000000
// 0x7465737441
fn get_keyhash_chunky<let N: u32>(body_text: [u8; N], body_index: u16, key_length: u16) -> Field {
    assert(key_length < MaxKeyBytes, "key too large"); // todo fix cast
    //  assert(lt_field_16_bit(key_length, 32), "key too large");
    let mut key_fields: [Field; 10] = [0; 10];

    let mut key_idx: u16 = 0;
    let num_limbs = (MaxKeyBytes / 31) + 1; // N.B. will be funky if MaxKeyBytes is multiple of 31

    for j in 0..num_limbs {
        //  let diff = key_length - (key_idx + j * num_limbs);
        let full_limb = (key_idx + j * num_limbs) + 31 <= key_length;
        let diff = key_length as Field - (key_idx as Field + j as Field * num_limbs as Field);
        let no_bytes = (key_idx + j * num_limbs) >= key_length;
        let mut limb_length = full_limb as Field * 31 + (1 - full_limb as Field) * (diff as Field);
        limb_length = limb_length * (1 - no_bytes as Field);
        // println(
        //     f"j {j} no bytes = {no_bytes} full_limb  {full_limb}, diff {diff}, limb_length {limb_length}"
        // );
        key_fields[j] = sum_var_bytes_into_field(
            body_text,
            body_index as Field + (j as Field * 31),
            limb_length
        );
        let k = key_fields[j];
        println(f"key_fields[{j}] = {k}");
        key_idx += 31;
    }
    // for j in 0..num_limbs {
    //     limb = 0;

    //     for i in 0..31 {
    //         limb *= 0x100;

    //         let valid = (key_idx < key_length) as Field;
    //         let byte_index = (body_index as Field + key_idx as Field) * valid;
    //         let byte = body_text[byte_index] as Field;
    //         limb += byte * valid;
    //         key_idx += 1;
    //     }
    //     key_fields[j] = limb;
    // }

    // with new method of copying bytes: 88507
    // without new method of copying bytes: 101084
    // diff = 12577
    // 196.5 saving noice
    // rough cost of algorithm is now 8,546? = 133
    // 57,980 without calling this fn
    // 79,103 without pos2
    // => 330 gates per element without hashing wtf
    // 101,105 with pos2
    // poseidon2 has t=4. 1 permutation should cover 3 fields
    // TGODO replace with cheaper hash!
    //  println(f"KEYS BEING HASHED = {key_fields}");
    let hashed_full = dep::std::hash::poseidon2::Poseidon2::hash(key_fields, num_limbs as u32);
    //let hashed_full = key_fields[0] + key_fields[1];
    // println(f"{hashed_full}");
    // hashed_full
    // hashed_full
    //let uv = hashed_full * hashed_full;
    //println(f"{uv}");
    //hashed_full
    slice_200_bits_from_field(hashed_full)
    // let hashed_bytes= dep::std::hash::blake2s(result);
    //    let hashed = fakehash(result); // dep::std::hash::blake2s(result);
    //let hashed_full = limb;
    // let r = slice_200_bits_from_field(hashed_full);
    // println(f"chunky result {r}");
    // r
    // let hashed_bytes = hashed_full.to_be_bytes(32);
    // let mut result: Field = 0;
    // // 200 bits
    // for i in 0..25 {
    //     result *= 0x100;
    //     result += hashed_bytes[25 - i] as Field;
    // }
    // // let key_len = entry.
    // result
}

fn get_keyhash<let N: u32>(body_text: [u8; N], body_index: u16, key_length: u16) -> Field {
    assert(key_length < MaxKeyBytes, "key too large"); // todo fix cast
    //  assert(lt_field_16_bit(key_length, 32), "key too large");
    let mut key_fields: [Field; 10] = [0; 10];
    let mut result: [u8; MaxKeyBytes] = [0; MaxKeyBytes];

    let mut key_idx: u16 = 0;
    let num_limbs = (MaxKeyBytes / 31) + 1; // N.B. will be funky if MaxKeyBytes is multiple of 31
    let mut limb = 0;

    // for j in 0..num_limbs {
    //     let diff = key_length - key_idx;
    //     let full_limb = diff >= 31;
    //     let limb_length = full_limb as Field * 31 + (1 - full_limb as Field) * (diff as Field);
    //     key_fields[j] = sum_var_bytes_into_field(
    //         body_text,
    //         body_index as Field + (j as Field * 31),
    //         limb_length
    //     );
    // }
    for j in 0..num_limbs {
        limb = 0;

        for i in 0..31 {
            let valid = (key_idx < key_length) as Field;
            limb *= (0x100 * valid) + (1 - valid);
            let byte_index = (body_index as Field + key_idx as Field) * valid;
            let byte = body_text[byte_index] as Field;
            limb += byte * valid;
            key_idx += 1;
        }
        key_fields[j] = limb;
        let k = key_fields[j];
        println(f"OLD VERSION key_fields[{j}] = {k}");
    }

    // 57,980 without calling this fn
    // 79,103 without pos2
    // => 330 gates per element without hashing wtf
    // 101,105 with pos2
    // poseidon2 has t=4. 1 permutation should cover 3 fields
    // TGODO replace with cheaper hash!
    //   OLD KEYS BEING HASHED [0x74657374410000000000000000000000000000000000000000000000000000, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]
    // KEYS BEING HASHED = [0x74657374410000000000000000000000000000000000000000000000000000, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]
    let hashed_full = dep::std::hash::poseidon2::Poseidon2::hash(key_fields, num_limbs as u32);
    // let hashed_full = limb;
    // let hashed_bytes= dep::std::hash::blake2s(result);
    //    let hashed = fakehash(result); // dep::std::hash::blake2s(result);
    //let hashed_full = limb;

    // VALUE NOW WITH FANCY SLICE = 87,334
    // VALUE WITHOUT FANCY SLICE = 89,158
    // diff = 28.5 gates per felt. womp womp. but this one is actually sound now
    let mut r = slice_200_bits_from_field(hashed_full);
    println(f"old result {r}");
    r
    // let hashed_bytes = hashed_full.to_be_bytes(32);
    // let mut result: Field = 0;
    // // 200 bits
    // for i in 0..25 {
    //     result *= 0x100;
    //     result += hashed_bytes[25 - i] as Field;
    // }
    // let key_len = entry.
    // result
}
// 0xc7411d9450cce4f0881a2ac0a346f02e1aa1d499535e33336c
// 0xc7411d9450cce4f0881a2ac0a346f02e1aa1d499535e33336c
// 0xc7411d9450cce4f0881a2ac0a346f02e1aa1d499535e33336c