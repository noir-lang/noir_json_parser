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

use crate::lt::lt_field_16_bit;
global LEN = 10000;
// 87741
fn main(x: [u16; LEN], y: [u16; LEN], z: [bool; LEN]) {
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
