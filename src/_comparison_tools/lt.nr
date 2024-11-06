/**
 * @file helper methods that evaluate comparison operations on Field elements that are known to be of a fixed size (e.g. <2^16)
 **/
pub unconstrained fn get_lt_predicate_f(x: Field, y: Field) -> bool {
    let a = x as u32;
    let b = y as u32;
    let r = a < b;
    r
}

pub unconstrained fn get_lte_predicate_large(x: Field, y: Field) -> bool {
    let r = x.lt(y) | (x == y);
    r
}

pub fn lte_field_240_bit(x: Field, y: Field) -> bool {
    let predicate = get_lte_predicate_large(x, y);
    let delta = y as Field - x as Field;

    // (x - y) * predicate
    // if true, y - x >= 0
    // if false, x <= y is wrong therefore x > y => x - y > 0 => x - y + 1 >= 0
    // (y - x) * p + (1 - p) * (x - y + 1)
    // (y - x) * p + x - y + 1 + p * (y - x)
    let lt_parameter = 2 * (predicate as Field) * delta - predicate as Field - delta + 1;
    lt_parameter.assert_max_bit_size::<240>();

    predicate
}

pub fn assert_lte_240_bit(x: Field, y: Field) {
    let delta = y as Field - x as Field;

    // (x - y) * predicate
    // if true, y - x >= 0
    // if false, x <= y is wrong therefore x > y => x - y > 0 => x - y + 1 >= 0
    // (y - x) * p + (1 - p) * (x - y + 1)
    // (y - x) * p + x - y + 1 + p * (y - x)
    delta.assert_max_bit_size::<240>();
}

pub fn lt_field_16_bit(x: Field, y: Field) -> bool {
    let predicate = get_lt_predicate_f(x, y);
    let delta = y as Field - x as Field;
    let lt_parameter = 2 * (predicate as Field) * delta - predicate as Field - delta;
    lt_parameter.assert_max_bit_size::<16>();

    predicate
}

pub fn lt_field_8_bit(x: Field, y: Field) -> bool {
    let predicate = get_lt_predicate_f(x, y);
    let delta = y as Field - x as Field;
    let lt_parameter = 2 * (predicate as Field) * delta - predicate as Field - delta;
    lt_parameter.assert_max_bit_size::<8>();

    predicate
}

pub fn assert_gt_240_bit(lhs: Field, rhs: Field) {
    // lhs > rhs
    // -> lhs - rhs > 0
    // -> lhs - rhs - 1 >= 0
    let diff = lhs - rhs - 1;
    diff.assert_max_bit_size::<240>();
}

pub fn assert_lt_240_bit(lhs: Field, rhs: Field) {
    // lhs < rhs
    // -> rhs - lhs > 0
    // -> rhs - lhs - 1 >= 0
    let diff = rhs - lhs - 1;
    diff.assert_max_bit_size::<240>();
}
