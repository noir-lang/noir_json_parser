pub(crate) mod _table_generation;
mod enums;
mod json;
mod json_tables;
mod keymap;
mod json_entry;
mod transcript_entry;
pub(crate) mod _string_tools;
pub(crate) mod _comparison_tools;
mod token_flags;
mod getters;
mod keyhash;
mod get_string;
mod get_number;
mod get_literal;
mod get_object;
mod get_array;
mod utils;
mod benchmarks;

use json::JSON;

pub type JSON512b = JSON<512, 20, 64, 33, 2>;
pub type JSON1kb = JSON<1024, 37, 128, 65, 2>;
pub type JSON2kb = JSON<2048, 70, 256, 129, 2>;
pub type JSON4kb = JSON<4096, 136, 512, 257, 2>;
pub type JSON8kb = JSON<8192, 268, 1024, 513, 2>;
pub type JSON16kb = JSON<16384, 532, 2048, 1025, 2>;
