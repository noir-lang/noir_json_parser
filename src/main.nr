/*
enum JsonTranscript {
    OBJECT_START,
    OBJECT_END,
    ARRAY_START,
    ARRAY_END,
    KEY_CAPTURE
    STRING_CAPTURE,
    NUMERIC_CAPTURE,
    BOOL_CAPTURE
}
*/
mod redux;
mod redux_tables;
mod lt;
mod keymap;
mod json_entry;
mod transcript_entry;
mod test_data;
mod getters;
mod keyhash;
mod slice_field;
use crate::redux::JSON;
use crate::slice_field::{slice_fields, slice_field};
use crate::keyhash::{slice_200_bits_from_field, get_keyhash_chunky, sum_var_bytes_into_field};
use crate::lt::lt_field_16_bit;
global LEN = 10000;
unconstrained fn preamble(_json: JSON<1024, 64, 37>) -> JSON<1024, 64, 37> {
    let mut json = _json.build_transcript();
    let x = json.transcript[0];
    println(f"{x}");
    json.capture_missing_tokens();
    json.keyswap();
    json.create_json_entries();
    json
}
// 38994
// 10002

// or 57,527

// 78,185
// vs 48,453
// 30,032 for compute_keyhash and sort entries with the sorting commented out??
// 469 per element? does not compute

// 30,548 for 64 iterations REDUCED TO 29,863
// 30,197 for 63 iteration REDUCED TO 29,512
// weird thing is this adds 800
// = 351 per iteration\
// without the 200 bit slice method:
// 24,514 for 64 iterations
// 24,246 for 63 iterations
// 268 per iteration

// -> 200 bit slice method = 83 gates
// 200 bits = 15 slices = 5 gates + 3.75 = 8.75 gates
// 54 bits = 4 slices = 3 gates
// 200 * 2 + 54 * 2 = 17.5 + 6 = 23.5 gates
// 1st assert = 1 gate
// lo_diff = 1 gate
// hi_diff = 1 gate
// should be 26.5 gates
// 5656 for 99 (slice field)
// 5671 for 100 (slice field)
// diff = 15? that can't be right
// wo range check 128. 5012 vs 5021 = 9

// slice limbs
// 99 = 37955
// 100 = 38283
// delta = 283 + 45 = 328 lol fuck

// size 1 slice limbs
// 99 = 28303
// 100 = 28533
// delta = 230 man painful

// size 2
// 99 = 33227
// 100 = 33508
// delta = 285 pain

// size 5 slice limbs
// 99 =  48103
// 100 = 48533
// delta = 430

// 607
// 601 6
// 595 6
// 589  6

// 645
// 640

// 606
// 600

// 6006
// 5145
// 150?
global TEST1: [Field; 35] = [
0x000000000, // 0 0 0 0 0 0 0 0 0
0x000000001, // 0 0 0 0 0 0 0 0 1
0x000000002, // 0 0 0 0 0 0 0 1 0
0x000000004, // 0 0 0 0 0 0 1 0 0
0x000000008, // 0 0 0 0 0 1 0 0 0
0x000000010, // 0 0 0 0 1 0 0 0 0
0x000000020, // 0 0 0 1 0 0 0 0 0
0x000000040, // 0 0 1 0 0 0 0 0 0
0x000000080, // 0 1 0 0 0 0 0 0 0
0x000000100, // 1 0 0 0 0 0 0 0 0
0x000000000, // 0 0 0 0 0 0 0 0 0
0x000000001, // 0 0 0 0 0 0 0 0 1
0x000000002, // 0 0 0 0 0 0 0 1 0
0x000000004, // 0 0 0 0 0 0 1 0 0
0x000000008, // 0 0 0 0 0 1 0 0 0
0x000000010, // 0 0 0 0 1 0 0 0 0
0x000000020, // 0 0 0 1 0 0 0 0 0
0x000000040, // 0 0 1 0 0 0 0 0 0
0x000000080, // 0 1 0 0 0 0 0 0 0
0x000000100, // 1 0 0 0 0 0 0 0 0
0x000000000, // 0 0 0 0 0 0 0 0 0
0x000000001, // 0 0 0 0 0 0 0 0 1
0x000000002, // 0 0 0 0 0 0 0 1 0
0x000000004, // 0 0 0 0 0 0 1 0 0
0x000000008, // 0 0 0 0 0 1 0 0 0
0x000000010, // 0 0 0 0 1 0 0 0 0
0x000000020, // 0 0 0 1 0 0 0 0 0
0x000000040, // 0 0 1 0 0 0 0 0 0
0x000000080, // 0 1 0 0 0 0 0 0 0
0x000000100, // 1 0 0 0 0 0 0 0 0
0x000000010, // 0 0 0 0 1 0 0 0 0
0x000000020, // 0 0 0 1 0 0 0 0 0
0x000000040, // 0 0 1 0 0 0 0 0 0
0x000000080, // 0 1 0 0 0 0 0 0 0
0x000000100, // 1 0 0 0 0 0 0 0 0
];

global FOO: [Field; 4] = [0, 1, 2, 3];
fn maiff(p: Field) {
    // let k = LAST_LIMB_PATH[p[0]];
    // println(f"{k}");
    // let q = TEST1[p[0]];
    // println(f"{q}"); // 47
    // let k = LAST_LIMB_PATH[lhs[0]];
    // println(f"{k}");
    // let k = FOO[p];
    // println(f"{k}");
    // let k = LAST_LIMB_PATH[p];
    //  let k: [Field; 2] = get_last_limb_path(p);
    //  println(f"{k}");
    // reading array = 147 gates
    // get_last_limb_path =150 gates
    // init = 145 - 8 = 137
    // 35 * 3 = 105 . + 32?
    // 35 range check...
    // 6 bit = 64 / 3 values = 22 values
    // 4 3 3 3 3 3 3 - = 8 gates padding * 2 = 16 gates padding
    // hmm hmm hmm hmm
    // OK so we save 1 gate per call to keyfind.
    // We have 64 keys max per 1kb json = save 64. cost is quite a bit higher. blah
    // we save 3? gates if key len is 3 fields
    // 8 -> 17 = 9 gates
    // 4 gates to make
    // 2 gates to read
    // 17 gates = 2 9 gates init
    // 20 gate = size 3 12 gates init
    // 23 gates = size 4 hmm? 15 gates init
    // 3 gates + (3 * size) boo
    // 35 * 3 = 105 + 3 = 108 + 8 = 116 + 5 = 121
    // cost = 140 gates
    // where are the 3 gates coming from?
    // 122 -> 220 = 100. why not 70?
    // for i in 0..1 {
    //     let k0: Field = (i as Field == p[i]) as Field;
    //     let k1 = (i as Field == lhs[i]) as Field;
    //     println(f"{k0}{k1}");
    //     //let k: [Field; 2] = get_last_limb_path(p[i]);
    //     //  println(f"{k}");
    //     // let is_last = (i as Field == p[i]) as Field; // 3 gates
    //     // let new = (rhs[i] - lhs[i]) * is_last + lhs[i]; // 2 gates
    //     // assert(new == r[i]); // 1 gate
    // }
}

fn main(bytes: [u8; 1024]) {
    let mut json = JSON {
        json: bytes,
        transcript: [0; 64],
        transcript_length: 0,
        key_data: [0; 64],
        key_hashes: [0; 64],
        layer_id: 0,
        layer_context: 0,
        layer_index_in_transcript: 0,
        packed_json_entries: [0; 64],
        packed_json: [0; 37]
    };

    json.compute_packed_json();

    for i in 0..37 {
        let kk = json.packed_json_entries[i];
        println(f"{kk}");
    }
    json.compute_packed_json();
    for i in 0..37 {
        let kk = json.packed_json_entries[i];
        println(f"{kk}");
    }
}
// hmm something weird here
fn mainjj(foo: [Field; 100], bar: [u8; 1000], num_bytes: [u16; 100], start_bytes: [u16; 100]) {
    // 3,621 for 100
    // 3,613 for 99 = 8 which is expected
    // 54 bits

    // 3,726 for 100
    // 3,723 for 99 = 3 gates = expected

    // slice 200 bits
    // 100 = 6181
    // 99  = 6154
    // 27 gates ok expected
    // so something squiffy is happening
    // aaaah the cost of an extr arange table was glomming things

    // 5,871
    // 28600 28055 26669 24689 24540
    // 28833 28283 26883 24883 24733

    // current 27834 with path valid via lookups
    // now 27184 without "no data" (via field padding)
    // and 26987 after tweaking with path stuff
    // and 26837 after removing u16 cast

    // more lookup messiness 28700 vs 28471 = 229 erm regression?
    // ok fixed. 24997 vs 24805 = 192? wow? 

    // 25349 vs 25153 = 150 + 46 = 196 hmmmm
    // 24749 vs 24559 = 190 lol a bit better
    // 23767 vs 23949 = 140 + 42 = 182
    //            23569 = 178
    // 45 * 3 = 135 => extra = 55 gates hmm

    // 26987 vs 26773 delta = 214
    // 26900 vs 26687 delta = 213?
    // 26837 vs 26624 delta = 213? hmm
    // hmm 
    // 27433 if we can remove no data
    // 26483 if we can remove slice_valid somehow = 10 gates hmm hmm
    // 233 hmmmmm this beats original version
    // 228
    // 214
    // 194 (we need to remove that damn write-at-arb-index)
    // 193
    // 45 * 3 = 135

    // num_whole_limbs => path for slice valid
    // 0 = 0 0 0 0 0
    // 1 = 0 0 0 0 1
    // 2 = 0 0 0 1 1
    // 3 = 0 0 1 1 1
    // etc etc
    // nice! let's do that!

    // e.g. if outputfields = 2
    // 3 gates to sort out
    // 2 gates to read
    // 5 gates total
    // 1: 18499 18630 -> 131
    // how to remove arb index
    // say we compute idx of final limb
    // we say if (i == idx) set value we write to last limb
    for i in 0..99 {
        let x: [Field; 2] = slice_fields(foo, start_bytes[i], num_bytes[i]);
        println(f"{x}");
        //    assert(x.0 == x.1);
    }
    // for i in 0..99 {
    //     let x = sum_var_bytes_into_field(bar, 10, 10);
    //     println(f"{x}");
    // }
}
// 27983
// 27759
// 224
// vs
// 27883
// 27659
// 224
// wat?
// 10,285 (10,087)
// 10,344 (10,144)
// diff = 44 + 15 = 59 (diff = 57)
// maybe 58 gates all in?
fn mainddddold(foo: [Field; 100], bar: [u8; 1000], num_bytes: [u16; 100]) {
    // 3,621 for 100
    // 3,613 for 99 = 8 which is expected
    println(f"{bar}");
    // 54 bits

    // 3,726 for 100
    // 3,723 for 99 = 3 gates = expected

    // slice 200 bits
    // 100 = 6181
    // 99  = 6154
    // 27 gates ok expected
    // so something squiffy is happening
    // aaaah the cost of an extr arange table was glomming things

    // 5,871

    for i in 0..100 {
        let x = slice_field(foo[i], num_bytes[i] as Field);
        println(f"{x}");
        //    assert(x.0 == x.1);
    }
    // for i in 0..99 {
    //     let x = sum_var_bytes_into_field(bar, 10, 10);
    //     println(f"{x}");
    // }
}
// without slice 200 bits: 24,246. 24,259 wtf
// with slice 200 bits: 29,512 (63 iterations) 29.520
// this does not align with existing foobar
// 24,279 vs 29.539
// w/o range checks its 27,902 still crazy
// 27965 with fn shell
// ok something squiffy was getting masked away - constraining the input adds the gates

// 63 = 10953
// 64 = 11010
// diff = 57

// 63 = 12590
// 64 = 12674
// diff = 84 ? for 64 byte eh oh most commented out

// 34392
// 34821
// 429 per key painful (poseidon hash is squiffy though)
fn mainkkkk(body_text: [u8; 1024], body_indices: [u16; 64], key_lengths: [u16; 64], dd: Field) {
    println(f"{body_text} {body_indices} {key_lengths}");
    let kk = slice_200_bits_from_field(dd);
    println(f"{kk}");
    for i in 0..64 {
        let x = get_keyhash_chunky(body_text, body_indices[i], key_lengths[i]);
        println(f"{x}");
    }
}

// sum_var_bytes_into_field 63 iterations: 15016
// sum_var_bytes_into_field 64 iterations: 15138
// cost per iteration = 84 + 38 = 122 wtf mate

/*
 31 lookups = 62
 15 + 7 + 3 + 1 idx computations = 26
 chunks[1] sum = 1
 chunks[2] sum = 2
 chunks[3] sum = 4
 chunks[4] sum = 8
 update idx = 4
 mask chunks using path flag = 5
 update multiplicand = 4
 add gates for sum = 5
total = 88 + 15 + 18 = 88 + 33 = 121
ok...erm blah

we currently call this twice = 242 * 64 = 15,488 fuck me

OK WHAT ABOUT PLAN B

AS WE PARSE THE JSON WE SPLIT IT INTO 10 BYTE CHUNKS

to get our key we need to do the following:

num chunks = ceil(maxbytes / 10) + 1 ? 
e.g. 99 bytes. 1 byte in one limb, 98 bytes across 10 limbs

there is a first split and a last split
1. get split index
2. convert slice into low/high bytes. sum useful bytes
even better. for partial chunks we use the algorithm we already have to sum

cons: we need to dive into 2 limbs instead of 1

costs: 0.5 gates per json byte to compute limb sums
        plus (json_bytes / limb_size) * 2 to store

what about we do the following:

we store 16 byte slices
we store 8 byte slices

Bytes * (6 / 16) cost

we then do the following
we select K 16 byte limbs
we select 2 8 byte limbs
we select 2 split indices and split lengths

ok we imagine what to do just with 8 byte limbs
starting limb index = start_idx / 8 + (start_idx % 8 != 0) ew
(keylen + start_idx) / 8 - (start_idx / 8) = number of whole limbs
num_overspill bytes = (keylen + start_idx) % 8
num_underspill bytes = start_idx % 8

underspill index = start_idx - limb_index * 8
overspill = (limb_index + whole_limbs) * 8

the cost of this nonsense will be:

start_idx . divmod 8...
quotient, remainder both range checked 1.25 gates * 2 = 2.5 gates
quotient * 8 + remainder = start_idx = 1 gate
(keylen + start_idx) divmod 8 = 3.5 gates
num whole limbs = 1 gate
num overspill bytes = 0
num underspill bytes = 0
underspill index = 1
overspill index = 1
start_idx % 8 != 0 ... 2 gates minimum (can use lookup table)
compute limb index = 1

total 13 gates minimum

we then need to assemble the limbs. we can probably do this 4 gates per limb just like we assemble bytes
minor difficulty as we straddle 31 byte limb boundaries

13 gates to split across limbs * 2 = 26 gates

q * 8 + r - X = 0 yea 3.5 gates

num spillover bytes at start = 7 max
num spillover bytes at end = 7 max

// 4 2 1
// 14 vs 31 = 2.1x = 58 gates = 63 spare. 13 gates for the computations. 4 limbs... hmm

// I think we should try this. as it scales much better for larger keys
*/
// 63 15,016 to 12,181 when removing the 16-sum = 2,835 gates / 63 = 45 gates
// 16 reads = 32 gates
// 15 index updates = 15 gates
// adding 16 doodads into a sum = 8 gates
// = 55 gates
// huh?
// removing all chunks[4] gives 11,362 
/* 
expectations:
// 31 lookups
// 30 index computations
// 

// chunks 3 removal cuts from 12,181 to 9,850
// 2,331 / 64 = 36.25?

// chunks 2 removal cuts from 9.850 to 8.779 = 221 + 850 = 1,071 / 63 = 17

// chunks 1 removal cuts from 8.779 to 8.275 = 504 / 63 = 8
*/
// 63: 8275
// 64: 8290
fn mainkjghg(body_text: [u8; 1024], body_indices: [u16; 64], key_lengths: [u16; 64], dd: Field) {
    println(f"{body_text} {body_indices} {key_lengths}");
    let kk = slice_200_bits_from_field(dd);
    println(f"{kk}");
    for i in 0..64 {
        let x = sum_var_bytes_into_field(body_text, body_indices[i] as Field, key_lengths[i] as Field);
        //   let x = get_keyhash_chunky(body_text, body_indices[i], key_lengths[i]);
        println(f"{x}");
    }
}

fn maink(text: str<1024>) {
    let mut json = JSON {
        json: text.as_bytes(),
        transcript: [0; 64],
        transcript_length: 0,
        key_data: [0; 64],
        key_hashes: [0; 64],
        layer_id: 0,
        layer_context: 0,
        layer_index_in_transcript: 0,
        packed_json_entries: [0; 64],
        packed_json: [0; 37]
    };
    // json = preamble(json);
    let mut json = json.build_transcript();
    let x = json.transcript[0];
    println(f"{x}");
    json.capture_missing_tokens();
    json.keyswap();
    json.create_json_entries();
    // json.compute_keyhash_and_sort_json_entries();
    // let x = json.get_number_unchecked("hello".as_bytes(), 5);
    // println(f"{x}");
}

// 1000 = 56053
// 1001 = 56109

// 8311
// 8303
// 5 bytes = 8? ow
// to radix is worse. man
// expected 
// delta = 56 gates meh not good not the cause of woes
// I expected it to be 11 + 8 = 19 gates
global NB = 5;
global NI = 1000;
fn mainw(k: [Field; NI]) {
    for i in 0..NI {
        let z = k[i].to_be_radix(16, NB);
        println(f"{z}");
    }
}
// 87741
fn main3(x: [u16; LEN], y: [u16; LEN], z: [bool; LEN]) {
    for i in 0..LEN {
        if (z[i]) {
            assert(x[i] < y[i]);
        }
        // assert(lt_field_16_bit(x[i] as Field, y[i] as Field));
    }
}

fn main2(x: [u16; LEN], y: [u16; LEN], z: [bool; LEN]) {
    for i in 0..LEN {
        assert(x[i] <= y[i]);
    }
}
