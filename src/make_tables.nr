/**
 * @file Contains methods used to generate tables in `json_tables.nr`. These table generation methods shouldn't be used inside of actual circuits.
 **/
use crate::json_tables::{
    OBJECT_LAYER, ARRAY_LAYER, SINGLE_VALUE_LAYER, STRING_CAPTURE, BEGIN_ARRAY_TOKEN, NO_TOKEN,
    END_OBJECT_TOKEN, END_ARRAY_TOKEN, KEY_SEPARATOR_TOKEN, VALUE_SEPARATOR_TOKEN, KEY_TOKEN,
    BEGIN_OBJECT_TOKEN, NUMERIC_TOKEN, STRING_TOKEN, LITERAL_TOKEN, OBJECT_CONTEXT, ARRAY_CONTEXT,
    NUM_TOKENS, GRAMMAR_CAPTURE_TABLE, STRING_CAPTURE_TABLE, NUMERIC_CAPTURE_TABLE,
    LITERAL_CAPTURE_TABLE, GRAMMAR_CAPTURE_TOKEN, STRING_CAPTURE_TOKEN, NUMERIC_CAPTURE_TOKEN,
    LITERAL_CAPTURE_TOKEN, GRAMMAR_CAPTURE_PUSH_TRANSCRIPT, STRING_CAPTURE_PUSH_TRANSCRIPT,
    NUMERIC_CAPTURE_PUSH_TRANSCRIPT, LITERAL_CAPTURE_PUSH_TRANSCRIPT, GRAMMAR_CAPTURE_INCREASE_LENGTH,
    STRING_CAPTURE_INCREASE_LENGTH, NUMERIC_CAPTURE_INCREASE_LENGTH, LITERAL_CAPTURE_INCREASE_LENGTH,
    GRAMMAR_CAPTURE_ERROR_FLAG, STRING_CAPTURE_ERROR_FLAG, NUMERIC_CAPTURE_ERROR_FLAG,
    LITERAL_CAPTURE_ERROR_FLAG, TOKEN_IS_NUMERIC_OR_LITERAL
};

use crate::token_flags::TokenFlags;
use crate::transcript_entry::ValidationFlags;

global CAPTURE_TABLE: [[Field; 128]; 4] = [GRAMMAR_CAPTURE_TABLE, STRING_CAPTURE_TABLE, NUMERIC_CAPTURE_TABLE, LITERAL_CAPTURE_TABLE];
global CAPTURE_TOKEN: [[Field; 128]; 4] = [GRAMMAR_CAPTURE_TOKEN, STRING_CAPTURE_TOKEN, NUMERIC_CAPTURE_TOKEN, LITERAL_CAPTURE_TOKEN];
global CAPTURE_PUSH_TRANSCRIPT: [[bool; 128]; 4] = [GRAMMAR_CAPTURE_PUSH_TRANSCRIPT, STRING_CAPTURE_PUSH_TRANSCRIPT, NUMERIC_CAPTURE_PUSH_TRANSCRIPT, LITERAL_CAPTURE_PUSH_TRANSCRIPT];
global CAPTURE_INCREASE_LENGTH: [[bool; 128]; 4] = [GRAMMAR_CAPTURE_INCREASE_LENGTH, STRING_CAPTURE_INCREASE_LENGTH, NUMERIC_CAPTURE_INCREASE_LENGTH, LITERAL_CAPTURE_INCREASE_LENGTH];
global CAPTURE_ERROR_FLAG: [[bool; 128]; 4] = [GRAMMAR_CAPTURE_ERROR_FLAG, STRING_CAPTURE_ERROR_FLAG, NUMERIC_CAPTURE_ERROR_FLAG, LITERAL_CAPTURE_ERROR_FLAG];

unconstrained fn make_capture_table_full() -> [[Field; 128]; 4] {
    let mut result: [[Field; 128]; 4] = [[0; 128]; 4];
    for i in 0..4 {
        for j in 0..128 {
            let table = CAPTURE_TABLE[i][j];
            let token = CAPTURE_TOKEN[i][j];
            let push_transcript = CAPTURE_PUSH_TRANSCRIPT[i][j] as Field;
            let increase_length = CAPTURE_INCREASE_LENGTH[i][j] as Field;
            let error = CAPTURE_ERROR_FLAG[i][j] as Field;

            let full = table
                + token * 0x100
                + push_transcript * 0x10000
                + increase_length * 0x1000000
                + error * 0x100000000;
            result[i][j] = full;
        }
    }

    result
}

unconstrained fn make_ascii_to_token_table() -> [Field; 1024] {
    let mut result: [Field; 256 * 4] = [0; 256 * 4];
    for i in 0..4 {
        for j in 0..128 {
            let token = CAPTURE_TOKEN[i][j];
            result[i * 256 + j] = token;
        }
        for j in 0..128 {
            result[i * 256 + j + 128] = 0;
        }
    }
    result
}

unconstrained fn make_token_validation_table() -> [Field; NUM_TOKENS * NUM_TOKENS * 3] {
    // index = layer type, current token and next token
    // output is layer type
    // 11 tokens , 3 layers = 11 * 11 * 3 = 121 * 3 = 343
    // object contexts
    let no_change = ValidationFlags { push_layer: 0, push_layer_id: 0, pop_layer: 0, error: 0 };
    let error_flags = ValidationFlags { push_layer: 0, push_layer_id: 0, pop_layer: 0, error: 1 };
    let begin_new_object_flags = ValidationFlags { push_layer: 1, push_layer_id: OBJECT_LAYER, pop_layer: 0, error: 0 };
    let begin_new_array_flags = ValidationFlags { push_layer: 1, push_layer_id: ARRAY_LAYER, pop_layer: 0, error: 0 };
    let end_object_or_array_flags: ValidationFlags = ValidationFlags { push_layer: 0, push_layer_id: 0, pop_layer: 1, error: 0 };

    let token_ids: [Field; NUM_TOKENS] = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10];

    let error_token_outcomes: [Field; NUM_TOKENS] = token_ids.map(|_| error_flags.to_field());
    let object_layer_begin_object_token_outcomes: [Field; NUM_TOKENS] = token_ids.map(
        |token| {
        let mut result = error_flags.to_field();
        if (token == KEY_TOKEN)
        {
            result = no_change.to_field();
        }
        if (token == END_OBJECT_TOKEN)
        {
            result = end_object_or_array_flags.to_field();
        }
        result
    }
    );

    let object_layer_key_token_outcomes: [Field; NUM_TOKENS] = token_ids.map(
        |token| {
            let mut result = no_change.to_field();
            if (token != KEY_SEPARATOR_TOKEN)
            {
                result = error_flags.to_field();
            }
            result
        }
    );

    let object_layer_key_separator_token_outcomes: [Field; NUM_TOKENS] = token_ids.map(
        |token| {
            let mut result = error_flags.to_field();
            if (token == STRING_TOKEN) | (token == LITERAL_TOKEN) | (token == NUMERIC_TOKEN)
            {
                result = no_change.to_field();
            }
            if (token == BEGIN_ARRAY_TOKEN)
            {
                result = begin_new_array_flags.to_field();
            }
            if (token == BEGIN_OBJECT_TOKEN)
            {
                result = begin_new_object_flags.to_field();
            }
            result
        }
    );

    let object_layer_value_token_outcomes: [Field; NUM_TOKENS] = token_ids.map(
        |token| {
            let mut result = error_flags.to_field();
            if (token == VALUE_SEPARATOR_TOKEN)
            {
                result = no_change.to_field();
            }
            if (token == END_OBJECT_TOKEN)
            {
                result = end_object_or_array_flags.to_field();
            }
            result
        }
    );

    let object_layer_end_object_outcomes: [Field; NUM_TOKENS] = token_ids.map(
        |token| {
            let mut result = error_flags.to_field();
            if (token == VALUE_SEPARATOR_TOKEN)
            {
                result = no_change.to_field();
            }
            if (token == END_OBJECT_TOKEN)
            {
                result = end_object_or_array_flags.to_field();
            }
            // we can reach the end of the JSON via this path
            if (token == NO_TOKEN)
            {
                result = no_change.to_field();
            }
            result
        }
    );

    let object_layer_value_separator_token_outcomes: [Field; NUM_TOKENS] = token_ids.map(
        |token| {
            let mut result = error_flags.to_field();
            if (token == KEY_TOKEN)
            {
                result = no_change.to_field();
            }
            result
        }
    );

    let mut object_layer_flags: [[Field; NUM_TOKENS]; NUM_TOKENS] = [[0; NUM_TOKENS]; NUM_TOKENS];
    let mut array_layer_flags: [[Field; NUM_TOKENS]; NUM_TOKENS] = [[0; NUM_TOKENS]; NUM_TOKENS];
    let mut single_value_layer_flags: [[Field; NUM_TOKENS]; NUM_TOKENS] = [[0; NUM_TOKENS]; NUM_TOKENS];

    let no_token_outcomes: [Field; NUM_TOKENS] = token_ids.map(
        |token| {
        let mut result = error_flags.to_field();
        if (token == NO_TOKEN)
        {
            result = no_change.to_field();
        }
        result
    }
    );

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

    let array_layer_begin_array_token_outcomes: [Field; NUM_TOKENS] = token_ids.map(
        |token| {
        let mut result = error_flags.to_field();
        if (token == STRING_TOKEN ) | (token == LITERAL_TOKEN) | (token == NUMERIC_TOKEN)
        {
            result = no_change.to_field();
        }
        if (token == BEGIN_OBJECT_TOKEN)
        {
            result = begin_new_object_flags.to_field();
        }
        if (token == BEGIN_ARRAY_TOKEN)
        {
            result = begin_new_array_flags.to_field();
        }
        if (token == END_ARRAY_TOKEN)
        {
            result = end_object_or_array_flags.to_field();
        }
        result
    }
    );

    let array_layer_value_token_outcomes: [Field; NUM_TOKENS] = token_ids.map(
        |token| {
        let mut result = error_flags.to_field();
        if (token == VALUE_SEPARATOR_TOKEN )
        {
            result = no_change.to_field();
        }
        if (token == END_ARRAY_TOKEN)
        {
            result = end_object_or_array_flags.to_field();
        }
        result
    }
    );

    let array_layer_value_separator_token_outcomes: [Field; NUM_TOKENS] = token_ids.map(
        |token| {
        let mut result = error_flags.to_field();
        if (token == STRING_TOKEN ) | (token == LITERAL_TOKEN) | (token == NUMERIC_TOKEN)
        {
            result = no_change.to_field();
        }
        if (token == BEGIN_OBJECT_TOKEN)
        {
            result = begin_new_object_flags.to_field();
        }
        if (token == BEGIN_ARRAY_TOKEN)
        {
            result = begin_new_array_flags.to_field();
        }
        result
    }
    );

    let array_layer_value_token_outcomes: [Field; NUM_TOKENS] = token_ids.map(
        |token| {
            let mut result = error_flags.to_field();
            if (token == VALUE_SEPARATOR_TOKEN)
            {
                result = no_change.to_field();
            }
            if (token == END_ARRAY_TOKEN)
            {
                result = end_object_or_array_flags.to_field();
            }
            result
        }
    );
    let array_layer_end_array_outcomes: [Field; NUM_TOKENS] = token_ids.map(
        |token| {
            let mut result = error_flags.to_field();
            if (token == VALUE_SEPARATOR_TOKEN)
            {
                result = no_change.to_field();
            }
            if (token == END_ARRAY_TOKEN)
            {
                result = end_object_or_array_flags.to_field();
            }
            // we can reach the end of the JSON via this path
            if (token == NO_TOKEN)
            {
                result = no_change.to_field();
            }
            result
        }
    );
    let array_layer_end_object_outcomes: [Field; NUM_TOKENS] = token_ids.map(
        |token| {
            let mut result = error_flags.to_field();
            if (token == VALUE_SEPARATOR_TOKEN)
            {
                result = no_change.to_field();
            }
            if (token == END_ARRAY_TOKEN)
            {
                result = end_object_or_array_flags.to_field();
            }
            result
        }
    );

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

    let single_value_layer_value_token_outcomes: [Field; NUM_TOKENS] = token_ids.map(
        |token| {
        let mut result = error_flags.to_field();
        // we have reached the end of json
        if (token == NO_TOKEN)
        {
            result = no_change.to_field();
        }
        result
    }
    );
    single_value_layer_flags[NO_TOKEN] = no_token_outcomes;
    single_value_layer_flags[BEGIN_OBJECT_TOKEN] = error_token_outcomes;
    single_value_layer_flags[END_OBJECT_TOKEN] = single_value_layer_value_token_outcomes;
    single_value_layer_flags[BEGIN_ARRAY_TOKEN] = error_token_outcomes;
    single_value_layer_flags[END_ARRAY_TOKEN] = single_value_layer_value_token_outcomes;
    single_value_layer_flags[KEY_SEPARATOR_TOKEN] = object_layer_key_separator_token_outcomes;
    single_value_layer_flags[VALUE_SEPARATOR_TOKEN] = error_token_outcomes;
    single_value_layer_flags[STRING_TOKEN] = single_value_layer_value_token_outcomes;
    single_value_layer_flags[NUMERIC_TOKEN] = single_value_layer_value_token_outcomes;
    single_value_layer_flags[LITERAL_TOKEN] = single_value_layer_value_token_outcomes;
    single_value_layer_flags[KEY_TOKEN] = no_token_outcomes;

    let mut flattened_flags: [Field; NUM_TOKENS * NUM_TOKENS * 3] = [0; NUM_TOKENS * NUM_TOKENS * 3];
    let NN = NUM_TOKENS * NUM_TOKENS as Field;
    for j in 0..NUM_TOKENS as u32 {
        for k in 0..NUM_TOKENS as u32 {
            flattened_flags[OBJECT_LAYER * NN + j as Field * NUM_TOKENS + k as Field] = object_layer_flags[j][k];
            flattened_flags[ARRAY_LAYER * NN + j as Field * NUM_TOKENS + k as Field] = array_layer_flags[j][k];
            flattened_flags[SINGLE_VALUE_LAYER * NN + j as Field * NUM_TOKENS + k as Field] = single_value_layer_flags[j][k];
        }
    }
    flattened_flags
}

// #[test]
// fn test_make_validation_flags() {
//     let f = make_token_validation_table();
//     println(f"global TOKEN_VALIDATION_TABLE: [Field; 363] = {f};");
// }
// #[test]
// fn test_make_ascii_to_token_table() {
//     let r = make_ascii_to_token_table();
//     println(f"table = {r}");
// }
unconstrained fn make_reduced_capture_table() -> [Field; 2048] {
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
// #[test]
// fn test_make_reduced_capture_table() {
//     let r = make_reduced_capture_table();
//     println(f"table = {r}");
// }

unconstrained fn make_process_raw_transcript_table() -> [Field; 1024] {
    // let token_is_numeric_or_literal = TOKEN_IS_NUMERIC_OR_LITERAL[token];

    // let new_grammar = GRAMMAR_CAPTURE_PUSH_TRANSCRIPT[ascii];
    // let scan_token: Field = GRAMMAR_CAPTURE_TOKEN[ascii];
    let mut result: [Field; 1024] = [0; 1024];
    for i in 0..4 {
        for j in 0..128 {
            let token = CAPTURE_TOKEN[i][j];
            let token_is_numeric_or_literal = TOKEN_IS_NUMERIC_OR_LITERAL[token];
            let new_grammar = GRAMMAR_CAPTURE_PUSH_TRANSCRIPT[j] as Field;
            let scan_token = GRAMMAR_CAPTURE_TOKEN[j];
            let new_grammar = ((new_grammar == 1) & (token_is_numeric_or_literal == 1)) as Field;
            result[i * 256 + j] = token
                + new_grammar * 0x100
                + scan_token * 0x10000;
        }
        for j in 128..256 {
            result[i * 256 + j] = 0;
        }
    }
    result
}
// #[test]
// fn test_make_process_raw_transcript_table() {
//     let r = make_process_raw_transcript_table();
//     println(f"table = {r}");
// }

unconstrained fn generate_token_flags_table() -> [Field; NUM_TOKENS * 2] {
    let mut flags: [TokenFlags; NUM_TOKENS * 2] = [TokenFlags::default(); NUM_TOKENS * 2];

    let mut no_token_flags: TokenFlags = TokenFlags {
        create_json_entry: 0,
        json_entry_type: 0,
        is_end_of_object_or_array: 0,
        is_start_of_object_or_array: 0,
        new_context: OBJECT_CONTEXT,
        is_key_token: 0,
        is_value_token: 0,
        // is_value_token_in_array_context: 0,
        // create_key_entry: 0,
        // // is_array_context: 0,
        // preserve_identity_value: 1,
        preserve_num_entries: 1
    };
    let mut key_token_flags: TokenFlags = TokenFlags {
        create_json_entry: 0,
        json_entry_type: 0,
        is_end_of_object_or_array: 0,
        is_start_of_object_or_array: 0,
        new_context: OBJECT_CONTEXT,
        is_key_token: 1,
        is_value_token: 0,
        // is_value_token_in_array_context: 0,
        // create_key_entry: 0,
        // // is_array_context: 0,
        // preserve_identity_value: 1,
        preserve_num_entries: 1
    };
    let begin_object_flags = TokenFlags {
        create_json_entry: 0,
        json_entry_type: 0,
        is_end_of_object_or_array: 0,
        is_start_of_object_or_array: 1,
        new_context: OBJECT_CONTEXT,
        is_key_token: 0,
        is_value_token: 0,
        // is_value_token_in_array_context: 0,
        // create_key_entry: 0,
        // // is_array_context: 0,
        // preserve_identity_value: 0,
        preserve_num_entries: 0
    };

    let begin_array_flags = TokenFlags {
        create_json_entry: 0,
        json_entry_type: 0,
        is_end_of_object_or_array: 0,
        is_start_of_object_or_array: 1,
        new_context: ARRAY_CONTEXT,
        is_key_token: 0,
        is_value_token: 0,
        // is_value_token_in_array_context: 0,
        // create_key_entry: 0,
        // is_array_context: 0,
        // preserve_identity_value: 0,
        preserve_num_entries: 0
    };

    let mut end_object_flags = TokenFlags {
        create_json_entry: 1,
        json_entry_type: BEGIN_OBJECT_TOKEN,
        is_end_of_object_or_array: 1,
        is_start_of_object_or_array: 0,
        new_context: 0,
        is_key_token: 0,
        is_value_token: 0,
        // is_value_token_in_array_context: 0,
        // create_key_entry: 1,
        // is_array_context: 0,
        // preserve_identity_value: 0,
        preserve_num_entries: 0
    };

    let mut end_array_flags = TokenFlags {
        create_json_entry: 1,
        json_entry_type: BEGIN_ARRAY_TOKEN,
        is_end_of_object_or_array: 1,
        is_start_of_object_or_array: 0,
        new_context: 0,
        is_key_token: 0,
        is_value_token: 0,
        // is_value_token_in_array_context: 0,
        // create_key_entry: 1,
        // is_array_context: 0,
        // preserve_identity_value: 0,
        preserve_num_entries: 0
    };

    let mut string_flags = TokenFlags {
        create_json_entry: 1,
        json_entry_type: STRING_TOKEN,
        is_end_of_object_or_array: 0,
        is_start_of_object_or_array: 0,
        new_context: OBJECT_CONTEXT,
        is_key_token: 0,
        is_value_token: 1,
        // is_value_token_in_array_context: 0,
        // create_key_entry: 1,
        // // is_array_context: 0,
        // preserve_identity_value: 1,
        preserve_num_entries: 1
    };

    let mut numeric_flags = TokenFlags {
        create_json_entry: 1,
        json_entry_type: NUMERIC_TOKEN,
        is_end_of_object_or_array: 0,
        is_start_of_object_or_array: 0,
        new_context: OBJECT_CONTEXT,
        is_key_token: 0,
        is_value_token: 1,
        // is_value_token_in_array_context: 0,
        // create_key_entry: 1,
        // // is_array_context: 0,
        // preserve_identity_value: 1,
        preserve_num_entries: 1
    };

    let mut literal_flags = TokenFlags {
        create_json_entry: 1,
        json_entry_type: LITERAL_TOKEN,
        is_end_of_object_or_array: 0,
        is_start_of_object_or_array: 0,
        new_context: OBJECT_CONTEXT,
        is_key_token: 0,
        is_value_token: 1,
        // is_value_token_in_array_context: 0,
        // create_key_entry: 1,
        // // is_array_context: 0,
        // preserve_identity_value: 1,
        preserve_num_entries: 1
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

    no_token_flags.new_context = ARRAY_CONTEXT;
    key_token_flags.new_context = ARRAY_CONTEXT;
    string_flags.new_context = ARRAY_CONTEXT;
    numeric_flags.new_context = ARRAY_CONTEXT;
    literal_flags.new_context = ARRAY_CONTEXT;

    // end_object_flags.is_array_context = 1;
    // end_array_flags.is_array_context = 1;
    // string_flags.is_value_token_in_array_context = 1;
    // numeric_flags.is_value_token_in_array_context = 1;
    // literal_flags.is_value_token_in_array_context = 1;
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
    for i in 0..(NUM_TOKENS as u32 * 2) {
        result[i] = flags[i].to_field();
    }
    result
}

#[test]
fn test_generate_token_flags_table() {
    let r = generate_token_flags_table();
    println(f"global TOKEN_FLAGS_TABLE: [Field; NUM_TOKENS_MUL_2] = {r};");
}
