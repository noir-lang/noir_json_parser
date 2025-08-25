use crate::utils::cast_num_to_u32;

/**
 * @file methods to extract data efficiently from Field elements that represent 31 bytes of packed data
 **/

// #############################################################
// ### GLOBAL VARIABLES AND LOOKUP TABLES
// #############################################################
global two_pow_128: Field = 0x100000000000000000000000000000000;
global two_pow_64: Field = 0x10000000000000000;
global two_pow_32: Field = 0x100000000;
global two_pow_16: Field = 0x10000;

global path_multipliers_chunk4: [Field; 32] = [
    /* 0  (00000) */ 0,
    /* 1  (00001) */ 0,
    /* 2  (00010) */ 0,
    /* 3  (00011) */ 0,
    /* 4  (00100) */ 0,
    /* 5  (00101) */ 0,
    /* 6  (00110) */ 0,
    /* 7  (00111) */ 0,
    /* 8  (01000) */ 0,
    /* 9  (01001) */ 0,
    /* 10 (01010) */ 0,
    /* 11 (01011) */ 0,
    /* 12 (01100) */ 0,
    /* 13 (01101) */ 0,
    /* 14 (01110) */ 0,
    /* 15 (01111) */ 0,
    /* 16 (10000) */ 1,
    /* 17 (10001) */ 1,
    /* 18 (10010) */ 1,
    /* 19 (10011) */ 1,
    /* 20 (10100) */ 1,
    /* 21 (10101) */ 1,
    /* 22 (10110) */ 1,
    /* 23 (10111) */ 1,
    /* 24 (11000) */ 1,
    /* 25 (11001) */ 1,
    /* 26 (11010) */ 1,
    /* 27 (11011) */ 1,
    /* 28 (11100) */ 1,
    /* 29 (11101) */ 1,
    /* 30 (11110) */ 1,
    /* 31 (11111) */ 1,
];

// this represents an 8 byte chunk. what do we multiply by?
global path_multipliers_chunk3: [Field; 32] = [
    /* 0  (00000) */ 0,
    /* 1  (00001) */ 0,
    /* 2  (00010) */ 0,
    /* 3  (00011) */ 0,
    /* 4  (00100) */ 0,
    /* 5  (00101) */ 0,
    /* 6  (00110) */ 0,
    /* 7  (00111) */ 0,
    /* 8  (01000) */ 1,
    /* 9  (01001) */ 1,
    /* 10 (01010) */ 1,
    /* 11 (01011) */ 1,
    /* 12 (01100) */ 1,
    /* 13 (01101) */ 1,
    /* 14 (01110) */ 1,
    /* 15 (01111) */ 1,
    /* 16 (10000) */ 0,
    /* 17 (10001) */ 0,
    /* 18 (10010) */ 0,
    /* 19 (10011) */ 0,
    /* 20 (10100) */ 0,
    /* 21 (10101) */ 0,
    /* 22 (10110) */ 0,
    /* 23 (10111) */ 0,
    /* 24 (11000) */ two_pow_128,
    /* 25 (11001) */ two_pow_128,
    /* 26 (11010) */ two_pow_128,
    /* 27 (11011) */ two_pow_128,
    /* 28 (11100) */ two_pow_128,
    /* 29 (11101) */ two_pow_128,
    /* 30 (11110) */ two_pow_128,
    /* 31 (11111) */ two_pow_128,
];

// what do we multiply 4 byte chunk by
global path_multipliers_chunk2: [Field; 32] = [
    /* 0  (00000) */ 0,
    /* 1  (00001) */ 0,
    /* 2  (00010) */ 0,
    /* 3  (00011) */ 0,
    /* 4  (00100) */ 1,
    /* 5  (00101) */ 1,
    /* 6  (00110) */ 1,
    /* 7  (00111) */ 1,
    /* 8  (01000) */ 0,
    /* 9  (01001) */ 0,
    /* 10 (01010) */ 0,
    /* 11 (01011) */ 0,
    /* 12 (01100) */ two_pow_64,
    /* 13 (01101) */ two_pow_64,
    /* 14 (01110) */ two_pow_64,
    /* 15 (01111) */ two_pow_64,
    /* 16 (10000) */ 0,
    /* 17 (10001) */ 0,
    /* 18 (10010) */ 0,
    /* 19 (10011) */ 0,
    /* 20 (10100) */ two_pow_128,
    /* 21 (10101) */ two_pow_128,
    /* 22 (10110) */ two_pow_128,
    /* 23 (10111) */ two_pow_128,
    /* 24 (11000) */ 0,
    /* 25 (11001) */ 0,
    /* 26 (11010) */ 0,
    /* 27 (11011) */ 0,
    /* 28 (11100) */ two_pow_128 * two_pow_64,
    /* 29 (11101) */ two_pow_128 * two_pow_64,
    /* 30 (11110) */ two_pow_128 * two_pow_64,
    /* 31 (11111) */ two_pow_128 * two_pow_64,
];

// what do we multiply 2 byte chunk by
global path_multipliers_chunk1: [Field; 32] = [
    /* 0  (00000) */ 0,
    /* 1  (00001) */ 0,
    /* 2  (00010) */ 1,
    /* 3  (00011) */ 1,
    /* 4  (00100) */ 0,
    /* 5  (00101) */ 0,
    /* 6  (00110) */ two_pow_32,
    /* 7  (00111) */ two_pow_32,
    /* 8  (01000) */ 0,
    /* 9  (01001) */ 0,
    /* 10 (01010) */ two_pow_64,
    /* 11 (01011) */ two_pow_64,
    /* 12 (01100) */ 0,
    /* 13 (01101) */ 0,
    /* 14 (01110) */ two_pow_64 * two_pow_32,
    /* 15 (01111) */ two_pow_64 * two_pow_32,
    /* 16 (10000) */ 0,
    /* 17 (10001) */ 0,
    /* 18 (10010) */ two_pow_128,
    /* 19 (10011) */ two_pow_128,
    /* 20 (10100) */ 0,
    /* 21 (10101) */ 0,
    /* 22 (10110) */ two_pow_128 * two_pow_32,
    /* 23 (10111) */ two_pow_128 * two_pow_32,
    /* 24 (11000) */ 0,
    /* 25 (11001) */ 0,
    /* 26 (11010) */ two_pow_128 * two_pow_64,
    /* 27 (11011) */ two_pow_128 * two_pow_64,
    /* 28 (11100) */ 0,
    /* 29 (11101) */ 0,
    /* 30 (11110) */ two_pow_128 * two_pow_64 * two_pow_32,
    /* 31 (11111) */ two_pow_128 * two_pow_64 * two_pow_32,
];

// what do we multiply 1 byte chunk by
global path_multipliers_chunk0: [Field; 32] = [
    /* 0  (00000) */ 0,
    /* 1  (00001) */ 1,
    /* 2  (00010) */ 0,
    /* 3  (00011) */ two_pow_16,
    /* 4  (00100) */ 0,
    /* 5  (00101) */ two_pow_32,
    /* 6  (00110) */ 0,
    /* 7  (00111) */ two_pow_16 * two_pow_32,
    /* 8  (01000) */ 0,
    /* 9  (01001) */ two_pow_64,
    /* 10 (01010) */ 0,
    /* 11 (01011) */ two_pow_64 * two_pow_16,
    /* 12 (01100) */ 0,
    /* 13 (01101) */ two_pow_64 * two_pow_32,
    /* 14 (01110) */ 0,
    /* 15 (01111) */ two_pow_64 * two_pow_32 * two_pow_16,
    /* 16 (10000) */ 0,
    /* 17 (10001) */ two_pow_128,
    /* 18 (10010) */ 0,
    /* 19 (10011) */ two_pow_128 * two_pow_16,
    /* 20 (10100) */ 0,
    /* 21 (10101) */ two_pow_128 * two_pow_32,
    /* 22 (10110) */ 0,
    /* 23 (10111) */ two_pow_128 * two_pow_32 * two_pow_16,
    /* 24 (11000) */ 0,
    /* 25 (11001) */ two_pow_128 * two_pow_64,
    /* 26 (11010) */ 0,
    /* 27 (11011) */ two_pow_128 * two_pow_64 * two_pow_16,
    /* 28 (11100) */ 0,
    /* 29 (11101) */ two_pow_128 * two_pow_64 * two_pow_32,
    /* 30 (11110) */ 0,
    /* 31 (11111) */ two_pow_128 * two_pow_64 * two_pow_32 * two_pow_16,
];

// these are `head_path_multipliers` but in reverse order
global tail_path_multipliers_chunk3: [Field; 32] = [
    0x0100000000000000000000000000000000,
    0x0100000000000000000000000000000000,
    0x0100000000000000000000000000000000,
    0x0100000000000000000000000000000000,
    0x0100000000000000000000000000000000,
    0x0100000000000000000000000000000000,
    0x0100000000000000000000000000000000,
    0x0100000000000000000000000000000000,
    0x00,
    0x00,
    0x00,
    0x00,
    0x00,
    0x00,
    0x00,
    0x00,
    0x01,
    0x01,
    0x01,
    0x01,
    0x01,
    0x01,
    0x01,
    0x01,
    0x00,
    0x00,
    0x00,
    0x00,
    0x00,
    0x00,
    0x00,
    0x00,
];
global tail_path_multipliers_chunk2: [Field; 32] = [
    0x01000000000000000000000000000000000000000000000000,
    0x01000000000000000000000000000000000000000000000000,
    0x01000000000000000000000000000000000000000000000000,
    0x01000000000000000000000000000000000000000000000000,
    0x00,
    0x00,
    0x00,
    0x00,
    0x0100000000000000000000000000000000,
    0x0100000000000000000000000000000000,
    0x0100000000000000000000000000000000,
    0x0100000000000000000000000000000000,
    0x00,
    0x00,
    0x00,
    0x00,
    0x010000000000000000,
    0x010000000000000000,
    0x010000000000000000,
    0x010000000000000000,
    0x00,
    0x00,
    0x00,
    0x00,
    0x01,
    0x01,
    0x01,
    0x01,
    0x00,
    0x00,
    0x00,
    0x00,
];
global tail_path_multipliers_chunk1: [Field; 32] = [
    0x0100000000000000000000000000000000000000000000000000000000,
    0x0100000000000000000000000000000000000000000000000000000000,
    0x00,
    0x00,
    0x01000000000000000000000000000000000000000000000000,
    0x01000000000000000000000000000000000000000000000000,
    0x00,
    0x00,
    0x010000000000000000000000000000000000000000,
    0x010000000000000000000000000000000000000000,
    0x00,
    0x00,
    0x0100000000000000000000000000000000,
    0x0100000000000000000000000000000000,
    0x00,
    0x00,
    0x01000000000000000000000000,
    0x01000000000000000000000000,
    0x00,
    0x00,
    0x010000000000000000,
    0x010000000000000000,
    0x00,
    0x00,
    0x0100000000,
    0x0100000000,
    0x00,
    0x00,
    0x01,
    0x01,
    0x00,
    0x00,
];
global tail_path_multipliers_chunk0: [Field; 32] = [
    0x01000000000000000000000000000000000000000000000000000000000000,
    0x00,
    0x0100000000000000000000000000000000000000000000000000000000,
    0x00,
    0x010000000000000000000000000000000000000000000000000000,
    0x00,
    0x01000000000000000000000000000000000000000000000000,
    0x00,
    0x0100000000000000000000000000000000000000000000,
    0x00,
    0x010000000000000000000000000000000000000000,
    0x00,
    0x01000000000000000000000000000000000000,
    0x00,
    0x0100000000000000000000000000000000,
    0x00,
    0x010000000000000000000000000000,
    0x00,
    0x01000000000000000000000000,
    0x00,
    0x0100000000000000000000,
    0x00,
    0x010000000000000000,
    0x00,
    0x01000000000000,
    0x00,
    0x0100000000,
    0x00,
    0x010000,
    0x00,
    0x01,
    0x00,
];

// these path variables describe the location of a limb in an array
// e.g. LAST_LIMB_PATH[5] produces 0x00000000f (15 in decimal),
// which is decomposed into ... 0 0 0 0 1 1 1 1 , meaning limbs 0,1,2,3 from the end should contain data
// Each 1 bit in the decomposed array indicates that the corresponding limb should contain valid data
// array extends to 0x3ffffffff which is 2^34 - 1 => 34 31 byte limbs = 1,055 bytes
// this puts a hard limit on the max size of a key that this program supports.
global LAST_LIMB_PATH: [Field; 36] = [
    0x000000000, // 0 0 0 0 0 0 0 0 0 <-- edge case because sometimes array index is -1, so we offset by 1
    0x000000000, // 0 0 0 0 0 0 0 0 0
    0x000000001, // 0 0 0 0 0 0 0 0 1
    0x000000003, // 0 0 0 0 0 0 0 1 1
    0x000000007, // 0 0 0 0 0 0 1 1 1
    0x00000000f, // 0 0 0 0 0 1 1 1 1
    0x00000001f, // 0 0 0 0 1 1 1 1 1
    0x00000003f, // 0 0 0 1 1 1 1 1 1
    0x00000007f, // 0 0 1 1 1 1 1 1 1
    0x0000000ff, // 0 1 1 1 1 1 1 1 1
    0x0000001ff, // 1 1 1 1 1 1 1 1 1
    0x0000003ff, // 1 1 1 1 1 1 1 1 1 1
    0x0000007ff, // 1 1 1 1 1 1 1 1 1 1 1
    0x000000fff, // 1 1 1 1 1 1 1 1 1 1 1 1
    0x000001fff, // 1 1 1 1 1 1 1 1 1 1 1 1 1
    0x000003fff,
    0x000007fff,
    0x00000ffff,
    0x00001ffff,
    0x00003ffff,
    0x00007ffff,
    0x0000fffff,
    0x0001fffff,
    0x0003fffff,
    0x0007fffff,
    0x000ffffff,
    0x001ffffff,
    0x003ffffff,
    0x007ffffff,
    0x00fffffff,
    0x01fffffff,
    0x03fffffff,
    0x07fffffff,
    0x0ffffffff,
    0x1ffffffff,
    0x3ffffffff,
];

global BYTE_SHIFT: [Field; 32] = [
    1,
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
    1,
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
    [true, true, true, true, true],
];

// #############################################################
// ### METHODS
// #############################################################

/**
 * slice a field that represents bytes [0, ..., 31] into 5 chunks where:
 * chunk[0] = 1 byte
 * chunk[1] = 2 bytes
 * chunk[2] = 4 bytes
 * chunk[3] = 8 bytes
 * chunk[4] = 16 bytes
 *
 * some of the chunks will describe the bytes [0, ..., num_bytes - 1]
 * some of the chunks will describe the bytes [num_bytes, ..., 31]
 **/
unconstrained fn __slice_field(f: Field, num_bytes: u32) -> [Field; 5] {
    let head_path = PATH_LOOKUP[num_bytes];
    let bytes: [u8; 32] = f.to_be_bytes();
    let bytes = bytes.map(|b: u8| b as Field);

    let mut chunks: [Field; 5] = [0; 5];
    let mut head_ptr = 1;
    let mut tail_ptr = num_bytes + 1;
    if head_path[0] {
        chunks[0] = bytes[head_ptr] as Field;
        head_ptr += 1;
    } else {
        chunks[0] = bytes[tail_ptr] as Field;
        tail_ptr += 1;
    }
    if head_path[1] {
        chunks[1] = bytes[head_ptr] * 0x100 + bytes[head_ptr + 1];
        head_ptr += 2;
    } else {
        chunks[1] = bytes[tail_ptr] * 0x100 + bytes[tail_ptr + 1];
        tail_ptr += 2;
    }
    if head_path[2] {
        chunks[2] = bytes[head_ptr] * 0x1000000
            + bytes[head_ptr + 1] * 0x10000
            + bytes[head_ptr + 2] * 0x100
            + bytes[head_ptr + 3];
        head_ptr += 4;
    } else {
        chunks[2] = bytes[tail_ptr] * 0x1000000
            + bytes[tail_ptr + 1] * 0x10000
            + bytes[tail_ptr + 2] * 0x100
            + bytes[tail_ptr + 3];
        tail_ptr += 4;
    }
    if head_path[3] {
        chunks[3] = bytes[head_ptr] * 0x100000000000000
            + bytes[head_ptr + 1] * 0x1000000000000
            + bytes[head_ptr + 2] * 0x10000000000
            + bytes[head_ptr + 3] * 0x100000000
            + bytes[head_ptr + 4] * 0x1000000
            + bytes[head_ptr + 5] * 0x10000
            + bytes[head_ptr + 6] * 0x100
            + bytes[head_ptr + 7];
        head_ptr += 8;
    } else {
        chunks[3] = bytes[tail_ptr] * 0x100000000000000
            + bytes[tail_ptr + 1] * 0x1000000000000
            + bytes[tail_ptr + 2] * 0x10000000000
            + bytes[tail_ptr + 3] * 0x100000000
            + bytes[tail_ptr + 4] * 0x1000000
            + bytes[tail_ptr + 5] * 0x10000
            + bytes[tail_ptr + 6] * 0x100
            + bytes[tail_ptr + 7];
        tail_ptr += 8;
    }
    if head_path[4] {
        chunks[4] = bytes[head_ptr] * 0x1000000000000000000000000000000
            + bytes[head_ptr + 1] * 0x10000000000000000000000000000
            + bytes[head_ptr + 2] * 0x100000000000000000000000000
            + bytes[head_ptr + 3] * 0x1000000000000000000000000
            + bytes[head_ptr + 4] * 0x10000000000000000000000
            + bytes[head_ptr + 5] * 0x100000000000000000000
            + bytes[head_ptr + 6] * 0x1000000000000000000
            + bytes[head_ptr + 7] * 0x10000000000000000
            + bytes[head_ptr + 8] * 0x100000000000000
            + bytes[head_ptr + 9] * 0x1000000000000
            + bytes[head_ptr + 10] * 0x10000000000
            + bytes[head_ptr + 11] * 0x100000000
            + bytes[head_ptr + 12] * 0x1000000
            + bytes[head_ptr + 13] * 0x10000
            + bytes[head_ptr + 14] * 0x100
            + bytes[head_ptr + 15];
    } else {
        chunks[4] = bytes[tail_ptr] * 0x1000000000000000000000000000000
            + bytes[tail_ptr + 1] * 0x10000000000000000000000000000
            + bytes[tail_ptr + 2] * 0x100000000000000000000000000
            + bytes[tail_ptr + 3] * 0x1000000000000000000000000
            + bytes[tail_ptr + 4] * 0x10000000000000000000000
            + bytes[tail_ptr + 5] * 0x100000000000000000000
            + bytes[tail_ptr + 6] * 0x1000000000000000000
            + bytes[tail_ptr + 7] * 0x10000000000000000
            + bytes[tail_ptr + 8] * 0x100000000000000
            + bytes[tail_ptr + 9] * 0x1000000000000
            + bytes[tail_ptr + 10] * 0x10000000000
            + bytes[tail_ptr + 11] * 0x100000000
            + bytes[tail_ptr + 12] * 0x1000000
            + bytes[tail_ptr + 13] * 0x10000
            + bytes[tail_ptr + 14] * 0x100
            + bytes[tail_ptr + 15];
    }

    chunks
}

unconstrained fn __divmod(numerator: u16, denominator: u16) -> (u16, u16) {
    let quotient = numerator / denominator;
    let remainder = numerator % denominator;
    (quotient, remainder)
}

/**
 * @brief cheeky divmod method for dividing a u16 by 31
 *        we know the quotient will fit into a 14 bit range check which will save us some fractional gates
 **/
fn divmod_31(numerator: u16) -> (u16, u16) {
    // Safety: we check the bit lengths of qf and rf and their relation to the numerator with assertions later
    let (quotient, remainder) = unsafe { __divmod(numerator, 31) };

    let qf = quotient as Field;
    let rf = remainder as Field;

    // note: these range checks are because we know the denominator is 31
    qf.assert_max_bit_size::<14>();
    rf.assert_max_bit_size::<5>();
    assert(remainder != 31);

    // n / d = q
    // d * q + r = n
    assert(qf * 31 + rf == numerator as Field);
    (quotient, remainder)
}

/**
 * @brief converts a 16 bit value into 16 fake bools (Field elements that are 0 or 1)
 **/
unconstrained fn decompose(val: Field) -> [Field; 16] {
    let mut r: [Field; 16] = [0; 16];

    let mut it = val as u32;
    for i in 0..16 {
        r[i] = (it & 1) as Field;
        it >>= 1;
    }
    r
}

/// Given the index of the last limb in a sequence of 31-byte fields, return a path mask that indicates which fields contain actual data up until the second to last limb.
///
/// The path mask is a bit pattern where each bit represents whether the corresponding field contains data.
///
pub fn get_last_limb_path<let OutputFields: u32>(last_limb_index: Field) -> [Field; OutputFields] {
    // The + 1 offset fixes a special case: when there are 0 bytes of data, last_limb_index becomes -1,
    // which would cause an error when trying to access the array. By adding 1, we turn -1 into 0,
    // which points to a special "empty" entry in the table. For all other cases,
    // the +1 just shifts us to the right spot in the table to get the correct bit pattern.
    // Then we offset by 1 again to exclude the last limb, which is calculated separately.
    // For example, if last_limb_index is 3, it means there are 4 valid limbs, then path variable is 7 (i.e. 00000111)
    // The return value path_valid_output represents the reverse of this number in array form [1, 1, 1, 0, 0, 0, 0, 0]
    let path = LAST_LIMB_PATH[cast_num_to_u32(last_limb_index + 1)]; // 2
    // Safety: check the comments below
    let path_valid_bits = unsafe { decompose(path) };
    let mut path_valid_sum: Field = 0;
    let mut path_valid_output: [Field; OutputFields] = [0; OutputFields];
    for i in 0..OutputFields {
        // we check that the path valid bits are binary
        assert(path_valid_bits[i] * path_valid_bits[i] - path_valid_bits[i] == 0);
        path_valid_sum += (path_valid_bits[i] * (1 << i) as Field);
        path_valid_output[i] = path_valid_bits[i];
    }
    // we check that the path valid bits sum to the path
    assert(path_valid_sum == path);
    path_valid_output
}

/**
 * @brief slice a Field `f`, that represents 31-bytes, into two outputs `head, tail`
 *        where `head = f.slice(0, num_bytes)`, `tail = f.slice(num_bytes, 31)`
 * @details cost 46 gates
 **/
pub fn slice_field(f: Field, num_bytes: u32) -> (Field, Field) {
    // Safety: we check the bit lengths of the chunks with assertions later
    let chunks = unsafe { __slice_field(f, num_bytes) };
    chunks[0].assert_max_bit_size::<8>(); // 1.25 gates
    chunks[1].assert_max_bit_size::<16>(); // 1.5 gates
    chunks[2].assert_max_bit_size::<32>(); // 1.75 gates
    chunks[3].assert_max_bit_size::<64>(); // 3.25 gates
    chunks[4].assert_max_bit_size::<128>(); // 7.5 gates
    let mut head: Field = 0;
    let mut tail: Field = 0;

    // 15 gates
    let temp = path_multipliers_chunk4[num_bytes];
    head = chunks[4] * temp;
    std::as_witness(head);
    head += chunks[3] * path_multipliers_chunk3[num_bytes];
    std::as_witness(head);
    head += chunks[2] * path_multipliers_chunk2[num_bytes];
    std::as_witness(head);
    head += chunks[1] * path_multipliers_chunk1[num_bytes];
    std::as_witness(head);
    head += chunks[0] * path_multipliers_chunk0[num_bytes];

    // 13 gates
    tail = chunks[4] * (1 - temp);
    std::as_witness(tail);
    tail += chunks[3] * tail_path_multipliers_chunk3[num_bytes];
    std::as_witness(tail);
    tail += chunks[2] * tail_path_multipliers_chunk2[num_bytes];
    std::as_witness(tail);
    tail += chunks[1] * tail_path_multipliers_chunk1[num_bytes];
    std::as_witness(tail);
    tail += chunks[0] * tail_path_multipliers_chunk0[num_bytes];
    std::as_witness(tail);

    // 3 gates
    let total = tail + head * BYTE_SHIFT[num_bytes];
    assert(total == f);

    // total 46.25 gates
    (head, tail)
}

/**
 * @brief Given an array of fields that pack 31 bytes, return an array that slices the packed byte array at a given index for a given number of bytes
 **/
pub fn slice_fields<let InputFields: u32, let OutputFields: u32>(
    data: [Field; InputFields],
    start_byte: Field, // starting byte position
    num_bytes: Field, // number of bytes to extract
) -> [Field; OutputFields] {
    start_byte.assert_max_bit_size::<16>();
    num_bytes.assert_max_bit_size::<16>();
    // 3.5
    // calculate Starting Position
    // start_index: which field contains the starting byte
    // start_mod_31: Byte offset within that field (0-30)
    // num_underflow_bytes: same as start_mod_31 (bytes to skip in first field)
    let (start_index, start_mod_31) = divmod_31(start_byte as u16);
    let num_underflow_bytes = start_mod_31;
    // 3.5, 7

    // num_bytes_div_31: Number of complete 31-byte fields needed
    // num_bytes_mod_31: Remaining bytes in the last field
    let (num_bytes_div_31, num_bytes_mod_31) = divmod_31(num_bytes as u16);

    // 2, 9
    //num_bytes_mod_31_is_0: True if num_bytes is a multiple of 31
    //num_bytes_div_31_is_0: True if num_bytes < 31
    let num_bytes_mod_31_is_0 = num_bytes_mod_31 == 0;
    // 2, 11
    let num_bytes_div_31_is_0 = num_bytes_div_31 == 0;

    // Determines if all bytes can fit within the starting field.
    // 3, 15
    let bytes_fit_into_limb =
        start_mod_31 as u32 + cast_num_to_u32(num_bytes) < 31 & num_bytes_div_31_is_0;
    std::as_witness(bytes_fit_into_limb as Field);

    // 2, 17
    // calculate bytes used in first Limb
    // if bytes fit: use all num_bytes
    // if bytes don't fit: use remaining bytes in first field
    let num_unused_bytes_in_start_limb = if bytes_fit_into_limb {
        num_bytes
    } else {
        (31 - start_mod_31 as Field)
    };
    std::as_witness(num_unused_bytes_in_start_limb);
    let num_remaining_bytes = num_bytes - num_unused_bytes_in_start_limb;

    // 4.5, 21.5
    // process remaining bytes
    num_remaining_bytes.assert_max_bit_size::<16>();
    let mut (num_whole_limbs, num_overflow_bytes) = divmod_31(num_remaining_bytes as u16);
    // 44, 65.5
    // extracts the tail portion of the starting field (bytes we want to keep) and discards the head.
    let (_, tail) = slice_field(data[start_index as u32], num_underflow_bytes as u32);

    // 4, 69.5
    // 31 - start_mod_31 is the number of bytes we need from the first limb,  num_overflow_bytes is the number of bytes we need from the last limb
    // if the sum is greater than 31, we need to start a new limb at the end. The data from first limb and last limb don't fit into one.
    let extra_head_section = 31 - start_mod_31 + num_overflow_bytes > 31 & !bytes_fit_into_limb;

    // 1, 70.5
    // the index of the last limb that contains data
    let index_of_output_limb = num_bytes_div_31 as Field - num_bytes_mod_31_is_0 as Field;
    // 5, 75.5
    // index_of_output_limb is -1 if num_bytes is 0 as num_bytes_div_31 is 0 and num_bytes_mod_31_is_0 is 1
    // path_valid_output[i] = 1 means field i should contain actual data, 0 means it should be 0. For example, it could be [1, 1, 0]
    let path_valid_output: [Field; OutputFields] = get_last_limb_path(index_of_output_limb);

    // 2, 77.5
    // For each new limb, we need to combined the end of the previous limb with the start of the new limb,
    // so we need to shift the previous limb by the number of bytes it has remaining
    let tail_shift = BYTE_SHIFT[cast_num_to_u32(num_unused_bytes_in_start_limb)];

    // 51, 128.5
    // process middle fields
    let mut result = [0; OutputFields];
    // starting with the remaining bytes from the first limb
    let mut previous = tail;
    for i in 0..(OutputFields - 1) {
        // 0
        // 1 if this limb should contain actual data
        let slice_valid = path_valid_output[i];
        // 1
        // the index of the current limb in the input array, +1 because we already processed the first limb in tail
        let data_index = (start_index as u32 + i + 1);
        // 2, 3
        let input_slice = data[data_index];
        // 44, 47
        let (head, tail) = slice_field(input_slice, num_underflow_bytes as u32);
        // 1, 48
        let combined = previous * tail_shift + head;
        // 1, 49
        result[i] = combined * slice_valid;
        // 2, 51
        // set to tail if slice_valid is 1, no change if slice_valid is 0
        previous = (tail - previous) * slice_valid + previous;
    }

    // handles the last limb
    // number of bytes to take from the last limb: if all bytes fit in one limb (last limb is first limb): use num_bytes + start_mod_31, else num_overflow_bytes
    let slice_size = (bytes_fit_into_limb as Field) * (num_bytes + start_mod_31 as Field)
        + num_overflow_bytes as Field;
    // use_previous_for_last_limb = does `previous` contain all the data we need for last limb?
    let use_previous_for_last_limb: Field =
        extra_head_section as Field + bytes_fit_into_limb as Field;
    let index_of_overflow_limb = start_index + num_whole_limbs + 1;
    let last_limb_from_data = data[index_of_overflow_limb as u32];
    // if use_previous_for_last_limb = 1: slice_source = previous
    // if use_previous_for_last_limb = 0: slice_source = last_limb_from_data
    let slice_source =
        (previous - last_limb_from_data) * use_previous_for_last_limb + last_limb_from_data;
    let (head, _) = slice_field(slice_source, cast_num_to_u32(slice_size));

    // assembled the final field
    let previous_shift = BYTE_SHIFT[31 - num_overflow_bytes as u32]; // could save 1 gate by making different shift table
    let last_limb_shift = BYTE_SHIFT[num_bytes_mod_31 as u32];
    let mut last_limb = (previous * previous_shift);
    std::as_witness(last_limb);
    last_limb = last_limb * (-use_previous_for_last_limb) + last_limb + head;
    std::as_witness(last_limb);
    last_limb = last_limb * last_limb_shift;
    std::as_witness(last_limb);

    // This blocks is used to fill the first limb that doesn't contain data with last_limb.
    let mut path: [Field; OutputFields] = [0; OutputFields];
    path[0] = (1 - path_valid_output[0]);
    for i in 1..OutputFields {
        // path[i] is set to 1 when path_valid_output[i] is 0 and path_valid_output[i-1] is 1, i.e. the first limb that that doesn't contain data,
        // which is the limb that we will use to fill the last_limb data.
        path[i] = path_valid_output[i] * -path_valid_output[i - 1] + path_valid_output[i - 1];
    }
    for i in 0..OutputFields {
        result[i] = (last_limb - result[i]) * path[i] + result[i];
    }

    result
}

mod test {
    use crate::_string_tools::slice_packed_field::slice_field;
    use crate::_string_tools::slice_packed_field::slice_fields;

    mod get_last_limb_path {
        use crate::_string_tools::slice_packed_field::get_last_limb_path;

        #[test]
        fn returns_expected_values() {
            // test cases taken from documentation on `LAST_LIMB_PATH`, note that indices are offset by 1 from
            // the value passed to `get_last_limb_path`.
            let test_cases: [[Field; 9]] =
                [[0, 0, 0, 0, 0, 0, 0, 0, 0], [1, 0, 0, 0, 0, 0, 0, 0, 0]];
            for i in 0..test_cases.len() {
                let path = get_last_limb_path(i as Field);
                let expected_path = test_cases[i];
                assert_eq(
                    path,
                    test_cases[i],
                    f"Expected {path} to equal {expected_path} for index {i}",
                );
            }
        }
    }

    unconstrained fn build_slices_for_test<let N: u32>(
        bytes: [u8; N],
        start: u32,
        num_bytes: u32,
    ) -> [Field; 3] {
        let mut slices: [Field; 3] = [0; 3];
        for i in 0..3 {
            for k in 0..31 {
                let mut idx = i * 31 + k;
                slices[i] *= 0x100;
                if (idx < num_bytes) {
                    slices[i] += bytes[idx + start] as Field;
                }
            }
        }
        slices
    }

    #[test]
    fn test_slice_fields_nolength() {
        let text: [u8; 1405] = "Charlie is genius, right. He's made from a million pieces of old bubble gum. Imagine that! In the summer of 1976, on his way home from an Alice Cooper concert, Charlie started to melt onto the pavement. It was too hot in L.A., and he melted like a pink bitch. Luckily though, there was Eric Phillips, a local crocodile who dabbled in black magic. He took pity on Charlie and scraped him off the floor with a pair of fish slicers. He poured him into an antique soup ladle, and boarded his magic carpet. Destination: Alaska! Eric Phillips decided to refreeze Charlie, but in his cold-blooded reptilian haste, he refroze him into to the shape of a Hoover. Charlie wasn't fazed though, he just zoomed about the place, sucking up Inuits. Ha ha! Oh. The Inuits didn't mind; they loved it in Charlie's pink, tight warm belly pouch, and they refused to come out. Charlie said, \"I'm cool with that,\" and set fire to a posh hammer to make it official. he downside was that the Inuits suffocated immediately. It was air-tight in there. Charlie panicked and fired the tiny Inuit bullets into Eric's crocodile peepers. The green shape was frozen. After a quick drink, Charlie stole Eric Phillips's magic carpet and left for Seattle. Charlie was racked with guilt: he'd killed 50 Inuits, noone needs that. He decided to spend the rest of his life putting small hairstyles onto boots, monkey nuts, trumpets and spanners."
            .as_bytes();
        let mut slices: [Field; 46 + 3] = [0; 46 + 3];
        for i in 0..46 {
            for j in 0..31 {
                let mut idx = i * 31 + j;
                slices[i] *= 0x100;
                if (idx < 1405) {
                    slices[i] += text[idx] as Field;
                }
            }
        }
        // let start_byte = 26;
        let num_bytes = 0;
        let start_byte: u32 = 0;
        // Safety: this is a test
        let mut expected_slices: [Field; 3] =
            unsafe { build_slices_for_test(text, start_byte, num_bytes) };
        let result_slices: [Field; 3] =
            slice_fields(slices, start_byte as Field, num_bytes as Field);
        assert(result_slices == expected_slices);
    }

    #[test]
    fn test_slice_fields() {
        let text: [u8; 1405] = "Charlie is genius, right. He's made from a million pieces of old bubble gum. Imagine that! In the summer of 1976, on his way home from an Alice Cooper concert, Charlie started to melt onto the pavement. It was too hot in L.A., and he melted like a pink bitch. Luckily though, there was Eric Phillips, a local crocodile who dabbled in black magic. He took pity on Charlie and scraped him off the floor with a pair of fish slicers. He poured him into an antique soup ladle, and boarded his magic carpet. Destination: Alaska! Eric Phillips decided to refreeze Charlie, but in his cold-blooded reptilian haste, he refroze him into to the shape of a Hoover. Charlie wasn't fazed though, he just zoomed about the place, sucking up Inuits. Ha ha! Oh. The Inuits didn't mind; they loved it in Charlie's pink, tight warm belly pouch, and they refused to come out. Charlie said, \"I'm cool with that,\" and set fire to a posh hammer to make it official. he downside was that the Inuits suffocated immediately. It was air-tight in there. Charlie panicked and fired the tiny Inuit bullets into Eric's crocodile peepers. The green shape was frozen. After a quick drink, Charlie stole Eric Phillips's magic carpet and left for Seattle. Charlie was racked with guilt: he'd killed 50 Inuits, noone needs that. He decided to spend the rest of his life putting small hairstyles onto boots, monkey nuts, trumpets and spanners."
            .as_bytes();
        let mut slices: [Field; 46 + 3] = [0; 46 + 3];
        for i in 0..46 {
            for j in 0..31 {
                let mut idx = i * 31 + j;
                slices[i] *= 0x100;
                if (idx < 1405) {
                    slices[i] += text[idx] as Field;
                }
            }
        }
        // let start_byte = 26;
        let byte_sizes: [u32; 10] = [0, 1, 5, 30, 31, 32, 47, 61, 62, 90];

        let byte_positions: [u32; 18] =
            [0, 1, 14, 15, 16, 20, 28, 29, 30, 31, 32, 33, 38, 40, 55, 60, 61, 62];

        for i in 0..10 {
            let num_bytes = byte_sizes[i];
            for j in 0..18 {
                let start_byte: u32 = byte_positions[j];
                // Safety: this is a test
                let mut expected_slices: [Field; 3] =
                    unsafe { build_slices_for_test(text, start_byte, num_bytes) };
                let result_slices: [Field; 3] =
                    slice_fields(slices, start_byte as Field, num_bytes as Field);
                assert(result_slices == expected_slices);
            }

            for j in 0..18 {
                let start_byte: u32 = text.len() - num_bytes - byte_positions[j];
                let mut expected_slices: [Field; 3] =
                    // Safety: this is a test
                    unsafe { build_slices_for_test(text, start_byte, num_bytes) };
                let result_slices: [Field; 3] =
                    slice_fields(slices, start_byte as Field, num_bytes as Field);
                assert(result_slices == expected_slices);
            }
        }
    }

    #[test]
    fn test_slice_field() {
        let input = 0xffeebbccbbaa99887766554433221100112233445566778899aabbccddeeff;

        let input_bytes: [u8; 32] = input.to_be_bytes();

        for i in 0..32 {
            let num_bytes = i;
            let (head, tail) = slice_field(input, num_bytes);
            let mut expected_head: Field = 0;
            let mut expected_tail: Field = 0;
            for j in 0..num_bytes as u32 {
                expected_head *= 0x100;
                expected_head += input_bytes[j + 1] as Field;
            }
            for j in 0..(31 - num_bytes as u32) {
                expected_tail *= 0x100;
                expected_tail += input_bytes[j + num_bytes + 1] as Field;
            }
            assert(expected_head == head);
            assert(expected_tail == tail);
        }
        let (head, tail) = slice_field(input, 11);
        let head_expected = 0xffeebbccbbaa9988776655;
        let tail_expected = 0x4433221100112233445566778899aabbccddeeff;
        assert(head_expected == head);
        assert(tail_expected == tail);
    }
}
