/**
 * @file methods to extract data efficiently from Field elements that represent 31 bytes of packed data
 **/

// #############################################################
// ### GLOBAL VARIABLES AND LOOKUP TABLES
// #############################################################
global two_pow_128 = 0x100000000000000000000000000000000;
global two_pow_64 = 0x10000000000000000;
global two_pow_32 = 0x100000000;
global two_pow_16 = 0x10000;

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
    /* 31 (11111) */ 1
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
    /* 31 (11111) */ two_pow_128
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
    /* 31 (11111) */ two_pow_128 * two_pow_64
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
    /* 31 (11111) */ two_pow_128 * two_pow_64 * two_pow_32
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
    /* 31 (11111) */ two_pow_128 * two_pow_64 * two_pow_32 * two_pow_16
];

// these are `head_path_multipliers` but in reverse order
global tail_path_multipliers_chunk3: [Field; 32] = [0x0100000000000000000000000000000000, 0x0100000000000000000000000000000000, 0x0100000000000000000000000000000000, 0x0100000000000000000000000000000000, 0x0100000000000000000000000000000000, 0x0100000000000000000000000000000000, 0x0100000000000000000000000000000000, 0x0100000000000000000000000000000000, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00];
global tail_path_multipliers_chunk2: [Field; 32] = [0x01000000000000000000000000000000000000000000000000, 0x01000000000000000000000000000000000000000000000000, 0x01000000000000000000000000000000000000000000000000, 0x01000000000000000000000000000000000000000000000000, 0x00, 0x00, 0x00, 0x00, 0x0100000000000000000000000000000000, 0x0100000000000000000000000000000000, 0x0100000000000000000000000000000000, 0x0100000000000000000000000000000000, 0x00, 0x00, 0x00, 0x00, 0x010000000000000000, 0x010000000000000000, 0x010000000000000000, 0x010000000000000000, 0x00, 0x00, 0x00, 0x00, 0x01, 0x01, 0x01, 0x01, 0x00, 0x00, 0x00, 0x00];
global tail_path_multipliers_chunk1: [Field; 32] = [0x0100000000000000000000000000000000000000000000000000000000, 0x0100000000000000000000000000000000000000000000000000000000, 0x00, 0x00, 0x01000000000000000000000000000000000000000000000000, 0x01000000000000000000000000000000000000000000000000, 0x00, 0x00, 0x010000000000000000000000000000000000000000, 0x010000000000000000000000000000000000000000, 0x00, 0x00, 0x0100000000000000000000000000000000, 0x0100000000000000000000000000000000, 0x00, 0x00, 0x01000000000000000000000000, 0x01000000000000000000000000, 0x00, 0x00, 0x010000000000000000, 0x010000000000000000, 0x00, 0x00, 0x0100000000, 0x0100000000, 0x00, 0x00, 0x01, 0x01, 0x00, 0x00];
global tail_path_multipliers_chunk0: [Field; 32] = [0x01000000000000000000000000000000000000000000000000000000000000, 0x00, 0x0100000000000000000000000000000000000000000000000000000000, 0x00, 0x010000000000000000000000000000000000000000000000000000, 0x00, 0x01000000000000000000000000000000000000000000000000, 0x00, 0x0100000000000000000000000000000000000000000000, 0x00, 0x010000000000000000000000000000000000000000, 0x00, 0x01000000000000000000000000000000000000, 0x00, 0x0100000000000000000000000000000000, 0x00, 0x010000000000000000000000000000, 0x00, 0x01000000000000000000000000, 0x00, 0x0100000000000000000000, 0x00, 0x010000000000000000, 0x00, 0x01000000000000, 0x00, 0x0100000000, 0x00, 0x010000, 0x00, 0x01, 0x00];

global LIMB_VALID_PATH: [Field; 35] = [
0x000000000, // 0 0 0 0 0 0 0 0 0
0x000000001, // 0 0 0 0 0 0 0 0 1
0x000000003, // 0 0 0 0 0 0 0 1 1
0x000000007, // 0 0 0 0 0 0 1 1 1
0x000000008, // 0 0 0 0 0 1 1 1 1
0x000000010, // 0 0 0 0 1 0 0 0 0
0x000000020, // 0 0 0 1 0 0 0 0 0
0x000000040, // 0 0 1 0 0 0 0 0 0
0x000000080, // 0 1 0 0 0 0 0 0 0
0x000000100, // 1 0 0 0 0 0 0 0 0
0x000000200, // 0 0 0 0 0 0 0 1 0
0x000000400, // 0 0 0 0 0 0 1 0 0
0x000000800, // 0 0 0 0 0 1 0 0 0
0x000001000, // 0 0 0 0 1 0 0 0 0
0x000002000, // 0 0 0 1 0 0 0 0 0
0x000004000, // 0 0 1 0 0 0 0 0 0
0x000008000, // 0 1 0 0 0 0 0 0 0
0x000010000, // 0 0 0 0 0 0 0 0 1
0x000020000, // 0 0 0 0 0 0 0 1 0
0x000040000, // 0 0 0 0 0 0 1 0 0
0x000080000, // 0 0 0 0 0 1 0 0 0
0x000100000, // 0 0 0 0 1 0 0 0 0
0x000200000, // 0 0 0 1 0 0 0 0 0
0x000400000, // 0 0 1 0 0 0 0 0 0
0x000800000, // 0 1 0 0 0 0 0 0 0
0x001000000, // 0 0 0 0 0 0 0 0 1
0x002000000, // 0 0 0 0 0 0 0 1 0
0x004000000, // 0 0 0 0 0 0 1 0 0
0x008000000, // 0 0 0 0 0 1 0 0 0
0x010000000, // 0 0 0 0 1 0 0 0 0
0x020000000, // 0 0 0 1 0 0 0 0 0
0x040000000, // 0 0 1 0 0 0 0 0 0
0x080000000, // 0 1 0 0 0 0 0 0 0
0x100000000,
0x200000000
];

// these path variables describe the location of a limb in an array
// e.g. LAST_LIMB_PATH[5] produces 2^{5-1},
// which is decomposed into 1 0 0 0 0, and the decompositions turned into an array M
// M[4] = 1 i.e. the limbs[4] should contain the last limb
// array extends to 0x200000000 which is 2^33 => 33 31 byte limbs = 1,023 bytes
// this puts a hard limit on the max size of a key that this program supports.
global LAST_LIMB_PATH: [Field; 36] = [
0x000000000, // 0 0 0 0 0 0 0 0 0 <-- edge case because sometimes array index is -1, so we offset by 1 TODO explain better
0x000000000, // 0 0 0 0 0 0 0 0 1
0x000000001, // 0 0 0 0 0 0 0 1 0
0x000000003, // 0 0 0 0 0 0 1 0 0
0x000000007, // 0 0 0 0 0 1 0 0 0
0x00000000f, // 0 0 0 0 1 0 0 0 0
0x00000001f, // 0 0 0 1 0 0 0 0 0
0x00000003f, // 0 0 1 0 0 0 0 0 0
0x00000007f, // 0 1 0 0 0 0 0 0 0
0x0000000ff, // 1 0 0 0 0 0 0 0 0
0x0000001ff, // 0 0 0 0 0 0 0 1 0
0x0000003ff, // 0 0 0 0 0 0 1 0 0
0x0000007ff, // 0 0 0 0 0 1 0 0 0
0x000000fff, // 0 0 0 0 1 0 0 0 0
0x000001fff, // 0 0 0 1 0 0 0 0 0
0x000003fff, // 0 0 1 0 0 0 0 0 0
0x000007fff, // 0 1 0 0 0 0 0 0 0
0x00000ffff, // 0 0 0 0 0 0 0 0 1
0x00001ffff, // 0 0 0 0 0 0 0 1 0
0x00003ffff, // 0 0 0 0 0 0 1 0 0
0x00007ffff, // 0 0 0 0 0 1 0 0 0
0x0000fffff, // 0 0 0 0 1 0 0 0 0
0x0001fffff, // 0 0 0 1 0 0 0 0 0
0x0003fffff, // 0 0 1 0 0 0 0 0 0
0x0007fffff, // 0 1 0 0 0 0 0 0 0
0x000ffffff, // 0 0 0 0 0 0 0 0 1
0x001ffffff, // 0 0 0 0 0 0 0 1 0
0x003ffffff, // 0 0 0 0 0 0 1 0 0
0x007ffffff, // 0 0 0 0 0 1 0 0 0
0x00fffffff, // 0 0 0 0 1 0 0 0 0
0x01fffffff, // 0 0 0 1 0 0 0 0 0
0x03fffffff, // 0 0 1 0 0 0 0 0 0
0x07fffffff, // 0 1 0 0 0 0 0 0 0
0x0ffffffff,
0x1ffffffff,
0x3ffffffff
];

global INTEGER_UP_TO_62_IS_GREATER_THAN_31: [Field; 63] = [
0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
];
global NUM_BYTES_MOD_31_IS_ZERO: [Field; 31] = [
    1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
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
unconstrained fn __slice_field(f: Field, num_bytes: Field) -> [Field; 5] {
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
        chunks[2] = bytes[head_ptr] * 0x1000000 + bytes[head_ptr + 1] * 0x10000
        + bytes[head_ptr + 2] * 0x100 + bytes[head_ptr + 3];
        head_ptr += 4;
    } else {
        chunks[2] = bytes[tail_ptr] * 0x1000000 + bytes[tail_ptr + 1] * 0x10000
        + bytes[tail_ptr + 2] * 0x100 + bytes[tail_ptr + 3];
        tail_ptr += 4;
    }
    if head_path[3] {
        chunks[3] =
        bytes[head_ptr] * 0x100000000000000 + bytes[head_ptr + 1] * 0x1000000000000
        + bytes[head_ptr + 2] * 0x10000000000 + bytes[head_ptr + 3] * 0x100000000
        + bytes[head_ptr + 4] * 0x1000000 + bytes[head_ptr + 5] * 0x10000
        + bytes[head_ptr + 6] * 0x100 + bytes[head_ptr + 7];
        head_ptr += 8;
    } else {
        chunks[3] =
        bytes[tail_ptr] * 0x100000000000000 + bytes[tail_ptr + 1] * 0x1000000000000
        + bytes[tail_ptr + 2] * 0x10000000000 + bytes[tail_ptr + 3] * 0x100000000
        + bytes[tail_ptr + 4] * 0x1000000 + bytes[tail_ptr + 5] * 0x10000
        + bytes[tail_ptr + 6] * 0x100 + bytes[tail_ptr + 7];
        tail_ptr += 8;
    }
    if head_path[4] {
        chunks[4] =
        bytes[head_ptr] *       0x1000000000000000000000000000000 + bytes[head_ptr + 1] * 0x10000000000000000000000000000
        + bytes[head_ptr + 2] * 0x100000000000000000000000000 + bytes[head_ptr + 3] *      0x1000000000000000000000000
        + bytes[head_ptr + 4] * 0x10000000000000000000000 + bytes[head_ptr + 5] * 0x100000000000000000000
        + bytes[head_ptr + 6] * 0x1000000000000000000 + bytes[head_ptr + 7] * 0x10000000000000000
        + bytes[head_ptr + 8] * 0x100000000000000 + bytes[head_ptr + 9] * 0x1000000000000
        + bytes[head_ptr + 10] * 0x10000000000 + bytes[head_ptr + 11] * 0x100000000
        + bytes[head_ptr + 12] * 0x1000000 + bytes[head_ptr + 13] * 0x10000
        + bytes[head_ptr + 14] * 0x100 + bytes[head_ptr + 15];
    } else {
        chunks[4] =
        bytes[tail_ptr] * 0x1000000000000000000000000000000 + bytes[tail_ptr + 1] * 0x10000000000000000000000000000
        + bytes[tail_ptr + 2] * 0x100000000000000000000000000 + bytes[tail_ptr + 3] * 0x1000000000000000000000000
        + bytes[tail_ptr + 4] * 0x10000000000000000000000 + bytes[tail_ptr + 5] * 0x100000000000000000000
        + bytes[tail_ptr + 6] * 0x1000000000000000000 + bytes[tail_ptr + 7] * 0x10000000000000000
        + bytes[tail_ptr + 8] * 0x100000000000000 + bytes[tail_ptr + 9] * 0x1000000000000
        + bytes[tail_ptr + 10] * 0x10000000000 + bytes[tail_ptr + 11] * 0x100000000
        + bytes[tail_ptr + 12] * 0x1000000 + bytes[tail_ptr + 13] * 0x10000
        + bytes[tail_ptr + 14] * 0x100 + bytes[tail_ptr + 15];
    }

    chunks
}

unconstrained fn __divmod(numerator: Field, denominator: Field) -> (Field, Field) {
    let quotient = numerator as u32 / denominator as u32;
    let remainder = numerator as u32 % denominator as u32;
    (quotient as Field, remainder as Field)
}

/**
 * @brief cheeky divmod method for dividing a u16 by 31
 *        we know the quotient will fit into a 14 bit range check which will save us some fractional gates
 **/
fn divmod_31(numerator: Field) -> (Field, Field) {
    let (quotient, remainder) = __divmod(numerator, 31);

    let qf = quotient as Field;
    let rf = remainder as Field;

    // note: these range checks are because we know the denominator is 31
    // TODO: need more checks, atm remainder could equal 31
    qf.assert_max_bit_size::<14>();
    rf.assert_max_bit_size::<5>();

    // n / d = q
    // d * q + r = n
    assert(qf * 31 as Field + rf == numerator as Field);
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

// 5 gates?
pub fn get_last_limb_path<let OutputFields: u32>(last_limb_index: Field) -> [Field; OutputFields] {
    // TODO we offset by 1 explain why (0 byte length produces 0 - 1 which = invalid array index. we just add 1 and increase array length by 1 to compensate)
    let path = LAST_LIMB_PATH[last_limb_index + 1]; // 2

    let path_valid_bits = decompose(path);
    let mut path_valid_sum: Field = 0;
    let mut path_valid_output: [Field; OutputFields] = [0; OutputFields];
    for i in 0..OutputFields {
        assert(path_valid_bits[i] * path_valid_bits[i] - path_valid_bits[i] == 0);
        path_valid_sum += (path_valid_bits[i] * (1 << i as u8) as Field);
        path_valid_output[i] = path_valid_bits[i];
    }
    assert(path_valid_sum == path);
    path_valid_output
}

/**
 * @brief slice a Field `f`, that represents 31-bytes, into two outputs `head, tail`
 *        where `head = f.slice(0, num_bytes)`, `tail = f.slice(num_bytes, 31)`
 * @details cost 46 gates
 **/
pub fn slice_field(f: Field, num_bytes: Field) -> (Field, Field) {
    let chunks = __slice_field(f, num_bytes);
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
 * @description Some serious dark black magic nonsense going on here. TODO: document
 **/
pub fn slice_fields<let InputFields: u32, let OutputFields: u32>(
    data: [Field; InputFields],
    start_byte: Field,
    num_bytes: Field
) -> [Field; OutputFields] {
    // 3.5
    let (start_index, start_mod_31) = divmod_31(start_byte);
    let num_underflow_bytes = start_mod_31;
    // 3.5, 7
    let (num_bytes_div_31, num_bytes_mod_31) = divmod_31(num_bytes);

    // 2, 9
    let num_bytes_mod_31_is_0 = NUM_BYTES_MOD_31_IS_ZERO[num_bytes_mod_31];
    // 2, 11
    let num_bytes_div_31_is_0 = NUM_BYTES_MOD_31_IS_ZERO[num_bytes_div_31];

    // 1, 12
    let lookup = (-num_bytes_div_31_is_0 * num_bytes) - start_mod_31 + 62;
    std::as_witness(lookup);
    // 3, 15
    let bytes_fit_into_limb = INTEGER_UP_TO_62_IS_GREATER_THAN_31[lookup] * num_bytes_div_31_is_0;
    std::as_witness(bytes_fit_into_limb);

    // 2, 17
    let num_unused_bytes_in_start_limb = (num_bytes + start_mod_31 - 31) * bytes_fit_into_limb + (31 - start_mod_31);
    std::as_witness(num_unused_bytes_in_start_limb);
    let num_remaining_bytes = num_bytes - num_unused_bytes_in_start_limb;

    // 4.5, 21.5
    let mut (num_whole_limbs, num_overflow_bytes) = divmod_31(num_remaining_bytes);
    // 44, 65.5
    let (_, tail) = slice_field(data[start_index], num_underflow_bytes);

    let mut previous = tail;

    let mut result = [0; OutputFields];

    // 4, 69.5
    let extra_head_section = INTEGER_UP_TO_62_IS_GREATER_THAN_31[num_overflow_bytes - start_mod_31 + 31]
        * (1 - bytes_fit_into_limb);

    // 1, 70.5
    let index_of_output_limb: Field = (num_bytes_div_31 - num_bytes_mod_31_is_0);
    // 5, 75.5
    let path_valid_output: [Field; OutputFields] = get_last_limb_path(index_of_output_limb);

    // 2, 77.5
    let tail_shift = BYTE_SHIFT[num_unused_bytes_in_start_limb];

    // 51, 128.5
    for i in 0..(OutputFields - 1) {
        // 0
        let slice_valid = path_valid_output[i];
        // 1
        let data_index = (start_index + 1 + i as Field);
        // 2, 3
        let input_slice = data[data_index];
        // 44, 47
        let (head, tail) = slice_field(input_slice, num_underflow_bytes);
        // 1, 48
        let combined = previous * tail_shift + head;
        // 1, 49
        result[i] = combined * slice_valid;
        // 2, 51
        previous = (tail - previous) * slice_valid + previous;
    }

    // 2, 130.5
    let slice_size = (num_bytes + start_mod_31) * bytes_fit_into_limb + num_overflow_bytes;

    // 1, 131.5
    let use_previous_for_last_limb: Field = extra_head_section + bytes_fit_into_limb;

    // 1, 132.5
    let mut index_of_overflow_limb = start_index + num_whole_limbs + 1;
    // 2, 134.5
    let last_limb_from_data = data[index_of_overflow_limb];
    // 2, 136.5
    let slice_source = (previous - last_limb_from_data) * use_previous_for_last_limb + last_limb_from_data;

    // 44, 180.5
    let (head, _) = slice_field(slice_source, slice_size);

    // 3, 183.5
    let previous_shift = BYTE_SHIFT[31 - num_overflow_bytes]; // could save 1 gate by making different shift table
    // 2, 185.5
    let last_limb_shift = BYTE_SHIFT[num_bytes_mod_31];
    // 1, 186.5
    let mut last_limb = (previous * previous_shift);
    std::as_witness(last_limb);
    // 1, 187.5
    last_limb = last_limb * (-use_previous_for_last_limb) + last_limb + head;
    std::as_witness(last_limb);
    // 1, 188.5
    last_limb = last_limb * last_limb_shift;
    std::as_witness(last_limb);

    let mut path: [Field; OutputFields] = [0; OutputFields];
    // 2, 190.5
    for i in 1..OutputFields {
        path[i] = path_valid_output[i] * -path_valid_output[i-1] + path_valid_output[i-1];
    }
    // 1, 191.5
    path[0] = (1 - path_valid_output[0]);

    // 4, 195.5
    // actual valud = 182, missing gates?
    for i in 0..OutputFields {
        // 2
        result[i] = (last_limb - result[i]) * path[i] + result[i];
        // std::as_witness(result[i]);
    }
    // actual value = 182?
    result
}

mod test {
    use crate::_string_tools::slice_packed_field::slice_field;
    use crate::_string_tools::slice_packed_field::slice_fields;

    unconstrained fn build_slices_for_test<let N: u32>(
        bytes: [u8; N],
        start: u32,
        num_bytes: u32
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
        let text: [u8; 1405] = "Charlie is genius, right. He's made from a million pieces of old bubble gum. Imagine that! In the summer of 1976, on his way home from an Alice Cooper concert, Charlie started to melt onto the pavement. It was too hot in L.A., and he melted like a pink bitch. Luckily though, there was Eric Phillips, a local crocodile who dabbled in black magic. He took pity on Charlie and scraped him off the floor with a pair of fish slicers. He poured him into an antique soup ladle, and boarded his magic carpet. Destination: Alaska! Eric Phillips decided to refreeze Charlie, but in his cold-blooded reptilian haste, he refroze him into to the shape of a Hoover. Charlie wasn't fazed though, he just zoomed about the place, sucking up Inuits. Ha ha! Oh. The Inuits didn't mind; they loved it in Charlie's pink, tight warm belly pouch, and they refused to come out. Charlie said, \"I'm cool with that,\" and set fire to a posh hammer to make it official. he downside was that the Inuits suffocated immediately. It was air-tight in there. Charlie panicked and fired the tiny Inuit bullets into Eric's crocodile peepers. The green shape was frozen. After a quick drink, Charlie stole Eric Phillips's magic carpet and left for Seattle. Charlie was racked with guilt: he'd killed 50 Inuits, noone needs that. He decided to spend the rest of his life putting small hairstyles onto boots, monkey nuts, trumpets and spanners.".as_bytes();
        println(f"text = {text}");
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
        let mut expected_slices: [Field; 3] = build_slices_for_test(text, start_byte, num_bytes);
        let result_slices: [Field; 3] = slice_fields(slices, start_byte as Field, num_bytes as Field);
        assert(result_slices == expected_slices);
    }

    #[test]
    fn test_slice_fields() {
        let text: [u8; 1405] = "Charlie is genius, right. He's made from a million pieces of old bubble gum. Imagine that! In the summer of 1976, on his way home from an Alice Cooper concert, Charlie started to melt onto the pavement. It was too hot in L.A., and he melted like a pink bitch. Luckily though, there was Eric Phillips, a local crocodile who dabbled in black magic. He took pity on Charlie and scraped him off the floor with a pair of fish slicers. He poured him into an antique soup ladle, and boarded his magic carpet. Destination: Alaska! Eric Phillips decided to refreeze Charlie, but in his cold-blooded reptilian haste, he refroze him into to the shape of a Hoover. Charlie wasn't fazed though, he just zoomed about the place, sucking up Inuits. Ha ha! Oh. The Inuits didn't mind; they loved it in Charlie's pink, tight warm belly pouch, and they refused to come out. Charlie said, \"I'm cool with that,\" and set fire to a posh hammer to make it official. he downside was that the Inuits suffocated immediately. It was air-tight in there. Charlie panicked and fired the tiny Inuit bullets into Eric's crocodile peepers. The green shape was frozen. After a quick drink, Charlie stole Eric Phillips's magic carpet and left for Seattle. Charlie was racked with guilt: he'd killed 50 Inuits, noone needs that. He decided to spend the rest of his life putting small hairstyles onto boots, monkey nuts, trumpets and spanners.".as_bytes();
        println(f"text = {text}");
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

        let byte_sizes: [u32; 10] = [
            0,
            1,
            5,
            30,
            31,
            32,
            47,
            61,
            62,
            90
        ];

        let byte_positions: [u32; 18] = [
            0,
            1,
            14,
            15,
            16,
            20,
            28,
            29,
            30,
            31,
            32,
            33,
            38,
            40,
            55,
            60,
            61,
            62
        ];

        for i in 0..10 {
            let num_bytes = byte_sizes[i];
            for j in 0..18 {
                let start_byte: u32 = byte_positions[j];
                let mut expected_slices: [Field; 3] = build_slices_for_test(text, start_byte, num_bytes);
                let result_slices: [Field; 3] = slice_fields(slices, start_byte as Field, num_bytes as Field);
                assert(result_slices == expected_slices);
            }

            for j in 0..18 {
                let start_byte: u32 = text.len() - num_bytes - byte_positions[j];
                let mut expected_slices: [Field; 3] = build_slices_for_test(text, start_byte, num_bytes);
                let result_slices: [Field; 3] = slice_fields(slices, start_byte as Field, num_bytes as Field);
                assert(result_slices == expected_slices);
            }
        }
    }

    #[test]
    fn test_slice_field() {
        let input = 0xffeebbccbbaa99887766554433221100112233445566778899aabbccddeeff;

        let input_bytes: [u8; 32] = input.to_be_bytes();

        for i in 0..32 {
            println(f"i = {i}");
            let num_bytes = i as Field;
            let (head, tail) = slice_field(input, num_bytes);
            let mut expected_head: Field = 0;
            let mut expected_tail: Field = 0;
            for j in 0..num_bytes as u32 {
                expected_head *= 0x100;
                expected_head += input_bytes[j + 1] as Field;
            }
            for j in 0..(31 - num_bytes as u32) {
                expected_tail *= 0x100;
                expected_tail += input_bytes[j as Field + num_bytes + 1] as Field;
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
