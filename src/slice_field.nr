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

unconstrained fn __slice_field(f: Field, num_bytes: Field) -> [Field; 5] {
    let head_path = PATH_LOOKUP[num_bytes];

    let bytes = f.to_be_bytes(32);
    let bytes = bytes.map(|b| b as Field);

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
global tail_path_multipliers_chunk3: [Field; 32] = [0x0100000000000000000000000000000000, 0x0100000000000000000000000000000000, 0x0100000000000000000000000000000000, 0x0100000000000000000000000000000000, 0x0100000000000000000000000000000000, 0x0100000000000000000000000000000000, 0x0100000000000000000000000000000000, 0x0100000000000000000000000000000000, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00];
global tail_path_multipliers_chunk2: [Field; 32] = [0x01000000000000000000000000000000000000000000000000, 0x01000000000000000000000000000000000000000000000000, 0x01000000000000000000000000000000000000000000000000, 0x01000000000000000000000000000000000000000000000000, 0x00, 0x00, 0x00, 0x00, 0x0100000000000000000000000000000000, 0x0100000000000000000000000000000000, 0x0100000000000000000000000000000000, 0x0100000000000000000000000000000000, 0x00, 0x00, 0x00, 0x00, 0x010000000000000000, 0x010000000000000000, 0x010000000000000000, 0x010000000000000000, 0x00, 0x00, 0x00, 0x00, 0x01, 0x01, 0x01, 0x01, 0x00, 0x00, 0x00, 0x00];
global tail_path_multipliers_chunk1: [Field; 32] = [0x0100000000000000000000000000000000000000000000000000000000, 0x0100000000000000000000000000000000000000000000000000000000, 0x00, 0x00, 0x01000000000000000000000000000000000000000000000000, 0x01000000000000000000000000000000000000000000000000, 0x00, 0x00, 0x010000000000000000000000000000000000000000, 0x010000000000000000000000000000000000000000, 0x00, 0x00, 0x0100000000000000000000000000000000, 0x0100000000000000000000000000000000, 0x00, 0x00, 0x01000000000000000000000000, 0x01000000000000000000000000, 0x00, 0x00, 0x010000000000000000, 0x010000000000000000, 0x00, 0x00, 0x0100000000, 0x0100000000, 0x00, 0x00, 0x01, 0x01, 0x00, 0x00];
global tail_path_multipliers_chunk0: [Field; 32] = [0x01000000000000000000000000000000000000000000000000000000000000, 0x00, 0x0100000000000000000000000000000000000000000000000000000000, 0x00, 0x010000000000000000000000000000000000000000000000000000, 0x00, 0x01000000000000000000000000000000000000000000000000, 0x00, 0x0100000000000000000000000000000000000000000000, 0x00, 0x010000000000000000000000000000000000000000, 0x00, 0x01000000000000000000000000000000000000, 0x00, 0x0100000000000000000000000000000000, 0x00, 0x010000000000000000000000000000, 0x00, 0x01000000000000000000000000, 0x00, 0x0100000000000000000000, 0x00, 0x010000000000000000, 0x00, 0x01000000000000, 0x00, 0x0100000000, 0x00, 0x010000, 0x00, 0x01, 0x00];

unconstrained fn __divmod(numerator: Field, denominator: Field) -> (Field, Field) {
    let quotient = numerator as u16 / denominator as u16;
    let remainder = numerator as u16 % denominator as u16;
    (quotient as Field, remainder as Field)
}

fn divmod(numerator: Field, denominator: Field) -> (Field, Field) {
    // assert(numerator != 0);
    println(f"divmod {numerator}, {denominator}");
    let (quotient, remainder) = __divmod(numerator, denominator);

    let qf = quotient as Field;
    let rf = remainder as Field;

    // note: these range checks are because we know the denominator is 31
    // TODO: need more checks, atm remainder could equal 31
    qf.assert_max_bit_size(14);
    rf.assert_max_bit_size(5);

    // n / d = q
    // d * q + r = n
    assert(qf * denominator as Field + rf == numerator as Field);
    (quotient, remainder)
}

global SliceFieldsNumSlices = 3;
fn slice_fields<let InputFields: u32, let OutputFields: u32>(data: [Field; InputFields], start_byte: u16, num_bytes: u16) -> [Field; OutputFields] {
    let (start_index, start_mod_31) = divmod(start_byte as Field, 31);

    let num_underflow_bytes = start_mod_31;

    let mut num_bytes_in_start_limb = 31 - start_mod_31;
    if (num_bytes as u16 < num_bytes_in_start_limb as u16) {
        num_bytes_in_start_limb = num_bytes as Field;
    }
    let mut num_remaining_bytes = num_bytes as Field - num_bytes_in_start_limb;
    // todo fix
    let bytes_fit_into_limb = (31 - start_mod_31 as u16) >= num_bytes;

    let (num_whole_limbs, num_overflow_bytes) = divmod(num_remaining_bytes, 31);
    let (_, tail) = slice_field(data[start_index], num_underflow_bytes);

    let mut previous = tail;
    // first chunk is tail
    let mut num_whole_limbs = num_whole_limbs as u16; // todo fix

    let mut result = [0; OutputFields];

    let extra_head_section = (num_overflow_bytes as u16 + num_bytes_in_start_limb as u16) > 31;
    num_whole_limbs += extra_head_section as u16;
    // 31, 31, 4
    // 4 overflow bytes. 2 bytes in start limb
    for i in 0..SliceFieldsNumSlices {
        // ok so... we start with a partial limb
        // we then have K number of whole limbs
        let slice_valid = i < num_whole_limbs;
        let data_idx = (start_index + 1 + i as Field) as u16;
        let mut data_index = (start_index + 1 + i as Field);
        let no_data = data_index as u16 >= InputFields as u16;
        data_index *= (1 - no_data as Field);
        let input_slice = data[data_index] * slice_valid as Field * (1 - no_data as Field);
        let mut (head, tail) = slice_field(input_slice, num_underflow_bytes);
        head *= slice_valid as Field;
        tail *= slice_valid as Field;
        let combined = previous * BYTE_SHIFT[num_bytes_in_start_limb] + head;
        result[i] = combined * slice_valid as Field;
        if (slice_valid) {
            previous = tail;
        }
    }
    let index_of_overflow_limb = start_index as u16 + num_whole_limbs + 1 - extra_head_section as u16;

    let (num_bytes_div_31, num_bytes_mod_31) = divmod(num_bytes as Field, 31);
    let perfectly_aligned = (start_mod_31 == 0);

    let num_bytes_mod_31_is_0 = (num_bytes_mod_31 == 0) as Field;
    let index_of_output_limb = num_bytes_div_31 - num_bytes_mod_31_is_0;

    // get index of overflow limb
    if (!bytes_fit_into_limb & extra_head_section) | (bytes_fit_into_limb) {
        let slice_size = (num_bytes as Field + start_mod_31 - num_overflow_bytes) * bytes_fit_into_limb as Field
            + num_overflow_bytes;

        let (head, _) = slice_field(previous, slice_size);

        result[index_of_output_limb] = head * BYTE_SHIFT[num_bytes_mod_31];
    } else {
        let mut (head, _) = slice_field(data[index_of_overflow_limb], num_overflow_bytes);

        let last_limb = (previous * BYTE_SHIFT[31 - num_overflow_bytes] + head) * BYTE_SHIFT[num_bytes_mod_31];

        // let mut last_limb = combined * (1 - perfectly_aligned as Field) + previous * perfectly_aligned as Field;
        // let num_bytes_in_last_limb = num_bytes % 31;
        // last_limb *= BYTE_SHIFT[num_bytes_in_last_limb];
        result[index_of_output_limb] = last_limb;
    }
    // 38 mod 31 = 7
    // limb[1] 7 bytes in
    result
}

// 32 position, 68 bytes
// x[30] = last in 1st limb
// x[31] = 1st in 2nd limb
// x[32] = 2nd in 2nd limb => 30 bytes in start limb = 0x1e
// 38 remaining bytes, 1 whole limb, 7 overflow bytes
// limbs[1] = first partial
// limbs[2] = whole
// limbs[3] = exit
// start = 1 on 30
// whole = 1 on 30

// when computing the whole limb, previous = 30 byte hoohah
// head = 0x6c. (previou * 0x100 + head). we do that
// we cache previous as 0x6420627... etc (30 byte chunk)
// final slice. we have 7 overflow bytes
// 1 byte goes into the previous chunk
// 6 bytes go into the final chunk
// oh. nasty. hmmmmm can we handle in main loop by going an extra iteration and performing a mask?

unconstrained fn build_slices<let N: u32>(bytes: [u8; N], start: u32, num_bytes: u32) -> [Field; 3] {
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
fn test_slice_fields() {
    let text: [u8; 1405] = "Charlie is genius, right. He's made from a million pieces of old bubble gum. Imagine that! In the summer of 1976, on his way home from an Alice Cooper concert, Charlie started to melt onto the pavement. It was too hot in L.A., and he melted like a pink bitch. Luckily though, there was Eric Phillips, a local crocodile who dabbled in black magic. He took pity on Charlie and scraped him off the floor with a pair of fish slicers. He poured him into an antique soup ladle, and boarded his magic carpet. Destination: Alaska! Eric Phillips decided to refreeze Charlie, but in his cold-blooded reptilian haste, he refroze him into to the shape of a Hoover. Charlie wasn't fazed though, he just zoomed about the place, sucking up Inuits. Ha ha! Oh. The Inuits didn't mind; they loved it in Charlie's pink, tight warm belly pouch, and they refused to come out. Charlie said, \"I'm cool with that,\" and set fire to a posh hammer to make it official. he downside was that the Inuits suffocated immediately. It was air-tight in there. Charlie panicked and fired the tiny Inuit bullets into Eric's crocodile peepers. The green shape was frozen. After a quick drink, Charlie stole Eric Phillips's magic carpet and left for Seattle. Charlie was racked with guilt: he'd killed 50 Inuits, noone needs that. He decided to spend the rest of his life putting small hairstyles onto boots, monkey nuts, trumpets and spanners.".as_bytes();
    println(f"text = {text}");
    let mut slices: [Field; 46] = [0; 46];
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
        1,
        5,
        30,
        31,
        37,
        44,
        61,
        62,
        63,
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
            let mut expected_slices: [Field; 3] = build_slices(text, start_byte, num_bytes);
            let result_slices: [Field; 3] = slice_fields(slices, start_byte as u16, num_bytes as u16);
            assert(result_slices == expected_slices);
        }

        for j in 0..18 {
            let start_byte: u32 = text.len() - num_bytes - byte_positions[j];
            let mut expected_slices: [Field; 3] = build_slices(text, start_byte, num_bytes);
            let result_slices: [Field; 3] = slice_fields(slices, start_byte as u16, num_bytes as u16);
            assert(result_slices == expected_slices);
        }
    }
}

fn slice_field(f: Field, num_bytes: Field) -> (Field, Field) {
    let chunks = __slice_field(f, num_bytes);
    chunks[0].assert_max_bit_size(8);
    chunks[1].assert_max_bit_size(16);
    chunks[2].assert_max_bit_size(32);
    chunks[3].assert_max_bit_size(64);
    chunks[4].assert_max_bit_size(128);

    let mut head: Field = 0;
    let mut tail: Field = 0;

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

    tail = chunks[4] * (1 - temp);
    std::as_witness(tail);
    tail += chunks[3] * tail_path_multipliers_chunk3[num_bytes];
    std::as_witness(tail);
    tail += chunks[2] * tail_path_multipliers_chunk2[num_bytes];
    std::as_witness(tail);
    tail += chunks[1] * tail_path_multipliers_chunk1[num_bytes];
    std::as_witness(tail);
    tail += chunks[0] * tail_path_multipliers_chunk0[num_bytes];

    let total = tail + head * BYTE_SHIFT[num_bytes];
    assert(total == f);
    (head, tail)
}

#[test]
fn test_slice_field() {
    let input = 0xffeebbccbbaa99887766554433221100112233445566778899aabbccddeeff;

    let input_bytes: [u8; 32] = input.to_be_bytes(32).as_array();

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

