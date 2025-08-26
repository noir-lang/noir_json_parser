//! Contains methods used to generate tables in `json_tables.nr`. These table generation methods shouldn't be used inside of actual circuits.
use crate::enums::CaptureMode::STRING_CAPTURE;
use crate::enums::Layer::{ARRAY_LAYER, OBJECT_LAYER};
use crate::enums::Token::{
    BEGIN_ARRAY_TOKEN, BEGIN_OBJECT_TOKEN, END_ARRAY_TOKEN, END_OBJECT_TOKEN, KEY_SEPARATOR_TOKEN,
    KEY_TOKEN, LITERAL_TOKEN, NO_TOKEN, NUM_TOKENS, NUMERIC_TOKEN, STRING_TOKEN,
    VALUE_SEPARATOR_TOKEN,
};
use crate::json_tables::ASCII_TO_TOKEN_TABLE;
use crate::json_tables::JSON_CAPTURE_TABLE;
use crate::json_tables::PROCESS_RAW_TRANSCRIPT_TABLE;
use crate::json_tables::TOKEN_FLAGS_TABLE;
use crate::json_tables::TOKEN_VALIDATION_TABLE;
use crate::token_flags::TokenFlags;
use crate::transcript_entry::ValidationFlags;
use super::make_tables_subtables::{
    GRAMMAR_CAPTURE_ERROR_FLAG, GRAMMAR_CAPTURE_INCREASE_LENGTH, GRAMMAR_CAPTURE_PUSH_TRANSCRIPT,
    GRAMMAR_CAPTURE_TABLE, GRAMMAR_CAPTURE_TOKEN, LITERAL_CAPTURE_ERROR_FLAG,
    LITERAL_CAPTURE_INCREASE_LENGTH, LITERAL_CAPTURE_PUSH_TRANSCRIPT, LITERAL_CAPTURE_TABLE,
    LITERAL_CAPTURE_TOKEN, NUMERIC_CAPTURE_ERROR_FLAG, NUMERIC_CAPTURE_INCREASE_LENGTH,
    NUMERIC_CAPTURE_PUSH_TRANSCRIPT, NUMERIC_CAPTURE_TABLE, NUMERIC_CAPTURE_TOKEN,
    STRING_CAPTURE_ERROR_FLAG, STRING_CAPTURE_INCREASE_LENGTH, STRING_CAPTURE_PUSH_TRANSCRIPT,
    STRING_CAPTURE_TABLE, STRING_CAPTURE_TOKEN, TOKEN_IS_NUMERIC_OR_LITERAL,
};

global CAPTURE_TABLE: [[Field; 128]; 4] =
    [GRAMMAR_CAPTURE_TABLE, STRING_CAPTURE_TABLE, NUMERIC_CAPTURE_TABLE, LITERAL_CAPTURE_TABLE];
global CAPTURE_TOKEN: [[u32; 128]; 4] =
    [GRAMMAR_CAPTURE_TOKEN, STRING_CAPTURE_TOKEN, NUMERIC_CAPTURE_TOKEN, LITERAL_CAPTURE_TOKEN];
global CAPTURE_PUSH_TRANSCRIPT: [[bool; 128]; 4] = [
    GRAMMAR_CAPTURE_PUSH_TRANSCRIPT,
    STRING_CAPTURE_PUSH_TRANSCRIPT,
    NUMERIC_CAPTURE_PUSH_TRANSCRIPT,
    LITERAL_CAPTURE_PUSH_TRANSCRIPT,
];
global CAPTURE_INCREASE_LENGTH: [[bool; 128]; 4] = [
    GRAMMAR_CAPTURE_INCREASE_LENGTH,
    STRING_CAPTURE_INCREASE_LENGTH,
    NUMERIC_CAPTURE_INCREASE_LENGTH,
    LITERAL_CAPTURE_INCREASE_LENGTH,
];
global CAPTURE_ERROR_FLAG: [[bool; 128]; 4] = [
    GRAMMAR_CAPTURE_ERROR_FLAG,
    STRING_CAPTURE_ERROR_FLAG,
    NUMERIC_CAPTURE_ERROR_FLAG,
    LITERAL_CAPTURE_ERROR_FLAG,
];

unconstrained fn make_ascii_to_token_table() -> [Field; 1024] {
    let mut result: [Field; 256 * 4] = [0; 256 * 4];
    for i in 0..4 {
        for j in 0..128 {
            let token = CAPTURE_TOKEN[i][j];
            result[i * 256 + j] = token as Field;
        }
        for j in 0..128 {
            result[i * 256 + j + 128] = 0;
        }
    }
    result
}

unconstrained fn make_token_validation_table() -> [Field; NUM_TOKENS * NUM_TOKENS * 2] {
    // index = layer type, current token and next token
    // output is layer type
    // 11 tokens , 2 layers = 11 * 11 * 2 = 121 * 2 = 242
    // object contexts
    let no_change = ValidationFlags { push_layer: 0, push_layer_type_of_root: 0, pop_layer: 0 };
    let error_flags =
        ValidationFlags { push_layer: 0x1000000, push_layer_type_of_root: 0, pop_layer: 0 };
    let begin_new_object_flags = ValidationFlags {
        push_layer: 1,
        push_layer_type_of_root: OBJECT_LAYER as Field,
        pop_layer: 0,
    };
    let begin_new_array_flags = ValidationFlags {
        push_layer: 1,
        push_layer_type_of_root: ARRAY_LAYER as Field,
        pop_layer: 0,
    };
    let end_object_or_array_flags: ValidationFlags =
        ValidationFlags { push_layer: 0, push_layer_type_of_root: 0, pop_layer: 1 };

    let token_ids: [u32; NUM_TOKENS] = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10];

    let error_token_outcomes: [Field; NUM_TOKENS] = token_ids.map(|_| error_flags.to_field());
    let object_layer_begin_object_token_outcomes: [Field; NUM_TOKENS] = token_ids.map(|token| {
        let mut result = error_flags.to_field();
        if (token == KEY_TOKEN) {
            result = no_change.to_field();
        }
        if (token == END_OBJECT_TOKEN) {
            result = end_object_or_array_flags.to_field();
        }
        result
    });

    let object_layer_key_token_outcomes: [Field; NUM_TOKENS] = token_ids.map(|token| {
        let mut result = no_change.to_field();
        if (token != KEY_SEPARATOR_TOKEN) {
            result = error_flags.to_field();
        }
        result
    });

    let object_layer_key_separator_token_outcomes: [Field; NUM_TOKENS] = token_ids.map(|token| {
        let mut result = error_flags.to_field();
        if (token == STRING_TOKEN) | (token == LITERAL_TOKEN) | (token == NUMERIC_TOKEN) {
            result = no_change.to_field();
        }
        if (token == BEGIN_ARRAY_TOKEN) {
            result = begin_new_array_flags.to_field();
        }
        if (token == BEGIN_OBJECT_TOKEN) {
            result = begin_new_object_flags.to_field();
        }
        result
    });

    let object_layer_value_token_outcomes: [Field; NUM_TOKENS] = token_ids.map(|token| {
        let mut result = error_flags.to_field();
        if (token == VALUE_SEPARATOR_TOKEN) {
            result = no_change.to_field();
        }
        if (token == END_OBJECT_TOKEN) {
            result = end_object_or_array_flags.to_field();
        }
        result
    });

    let object_layer_end_object_outcomes: [Field; NUM_TOKENS] = token_ids.map(|token| {
        let mut result = error_flags.to_field();
        if (token == VALUE_SEPARATOR_TOKEN) {
            result = no_change.to_field();
        }
        if (token == END_OBJECT_TOKEN) {
            result = end_object_or_array_flags.to_field();
        }
        // we can reach the end of the JSON via this path
        if (token == NO_TOKEN) {
            result = no_change.to_field();
        }
        result
    });

    let object_layer_value_separator_token_outcomes: [Field; NUM_TOKENS] = token_ids.map(|token| {
        let mut result = error_flags.to_field();
        if (token == KEY_TOKEN) {
            result = no_change.to_field();
        }
        result
    });

    let mut object_layer_flags: [[Field; NUM_TOKENS]; NUM_TOKENS] = [[0; NUM_TOKENS]; NUM_TOKENS];
    let mut array_layer_flags: [[Field; NUM_TOKENS]; NUM_TOKENS] = [[0; NUM_TOKENS]; NUM_TOKENS];
    let no_token_outcomes: [Field; NUM_TOKENS] = token_ids.map(|token| {
        let mut result = error_flags.to_field();
        if (token == NO_TOKEN) {
            result = no_change.to_field();
        }
        result
    });

    object_layer_flags[NO_TOKEN] = no_token_outcomes;
    object_layer_flags[BEGIN_OBJECT_TOKEN] = object_layer_begin_object_token_outcomes;
    object_layer_flags[END_OBJECT_TOKEN] = object_layer_end_object_outcomes;
    object_layer_flags[BEGIN_ARRAY_TOKEN] = error_token_outcomes;
    object_layer_flags[END_ARRAY_TOKEN] = object_layer_value_token_outcomes;
    object_layer_flags[KEY_SEPARATOR_TOKEN] = object_layer_key_separator_token_outcomes;
    object_layer_flags[VALUE_SEPARATOR_TOKEN] = object_layer_value_separator_token_outcomes;
    object_layer_flags[STRING_TOKEN] = object_layer_value_token_outcomes;
    object_layer_flags[NUMERIC_TOKEN] = object_layer_value_token_outcomes;
    object_layer_flags[LITERAL_TOKEN] = object_layer_value_token_outcomes;
    object_layer_flags[KEY_TOKEN] = object_layer_key_token_outcomes;

    let array_layer_begin_array_token_outcomes: [Field; NUM_TOKENS] = token_ids.map(|token: u32| {
        let mut result = error_flags.to_field();
        if (token == STRING_TOKEN) | (token == LITERAL_TOKEN) | (token == NUMERIC_TOKEN) {
            result = no_change.to_field();
        }
        if (token == BEGIN_OBJECT_TOKEN) {
            result = begin_new_object_flags.to_field();
        }
        if (token == BEGIN_ARRAY_TOKEN) {
            result = begin_new_array_flags.to_field();
        }
        if (token == END_ARRAY_TOKEN) {
            result = end_object_or_array_flags.to_field();
        }
        result
    });

    let array_layer_value_token_outcomes: [Field; NUM_TOKENS] = token_ids.map(|token| {
        let mut result = error_flags.to_field();
        if (token == VALUE_SEPARATOR_TOKEN) {
            result = no_change.to_field();
        }
        if (token == END_ARRAY_TOKEN) {
            result = end_object_or_array_flags.to_field();
        }
        result
    });

    let array_layer_value_separator_token_outcomes: [Field; NUM_TOKENS] = token_ids.map(|token| {
        let mut result = error_flags.to_field();
        if (token == STRING_TOKEN) | (token == LITERAL_TOKEN) | (token == NUMERIC_TOKEN) {
            result = no_change.to_field();
        }
        if (token == BEGIN_OBJECT_TOKEN) {
            result = begin_new_object_flags.to_field();
        }
        if (token == BEGIN_ARRAY_TOKEN) {
            result = begin_new_array_flags.to_field();
        }
        result
    });

    let array_layer_value_token_outcomes: [Field; NUM_TOKENS] = token_ids.map(|token| {
        let mut result = error_flags.to_field();
        if (token == VALUE_SEPARATOR_TOKEN) {
            result = no_change.to_field();
        }
        if (token == END_ARRAY_TOKEN) {
            result = end_object_or_array_flags.to_field();
        }
        result
    });
    let array_layer_end_array_outcomes: [Field; NUM_TOKENS] = token_ids.map(|token| {
        let mut result = error_flags.to_field();
        if (token == VALUE_SEPARATOR_TOKEN) {
            result = no_change.to_field();
        }
        if (token == END_ARRAY_TOKEN) {
            result = end_object_or_array_flags.to_field();
        }
        // we can reach the end of the JSON via this path
        if (token == NO_TOKEN) {
            result = no_change.to_field();
        }
        result
    });
    let array_layer_end_object_outcomes: [Field; NUM_TOKENS] = token_ids.map(|token| {
        let mut result = error_flags.to_field();
        if (token == VALUE_SEPARATOR_TOKEN) {
            result = no_change.to_field();
        }
        if (token == END_ARRAY_TOKEN) {
            result = end_object_or_array_flags.to_field();
        }
        result
    });

    array_layer_flags[NO_TOKEN] = no_token_outcomes;
    array_layer_flags[BEGIN_OBJECT_TOKEN] = error_token_outcomes;
    array_layer_flags[END_OBJECT_TOKEN] = array_layer_end_object_outcomes;
    array_layer_flags[BEGIN_ARRAY_TOKEN] = array_layer_begin_array_token_outcomes;
    array_layer_flags[END_ARRAY_TOKEN] = array_layer_end_array_outcomes;
    array_layer_flags[KEY_SEPARATOR_TOKEN] = error_token_outcomes;
    array_layer_flags[VALUE_SEPARATOR_TOKEN] = array_layer_value_separator_token_outcomes;
    array_layer_flags[STRING_TOKEN] = array_layer_value_token_outcomes;
    array_layer_flags[NUMERIC_TOKEN] = array_layer_value_token_outcomes;
    array_layer_flags[LITERAL_TOKEN] = array_layer_value_token_outcomes;
    array_layer_flags[KEY_TOKEN] = error_token_outcomes;
    let mut flattened_flags: [Field; NUM_TOKENS * NUM_TOKENS * 2] =
        [0; NUM_TOKENS * NUM_TOKENS * 2];
    let NN = (NUM_TOKENS * NUM_TOKENS);
    for j in 0..NUM_TOKENS {
        for k in 0..NUM_TOKENS {
            flattened_flags[OBJECT_LAYER * NN + j * NUM_TOKENS + k] = object_layer_flags[j][k];
            flattened_flags[ARRAY_LAYER * NN + j * NUM_TOKENS + k] = array_layer_flags[j][k];
        }
    }
    flattened_flags
}

unconstrained fn make_json_capture_table() -> [Field; 2048] {
    let backslash: u32 = "\\".as_bytes()[0] as u32;
    let quotes: u32 = "\"".as_bytes()[0] as u32;
    let mut result: [Field; 2048] = [0; 2048];
    for previous_was_potential_capture_escape in 0..2 {
        for i in 0..4 {
            for j in 0..128 {
                let mut scan_token = CAPTURE_TABLE[i][j];
                let mut push_transcript = CAPTURE_PUSH_TRANSCRIPT[i][j] as Field;
                let mut increase_length = CAPTURE_INCREASE_LENGTH[i][j] as Field;
                let mut error = CAPTURE_ERROR_FLAG[i][j] as Field;

                let mut is_potential_capture_escape = 0;
                if (scan_token == STRING_CAPTURE) & (j == backslash) {
                    is_potential_capture_escape = 1;
                }
                if ((previous_was_potential_capture_escape == 1) & (j == quotes)) {
                    scan_token = STRING_CAPTURE;
                    push_transcript = 0;
                    increase_length = 1;
                    error = 0;
                }
                let full = scan_token
                    + push_transcript * 0x100
                    + increase_length * 0x10000
                    + is_potential_capture_escape * 0x1000000
                    + error * 0x100000000;
                let index = i * 256 + previous_was_potential_capture_escape * 1024 + j;
                result[index] = full;
            }
            for j in 0..128 {
                let index = i * 256 + previous_was_potential_capture_escape * 1024 + j + 128;
                result[index] = 0x100000000; // error flag
            }
        }
    }

    result
}

unconstrained fn make_process_raw_transcript_table() -> [Field; 1024] {
    let mut result: [Field; 1024] = [0; 1024];
    for i in 0..4 {
        for j in 0..128 {
            let token = CAPTURE_TOKEN[i][j];
            let token_is_numeric_or_literal = TOKEN_IS_NUMERIC_OR_LITERAL[token];
            let new_grammar = GRAMMAR_CAPTURE_PUSH_TRANSCRIPT[j] as Field;
            let scan_token = GRAMMAR_CAPTURE_TOKEN[j];
            let new_grammar = ((new_grammar == 1) & (token_is_numeric_or_literal == 1)) as Field;
            result[i * 256 + j] =
                token as Field + new_grammar * 0x100 + scan_token as Field * 0x10000;
        }
        for j in 128..256 {
            result[i * 256 + j] = 0;
        }
    }
    result
}

unconstrained fn generate_token_flags_table() -> [Field; NUM_TOKENS * 2] {
    let mut flags: [TokenFlags; NUM_TOKENS * 2] = std::mem::zeroed();

    let mut no_token_flags: TokenFlags = TokenFlags {
        create_json_entry: false,
        is_end_of_object_or_array: false,
        is_start_of_object_or_array: false,
        new_context: OBJECT_LAYER != 0,
        is_key_token: false,
        is_value_token: false,
        preserve_num_entries: true,
    };
    let mut key_token_flags: TokenFlags = TokenFlags {
        create_json_entry: false,
        is_end_of_object_or_array: false,
        is_start_of_object_or_array: false,
        new_context: OBJECT_LAYER != 0,
        is_key_token: true,
        is_value_token: false,
        preserve_num_entries: true,
    };
    let begin_object_flags = TokenFlags {
        create_json_entry: false,
        is_end_of_object_or_array: false,
        is_start_of_object_or_array: true,
        new_context: OBJECT_LAYER != 0,
        is_key_token: false,
        is_value_token: false,
        preserve_num_entries: false,
    };

    let begin_array_flags = TokenFlags {
        create_json_entry: false,
        is_end_of_object_or_array: false,
        is_start_of_object_or_array: true,
        new_context: ARRAY_LAYER != 0,
        is_key_token: false,
        is_value_token: false,
        preserve_num_entries: false,
    };

    let mut end_object_flags = TokenFlags {
        create_json_entry: true,
        is_end_of_object_or_array: true,
        is_start_of_object_or_array: false,
        new_context: false,
        is_key_token: false,
        is_value_token: false,
        preserve_num_entries: false,
    };

    let mut end_array_flags = TokenFlags {
        create_json_entry: true,
        is_end_of_object_or_array: true,
        is_start_of_object_or_array: false,
        new_context: false,
        is_key_token: false,
        is_value_token: false,
        preserve_num_entries: false,
    };

    let mut string_flags = TokenFlags {
        create_json_entry: true,
        is_end_of_object_or_array: false,
        is_start_of_object_or_array: false,
        new_context: OBJECT_LAYER != 0,
        is_key_token: false,
        is_value_token: true,
        preserve_num_entries: true,
    };

    let mut numeric_flags = TokenFlags {
        create_json_entry: true,
        is_end_of_object_or_array: false,
        is_start_of_object_or_array: false,
        new_context: OBJECT_LAYER != 0,
        is_key_token: false,
        is_value_token: true,
        preserve_num_entries: true,
    };

    let mut literal_flags = TokenFlags {
        create_json_entry: true,
        is_end_of_object_or_array: false,
        is_start_of_object_or_array: false,
        new_context: OBJECT_LAYER != 0,
        is_key_token: false,
        is_value_token: true,
        preserve_num_entries: true,
    };

    flags[NO_TOKEN] = no_token_flags;
    flags[BEGIN_OBJECT_TOKEN] = begin_object_flags;
    flags[END_OBJECT_TOKEN] = end_object_flags;
    flags[BEGIN_ARRAY_TOKEN] = begin_array_flags;
    flags[END_ARRAY_TOKEN] = end_array_flags;
    flags[KEY_SEPARATOR_TOKEN] = no_token_flags;
    flags[VALUE_SEPARATOR_TOKEN] = no_token_flags;
    flags[STRING_TOKEN] = string_flags;
    flags[NUMERIC_TOKEN] = numeric_flags;
    flags[LITERAL_TOKEN] = literal_flags;
    flags[KEY_TOKEN] = key_token_flags;

    no_token_flags.new_context = ARRAY_LAYER != 0;
    key_token_flags.new_context = ARRAY_LAYER != 0;
    string_flags.new_context = ARRAY_LAYER != 0;
    numeric_flags.new_context = ARRAY_LAYER != 0;
    literal_flags.new_context = ARRAY_LAYER != 0;

    flags[NUM_TOKENS + NO_TOKEN] = no_token_flags;
    flags[NUM_TOKENS + BEGIN_OBJECT_TOKEN] = begin_object_flags;
    flags[NUM_TOKENS + END_OBJECT_TOKEN] = end_object_flags;
    flags[NUM_TOKENS + BEGIN_ARRAY_TOKEN] = begin_array_flags;
    flags[NUM_TOKENS + END_ARRAY_TOKEN] = end_array_flags;
    flags[NUM_TOKENS + KEY_SEPARATOR_TOKEN] = no_token_flags;
    flags[NUM_TOKENS + VALUE_SEPARATOR_TOKEN] = no_token_flags;
    flags[NUM_TOKENS + STRING_TOKEN] = string_flags;
    flags[NUM_TOKENS + NUMERIC_TOKEN] = numeric_flags;
    flags[NUM_TOKENS + LITERAL_TOKEN] = literal_flags;
    flags[NUM_TOKENS + KEY_TOKEN] = key_token_flags;

    let mut result: [Field; NUM_TOKENS * 2] = [0; NUM_TOKENS * 2];
    for i in 0..(NUM_TOKENS * 2) {
        result[i] = flags[i].to_field();
    }
    result
}

#[test]
fn test_generate_token_flags_table() {
    unsafe {
        let r = generate_token_flags_table();
        assert(r == TOKEN_FLAGS_TABLE);
    }
}

#[test]
fn test_make_json_capture_table() {
    unsafe {
        let r = make_json_capture_table();
        assert(r == JSON_CAPTURE_TABLE);
    }
}

#[test]
fn test_make_validation_flags() {
    unsafe {
        let f = make_token_validation_table();
        assert(f == TOKEN_VALIDATION_TABLE);
    }
}
#[test]
fn test_make_ascii_to_token_table() {
    unsafe {
        let r = make_ascii_to_token_table();
        assert(r == ASCII_TO_TOKEN_TABLE);
    }
}

#[test]
fn test_make_process_raw_transcript_table() {
    unsafe {
        let r = make_process_raw_transcript_table();
        assert(r == PROCESS_RAW_TRANSCRIPT_TABLE);
    }
}
