fn parse_JSON_copy<let N: u32, let TranscriptEntries: u32, let KeyEntries: u32, let ValueEntries: u32>(
    json: [u8; N],
    transcript: [Field; TranscriptEntries],
    json_keys: [Field; KeyEntries]
) -> [Field; ValueEntries] {
    let mut transcript_ptr: Field = 0;
    let mut capture_in_progress: bool = false;
    let mut value_ptr = 0;

    let mut capture_in_progress = false;
    let mut search_in_progress = true;
    let mut grammar_token_found = false;
    let mut capture_field = 0;

    let mut value_indices: [Field; ValueEntries] = [0; ValueEntries];
    let mut key_ptr = 0;

    let mut ascii = json[0];
    let mut skip = false;

    for i in 0..N {
        if (skip) {
            ascii = json[i + 1];
            skip = false;
        } else {
            let mut transcript_capture = transcript[transcript_ptr];

            let mut new_ascii = 0;
            if (i < N - 1) {
                new_ascii = json[i + 1];
            }

            let flags_raw = JSON_BITFLAGS[transcript_capture][ascii];

            let flags: [u1; 6] = flags_raw.to_be_bits(6).as_array();
            // let escape_start = ESCAPE_SEQUENCE_START_CHARS[i];
            // let escape_end = ESCAPE_SEQUENCE_END_CHARS[i];
            // let search = SEARCH_CHARACTERS[i];
            // let start = BOOL_START_CHARACTERS[i];
            // let end = BOOL_END_CHARACTERS[i];
            // let value = BOOL_VALUE_CHARACTERS[i];
            let possible_escape_sequence_lo = flags[5] as bool;
            // let possible_escape_sequence_hi = flags[4] as bool;
            let valid_search_token = flags[3] as bool;
            let valid_start_token = flags[2] as bool;
            let valid_end_token = flags[1] as bool;
            let valid_value_token = flags[0] as bool;
            // let possible_escape_sequence_lo = ESCAPE_SEQUENCE_START_CHARS[ascii]; // backslash ascii code

            let possible_escape_sequence_hi = ESCAPE_SEQUENCE_END_CHARS[new_ascii];

            let is_escape_sequence = possible_escape_sequence_lo
                & possible_escape_sequence_hi
                & ((transcript_capture == KEY_CAPTURE) | (transcript_capture == STRING_CAPTURE));

            if (is_escape_sequence) {
                ascii = ESCAPE_SEQUENCE_REPLACEMENT[new_ascii];
                skip = true;
            }
            // let valid_capture = JSON_CAPTURES[transcript_capture][ascii];

            // let CharData{
            //     valid_search_token,
            //     valid_start_token,
            //     valid_end_token,
            //     valid_value_token,
            //     valid_grammar_token
            // } = get_chardata(0);

            // let valid_search_token = SEARCH_CHARACTERS[ascii as Field];
            // let valid_start_token = START_CHARACTERS[transcript_capture][ascii as Field];
            // let valid_end_token = END_CHARACTERS[transcript_capture][ascii as Field] & !is_escape_sequence;
            // let valid_value_token = VALUE_CHARACTERS[transcript_capture][ascii as Field];

            /*
            valid cases:
                1. searching, valid_search_token = true, valid_start_token = true, valid_grammar_token = true
                2. capture value, valid_value_token = true, valid_end_token = true
            
            transition cases:
                1. searching, valid_start_token = true -> capture
                2. capture, valid_end_token = true -> searching
        
            e.g.
            {
                "key" : 100000 ,
            }
            capture starts when 1 is triggered
            capture ends when whitespace is found


        */

            {
                // println(f"i = {i}");
                // println(f"ascii = {ascii}");
                // println(f"transcript capture = {transcript_capture}");
                // println(f"search_in_progress = {search_in_progress}");
                // println(f"valid_search_token = {valid_search_token}");
                // println(f"valid_start_token = {valid_start_token}");

                let searching_check = search_in_progress & (valid_search_token | valid_start_token);
                let capture_check = capture_in_progress & (valid_value_token | valid_end_token);
                assert(searching_check | capture_check, "invalid token");

                if (search_in_progress & valid_start_token) {
                    capture_field = 0;
                    if CAPTURE_START_INCLUSIVE[transcript_capture] {
                        capture_field = ascii as Field;
                    }
                    if (IS_VALUE_CAPTURE[transcript_capture]) {
                        value_indices[value_ptr] = i as Field + 1 - CAPTURE_START_INCLUSIVE[transcript_capture] as Field;
                        value_ptr += 1;
                    }
                }
                if (capture_in_progress & valid_value_token) {
                    capture_field *= 256;
                    capture_field += ascii as Field;
                }

                if (search_in_progress & valid_start_token) {
                    if (SINGLE_CHARACTER_TOKEN[transcript_capture]) {
                        transcript_ptr += 1;
                    } else {
                        search_in_progress = false;
                        capture_in_progress = true;
                    }
                } else if (capture_in_progress & valid_end_token) {
                    search_in_progress = true;
                    capture_in_progress = false;
                    grammar_token_found = false;
                    // if this is a value

                    if (transcript_capture == KEY_CAPTURE) {
                        let ff = json_keys[key_ptr];
                        println(f"json key val = {ff}");
                        println(f"key capture_field = {capture_field}");
                        assert(
                            capture_field == json_keys[key_ptr], "JSON key does not match expected transcript value!"
                        );
                        key_ptr += 1;
                    }
                    transcript_ptr += 1;

                    if (CAPTURE_START_INCLUSIVE[transcript_capture]) {
                        let mut next_capture = transcript[transcript_ptr];
                        let valid_start_token = START_CHARACTERS[next_capture][ascii as Field];
                        if (valid_start_token) {
                            transcript_ptr += 1;
                        }
                    }
                }

                ascii = new_ascii;
            }
        }
    }
    value_indices
}

fn compute_object_open_tables() {
    let mut result: [Field; 128] = [0; 128];
    for i in 0..128 {
        let escape_start = ESCAPE_SEQUENCE_START_CHARS[i];
        let escape_end = ESCAPE_SEQUENCE_END_CHARS[i];
        let search = SEARCH_CHARACTERS[i];
        let start = OBJECT_OPEN_START_CHARACTERS[i];
        let end = OBJECT_OPEN_END_CHARACTERS[i];
        let value = OBJECT_OPEN_VALUE_CHARACTERS[i];

        let value = escape_start as Field
            + 2 * escape_end as Field
            + 4 * search as Field
            + 8 * start as Field
            + 16 * end as Field
            + 32 * value as Field;
        result[i] = value;
    }
    println(f"global OBJECT_OPEN_BITFLAGS: [Field; 128] = {result}");
}

fn compute_object_close_tables() {
    let mut result: [Field; 128] = [0; 128];
    for i in 0..128 {
        let escape_start = ESCAPE_SEQUENCE_START_CHARS[i];
        let escape_end = ESCAPE_SEQUENCE_END_CHARS[i];
        let search = SEARCH_CHARACTERS[i];
        let start = OBJECT_CLOSE_START_CHARACTERS[i];
        let end = OBJECT_CLOSE_END_CHARACTERS[i];
        let value = OBJECT_CLOSE_VALUE_CHARACTERS[i];

        let value = escape_start as Field
            + 2 * escape_end as Field
            + 4 * search as Field
            + 8 * start as Field
            + 16 * end as Field
            + 32 * value as Field;
        result[i] = value;
    }
    println(f"global OBJECT_CLOSE_BITFLAGS: [Field; 128] = {result}");
}

fn compute_array_open_tables() {
    let mut result: [Field; 128] = [0; 128];
    for i in 0..128 {
        let escape_start = ESCAPE_SEQUENCE_START_CHARS[i];
        let escape_end = ESCAPE_SEQUENCE_END_CHARS[i];
        let search = SEARCH_CHARACTERS[i];
        let start = ARRAY_OPEN_START_CHARACTERS[i];
        let end = ARRAY_OPEN_END_CHARACTERS[i];
        let value = ARRAY_OPEN_VALUE_CHARACTERS[i];

        let value = escape_start as Field
            + 2 * escape_end as Field
            + 4 * search as Field
            + 8 * start as Field
            + 16 * end as Field
            + 32 * value as Field;
        result[i] = value;
    }
    println(f"global ARRAY_OPEN_BITFLAGS: [Field; 128] = {result}");
}

fn compute_array_close_tables() {
    let mut result: [Field; 128] = [0; 128];
    for i in 0..128 {
        let escape_start = ESCAPE_SEQUENCE_START_CHARS[i];
        let escape_end = ESCAPE_SEQUENCE_END_CHARS[i];
        let search = SEARCH_CHARACTERS[i];
        let start = ARRAY_CLOSE_START_CHARACTERS[i];
        let end = ARRAY_CLOSE_END_CHARACTERS[i];
        let value = ARRAY_CLOSE_VALUE_CHARACTERS[i];

        let value = escape_start as Field
            + 2 * escape_end as Field
            + 4 * search as Field
            + 8 * start as Field
            + 16 * end as Field
            + 32 * value as Field;
        result[i] = value;
    }
    println(f"global ARRAY_CLOSE_BITFLAGS: [Field; 128] = {result}");
}

fn compute_comma_tables() {
    let mut result: [Field; 128] = [0; 128];
    for i in 0..128 {
        let escape_start = ESCAPE_SEQUENCE_START_CHARS[i];
        let escape_end = ESCAPE_SEQUENCE_END_CHARS[i];
        let search = SEARCH_CHARACTERS[i];
        let start = COMMA_START_CHARACTERS[i];
        let end = COMMA_END_CHARACTERS[i];
        let value = COMMA_VALUE_CHARACTERS[i];

        let value = escape_start as Field
            + 2 * escape_end as Field
            + 4 * search as Field
            + 8 * start as Field
            + 16 * end as Field
            + 32 * value as Field;
        result[i] = value;
    }
    println(f"global COMMA_BITFLAGS: [Field; 128] = {result}");
}

fn compute_colon_tables() {
    let mut result: [Field; 128] = [0; 128];
    for i in 0..128 {
        let escape_start = ESCAPE_SEQUENCE_START_CHARS[i];
        let escape_end = ESCAPE_SEQUENCE_END_CHARS[i];
        let search = SEARCH_CHARACTERS[i];
        let start = COLON_START_CHARACTERS[i];
        let end = COLON_END_CHARACTERS[i];
        let value = COLON_VALUE_CHARACTERS[i];

        let value = escape_start as Field
            + 2 * escape_end as Field
            + 4 * search as Field
            + 8 * start as Field
            + 16 * end as Field
            + 32 * value as Field;
        result[i] = value;
    }
    println(f"global COLON_BITFLAGS: [Field; 128] = {result}");
}

fn compute_key_tables() {
    let mut result: [Field; 128] = [0; 128];
    for i in 0..128 {
        let escape_start = ESCAPE_SEQUENCE_START_CHARS[i];
        let escape_end = ESCAPE_SEQUENCE_END_CHARS[i];
        let search = SEARCH_CHARACTERS[i];
        let start = KEY_START_CHARACTERS[i];
        let end = KEY_END_CHARACTERS[i];
        let value = KEY_VALUE_CHARACTERS[i];

        let value = escape_start as Field
            + 2 * escape_end as Field
            + 4 * search as Field
            + 8 * start as Field
            + 16 * end as Field
            + 32 * value as Field;
        result[i] = value;
    }
    println(f"global KEY_BITFLAGS: [Field; 128] = {result}");
}

fn compute_string_tables() {
    let mut result: [Field; 128] = [0; 128];
    for i in 0..128 {
        let escape_start = ESCAPE_SEQUENCE_START_CHARS[i];
        let escape_end = ESCAPE_SEQUENCE_END_CHARS[i];
        let search = SEARCH_CHARACTERS[i];
        let start = STRING_START_CHARACTERS[i];
        let end = STRING_END_CHARACTERS[i];
        let value = STRING_VALUE_CHARACTERS[i];

        let value = escape_start as Field
            + 2 * escape_end as Field
            + 4 * search as Field
            + 8 * start as Field
            + 16 * end as Field
            + 32 * value as Field;
        result[i] = value;
    }
    println(f"global STRING_BITFLAGS: [Field; 128] = {result}");
}

fn compute_numeric_tables() {
    let mut result: [Field; 128] = [0; 128];
    for i in 0..128 {
        let escape_start = ESCAPE_SEQUENCE_START_CHARS[i];
        let escape_end = ESCAPE_SEQUENCE_END_CHARS[i];
        let search = SEARCH_CHARACTERS[i];
        let start = NUMERIC_START_CHARACTERS[i];
        let end = NUMERIC_END_CHARACTERS[i];
        let value = NUMERIC_VALUE_CHARACTERS[i];

        let value = escape_start as Field
            + 2 * escape_end as Field
            + 4 * search as Field
            + 8 * start as Field
            + 16 * end as Field
            + 32 * value as Field;
        result[i] = value;
    }
    println(f"global NUMERIC_BITFLAGS: [Field; 128] = {result}");
}

fn compute_bool_tables() {
    let mut result: [Field; 128] = [0; 128];
    for i in 0..128 {
        let escape_start = ESCAPE_SEQUENCE_START_CHARS[i];
        let escape_end = ESCAPE_SEQUENCE_END_CHARS[i];
        let search = SEARCH_CHARACTERS[i];
        let start = BOOL_START_CHARACTERS[i];
        let end = BOOL_END_CHARACTERS[i];
        let value = BOOL_VALUE_CHARACTERS[i];

        let value = escape_start as Field
            + 2 * escape_end as Field
            + 4 * search as Field
            + 8 * start as Field
            + 16 * end as Field
            + 32 * value as Field;
        result[i] = value;
    }
    println(f"global BOOL_BITFLAGS: [Field; 128] = {result}");
}

fn compute_tables() {
    compute_object_open_tables();
    compute_object_close_tables();
    compute_array_open_tables();
    compute_array_close_tables();
    compute_comma_tables();
    compute_colon_tables();
    compute_key_tables();
    compute_string_tables();
    compute_numeric_tables();
    compute_bool_tables();
}
