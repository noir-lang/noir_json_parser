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
mod make_tables;
mod redux;
mod redux_tables;
mod lt;
mod keymap;
mod json_entry;
mod transcript_entry;
mod token_flags;
mod test_data;
mod getters;
mod keyhash;
mod slice_field;
use crate::redux::JSON;
use crate::slice_field::{slice_fields, slice_field};
use crate::keyhash::{Hasher, slice_200_bits_from_field, get_keyhash_chunky, sum_var_bytes_into_field};
use crate::lt::lt_field_16_bit;
global LEN = 10000;
unconstrained fn preamble(_json: JSON<1024, 64, 37, 37>) -> JSON<1024, 64, 37, 37> {
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

// fn main(bytes: [u8; 1024]) {
//     let mut json = JSON {
//         json: bytes,
//         transcript: [0; 64],
//         transcript_length: 0,
//         key_data: [0; 64],
//         key_hashes: [0; 64],
//         layer_id: 0,
//         layer_context: 0,
//         layer_index_in_transcript: 0,
//         packed_json_entries: [0; 64],
//         packed_json: [0; 37]
//     };
//     json.compute_packed_json();
//     // 1333
//     // 1828
//     // cost = 495
//     // makes sense
//     for i in 0..37 {
//         let kk = json.packed_json_entries[i];
//         println(f"{kk}");
//     }
//     // json.compute_packed_json();
//     // for i in 0..37 {
//     //     let kk = json.packed_json_entries[i];
//     //     println(f"{kk}");
//     // }
// }
// 27060
// 24895
// wot were back to 217?
// hmm something weird here
fn mainslice(foo: [Field; 100], bar: [u8; 1000], num_bytes: [u16; 100], start_bytes: [u16; 100]) {
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

    // 2 fields
    // 99 = 23571
    // 89 = 21759
    // delta = 241 + 1571 = 1812
    // 181.2
    // 21848

    // 22115
    // 23967

    // 9535 99 (slice field)
    // 9082 89
    // diff 44.3

    // 21848
    // 23670
    // 1822 diff = 182

    // 21492
    // 23274
    // diff = 178.2

    // CURRENT VALUE OF SLICE_FIELDS IS 182 GATES 26 AUGUST
    for i in 0..89 {
        let x: [Field; 2] = slice_fields(foo, start_bytes[i] as Field, num_bytes[i] as Field);
        // let x = slice_field(foo[i], start_bytes[i] as Field);
        println(f"{x}");
        //  assert(x[0] == x[1]);
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
fn main_chunky(body_text: [u8; 1024], body_indices: [u16; 64], key_lengths: [u16; 64], dd: Field) {
    println(f"{body_text} {body_indices} {key_lengths}");
    let kk = slice_200_bits_from_field(dd);
    println(f"{kk}");
    for i in 0..64 {
        let x = get_keyhash_chunky(body_text, body_indices[i], key_lengths[i]);
        println(f"{x}");
    }
}

fn mainget_keyhash(body_text: [u8; 1024], body_indices: [u16; 64], key_lengths: [u16; 64], dd: Field) {
    println(f"{body_text} {body_indices} {key_lengths}");
    let kk = slice_200_bits_from_field(dd);
    let mut json = JSON {
        json: body_text,
        raw_transcript: [0; 64],
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

    let hasher: Hasher<2> = Hasher {};
    // iteration from 64 = 26,902
    // iteration from 54 = 23,623
    // delta = 3,279
    // cost per iteration = 328

    // old chunky = 35316 for 64, 31027 for 54
    // delta = 3973 + 316 = 4,289
    // cost per it = 428
    // hmm

    // lets see poseidon cost
    // 34 iterations = 7410
    // 24 iterations = 6638
    // delta = 410 + 362 = 782
    // per it = 78.2 

    // ok what is get_keyhash without the hash
    // 64 its = 21973
    // 54 its = 19464
    // delta = 536 + 1973 = 2200 + 109 = 2509
    // cost  w/o hash = 251
    // cost with hash  = 328
    // hash cost = 49 + 28 = 77 good job
    // ok why is cost 251
    // slice field = 182

    // pure slice. 64 its = 20213
    //             54 its = 17979
    // delta = 2,234 = 223?

    // 54 iterations now 17871
    // 64 iterations 20852
    // cost = 2214
    // delta = 221
    // 64 iterations 20,211
    // 54 iterations 17,997
    // cost 2214 = 221 blah
    // OK THIS WAS FOR KEY LENGTH 3

    // 18148
    // 16256
    // delta 1892 = 189.2 ok better

    // ok full fandango:  64 = 24,388
    //                    54 = 21,521
    // delta = 2,867 = 287 gates per keyhash. ouch.

    // GET KEYHASH COST FOR 2 LIMBS SHOULD BE 287 287 287 287 2872
    // 287 gates
    // ~80 for poseidon2
    // ~190 for slice
    // ~17 for 200 bit chunk

    // equivalent using byte slices (62 byte max)
    // 35741
    // 40880
    // 5139 = 514 gates, 1.8x slower
    println(f"{kk}");
    for i in 1..64 {
        assert(body_indices[i] == body_indices[i - 1]);
        assert(key_lengths[i] == key_lengths[i - 1]);
        //   println(f"{a}, {b}");
    }
    for i in 0..64 {
        //   let key_fields = [json.packed_json[i], json.packed_json[i + 1], json.packed_json[i + 2]];
        //   let x = dep::std::hash::poseidon2::Poseidon2::hash(key_fields, 3);
        //let x = hasher.get_keyhash(json.packed_json, body_indices[i], key_lengths[i]);

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

// 1,024 parse 48,948 without sorting and keyhash (ow)
//             74,873 compute keyhash (25,925 for keyhashes)
//             126,141 after sorting wtf

// 287 * 64 = 18,368 = what cost of keyhash should be
// where is extra 7,557 coming from?
// we need to turn packed_json into ROM array (120-160 tops)
// about 300 lookup table entries in slice fields (1200 tops)
// ???

// 48,948 to 55,091 for ONE keyhash
// 5,091

// ok new

// empty: 1332
// build_transcript: 21332
// + capture_missing_tokens: 24233
// + keyswap: 33605 (9k?)
// + create_json_entries: 53989 (20k?)
// + keyhash: 74936 (20,947. assuming 2k init for tables and crap (a lot), about 296 gates per hash)
// + sort: 123,820 . ok this needs a lot of tender love and care

/*
    CREATE_JSON_ENTRIES....
    each iteration should be about 90 gates
    which would cost 5,760
    but actual cost is 20,384
*/

// 53,989
// 49,723
// delta = 4266 = 426 per iteration

// 40074 411791, 1105 delta = 110 hmm hmm writes pain?
// 48948 45802, 3146 = 314 just for context stack?
// 53,989
// 51,154
// 34,100
// 42,001
// delta = 8k which is much better!
// 34,100 vs 41,876 = 7,776

// 1 entry = 34,218
// 64 = 41,876 = 7,65
// still 121 gates per entry
// 40093 vs 41876
// looks like copying arrays is incurring a cost??
fn main(text: str<1024>) {
    // let strbytes = text.as_bytes();
    // let mut inputs: [Field; 13] = [0; 13];
    // for j in 0..13 {
    //     let mut input: Field = 0;
    //     for i in 0..31 {
    //         input += text.as_bytes()[j * 31 + i] as Field;
    //     }
    //     inputs[j] = input;
    // }
    // inputs[0].assert_max_bit_size(1);
    // inputs[1].assert_max_bit_size(2);
    // inputs[2].assert_max_bit_size(3);
    // inputs[3].assert_max_bit_size(4);
    // inputs[4].assert_max_bit_size(5);
    // inputs[5].assert_max_bit_size(6);
    // inputs[6].assert_max_bit_size(7);
    // inputs[7].assert_max_bit_size(8);
    // inputs[8].assert_max_bit_size(0);
    // inputs[9].assert_max_bit_size(10);
    // inputs[10].assert_max_bit_size(11);
    // inputs[11].assert_max_bit_size(12);
    // inputs[12].assert_max_bit_size(13);
    // inputs[13].assert_max_bit_size(14);

    // let sliced: [Field; 2] = slice_fields(inputs, strbytes[5] as u16, strbytes[200] as u16);
    // assert(sliced[0] == sliced[1]);
    let mut json = JSON {
        json: text.as_bytes(),
        raw_transcript: [0; 64],
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
    let mut json = json.build_transcript(); // 16,824
    // let x = json.transcript[0];
    // println(f"{x}");
    json.capture_missing_tokens(); // 23,604 // 7k?
    json.keyswap(); // 24,341
    json.compute_packed_json(); // 24,836
    json.create_json_entries(); // 29,603
    json.compute_keyhash_and_sort_json_entries(); // 55,853
    // // assert(json.packed_json[inputs[3]] == 1234);
    // for i in 0..63 {
    //     assert(json.key_data[i] == json.key_data[i + 1]);
    // }
    //  let keymap::KeyIndexData{ json_index, json_length, parent_id, array_index } = keymap::KeyIndexData::from_field(json.key_data[0]);
    // assert(json_index == json_length);
    // assert(parent_id == array_index);
    // 62578
    // 51810 57908
    // 51889 57911
    // delta of 6,098 even after initing range tables
    // delta of 6,022 after casting json to rom table first
    // 58093 53041
    // still 5k even after initializing all fo the slice_fields tables!
    // 58119, 57807
    // delta = 193 + 119 = 312 gates
    // ok it's json.key_data that is the problem?
    // 58082 58394
    // 55359 53989
    // 1,370 for 1st which makes sense because of all the tables. hmm
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
