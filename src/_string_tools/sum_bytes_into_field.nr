/**
 * @file utility function to sum up to 31 bytes from a byte array into a Field,
 *       The location in the byte array and the number of bytes being summed can be abritrary.
 *       Not currently used in noir_json_parse but...is useful algorithm, just lurking here until it's needed...
 **/

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

unconstrained fn get_path(idx: Field) -> [bool; 5] {
    PATH_LOOKUP[idx]
}

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

fn sum_var_bytes_into_field<let N: u32>(
    body_text: [u8; N],
    body_index: Field,
    num_bytes: Field,
) -> Field {
    let path = get_path(num_bytes); // 5 gates
    let path_f: [Field; 5] =
        [path[0] as Field, path[1] as Field, path[2] as Field, path[3] as Field, path[4] as Field];

    assert(
        path_f[0] + path_f[1] * 2 + path_f[2] * 4 + path_f[3] * 8 + path_f[4] * 16
            == num_bytes as Field,
    );

    let mut idx: Field = body_index as Field;

    let mut chunks: [Field; 5] = [0; 5];

    chunks[0] = body_text[idx] as Field;
    idx += path_f[0];

    chunks[1] = body_text[idx] as Field * 0x100 + body_text[idx + 1] as Field;
    idx += path_f[1] * 2;

    chunks[2] = body_text[idx] as Field * 0x1000000
        + body_text[idx + 1] as Field * 0x10000
        + body_text[idx + 2] as Field * 0x100
        + body_text[idx + 3] as Field;
    idx += path_f[2] * 4;

    chunks[3] = body_text[idx] as Field * 0x100000000000000
        + body_text[idx + 1] as Field * 0x1000000000000
        + body_text[idx + 2] as Field * 0x10000000000
        + body_text[idx + 3] as Field * 0x100000000
        + body_text[idx + 4] as Field * 0x1000000
        + body_text[idx + 5] as Field * 0x10000
        + body_text[idx + 6] as Field * 0x100
        + body_text[idx + 7] as Field;
    idx += path_f[3] * 8;

    chunks[4] = body_text[idx] as Field * 0x1000000000000000000000000000000
        + body_text[idx + 1] as Field * 0x1000000000000000000000000000
        + body_text[idx + 2] as Field * 0x100000000000000000000000000
        + body_text[idx + 3] as Field * 0x1000000000000000000000000
        + body_text[idx + 4] as Field * 0x10000000000000000000000
        + body_text[idx + 5] as Field * 0x100000000000000000000
        + body_text[idx + 6] as Field * 0x1000000000000000000
        + body_text[idx + 7] as Field * 0000000000000000
        + body_text[idx + 8] as Field * 0x100000000000000
        + body_text[idx + 9] as Field * 0x100000000000
        + body_text[idx + 10] as Field * 0x10000000000
        + body_text[idx + 11] as Field * 0x100000000
        + body_text[idx + 12] as Field * 0x1000000
        + body_text[idx + 13] as Field * 0x10000
        + body_text[idx + 14] as Field * 0x100
        + body_text[idx + 15] as Field;

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
