/*

when iterating from 0 to N, validate i < M efficiently
we have an array of flags that describe whether entry is valid
flags start at 1 and at 0 more or less

we check:
1. flag starts at 0 or 1
2. flag transition cannot be 0 -> 1 i.e. new_flag * (1 - old_flag) == 0
3. flag ends at 0 or 1

the above validates that only one transition point occurs
we still need to test the transition point

transition happens when we get 1 -> 0 i.e. tx = i * (old_flag * (1 - new_flag))
in this case, i == M

// o * (1 - n) = o - on
// n * (1 - o) = n - on
// i*(o - on) * (1/i) - o + n
*/

/**
 * @brief helper method that provides an array of Field elements `flags`, where `flags[i] = i < boundary`
 * @description this method is cheaper than querying `i < boundary` for `u16` and `u32` types
 *              cost = 3 gates + 2 gates per iteration 
 **/
pub fn get_validity_flags<let N: u32>(boundary: u32) -> [Field; N] {
    //@Safety: The constraining is happening inside get_validity_flags_inner
    let flags: [Field; N] = unsafe { __get_validity_flags(boundary) };
    get_validity_flags_inner(boundary, flags)
}

unconstrained fn __get_validity_flags<let N: u32>(boundary: u32) -> [Field; N] {
    let mut result: [Field; N] = [0; N];
    for i in 0..N {
        if i < boundary {
            result[i] = 1;
        }
    }
    result
}

/**
 * @brief implementation of `get_validity_flags`
 * @description Given an array of `flags`, we apply the following checks to build an inductive proof about the validity of the flags array:
 *              1. the first element `flags[0]` is in the range [0,1]
 *              2. the last element `flags[N-1]` is in the range [0,1]
 *              3. for any two flags `old, new` where `old = flags[i-1], new = flags[i]` and `i>0, i <N`, we validate the following:
 *                  a. if `old` is 0, `new` *cannot* equal 1
 *                  b. if `old` is 1 and `new` is 0, set `transition_index = i`
 *  The value of `transition_index` will equal the value `i` where `i = boundary` (or `N` if `boundary > N`)
 *              4. we finally validate `transition_index == boundary` to prove the location where `flags[i-1] = 1` and `flags[i] = 0`
 *                 aligns with what is expected from testing `i < boundary`
 *  N.B. this method will revert if `boundary > N`
 **/
fn get_validity_flags_inner<let N: u32>(boundary: u32, flags: [Field; N]) -> [Field; N] {
    let initial_flag = flags[0];
    let final_flag = flags[N - 1];

    // check first and last flags are in the range [0, 1]
    assert(initial_flag * initial_flag == initial_flag);
    assert(final_flag * final_flag == final_flag);

    let mut transition_index = 0;

    for i in 1..N {
        let old_flag = flags[i - 1];
        let new_flag = flags[i];
        assert(new_flag == old_flag * new_flag);

        // old = a, new = b
        let idx = (old_flag * (1 - new_flag)) * (i as Field);
        transition_index = transition_index + idx;
        std::as_witness(transition_index);
    }

    assert(transition_index == boundary as Field);
    flags
}

#[test]
fn test_get_validity_flags() {
    for i in 0..32 {
        let flags: [Field; 32] = get_validity_flags(i);
        for j in 0..32 {
            assert(flags[j] == (j < i) as Field);
        }
    }
}

#[test(should_fail)]
fn test_get_validity_flags_fail() {
    let _: [Field; 33] = get_validity_flags(33);
}

#[test(should_fail)]
fn test_get_validity_flags_bad_index_fail_a() {
    let bad_flags: [Field; 10] = [1, 1, 1, 0, 0, 0, 1, 0, 0, 0];
    let _ = get_validity_flags_inner(3, bad_flags);
}
#[test(should_fail)]
fn test_get_validity_flags_bad_index_fail_b() {
    let bad_flags: [Field; 10] = [1, 1, 1, 1, 0, 0, 0, 0, 0, 0];
    let _ = get_validity_flags_inner(3, bad_flags);
}

#[test(should_fail)]
fn test_get_validity_flags_bad_index_fail_c() {
    let bad_flags: [Field; 10] = [1, 1, 0, 0, 0, 0, 0, 0, 0, 0];
    let _ = get_validity_flags_inner(3, bad_flags);
}

#[test]
fn test_get_validity_flags_good_index_d() {
    let bad_flags: [Field; 10] = [1, 1, 1, 0, 0, 0, 0, 0, 0, 0];
    let _ = get_validity_flags_inner(3, bad_flags);
}

#[test(should_fail)]
fn test_get_validity_flags_bad_index_fail_e() {
    let bad_flags: [Field; 10] = [1, 1, 1, 1, 1, 1, 1, 1, 1, 1];
    let _ = get_validity_flags_inner(11, bad_flags);
}

// this test uses bad flags but manipulates transition_index to be satisfiable
// nevertheless test will fail because our transition test (old * new = new) will fail
#[test(should_fail)]
fn test_get_validity_flags_bad_index_fail_f() {
    let mut bad_flags: [Field; 10] = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0];

    let fake_index_a = 2;
    let fake_value_a = 100;

    let fake_index_b = 4;
    // 4 * Y = -2 * X
    let fake_value_b = (-fake_value_a * fake_index_a) / fake_index_b;

    bad_flags[fake_index_a] = fake_value_a;
    bad_flags[fake_index_b] = fake_value_b;
    let _ = get_validity_flags_inner(0, bad_flags);
}
