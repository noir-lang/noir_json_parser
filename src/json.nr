use crate::_comparison_tools::bounds_checker;
use crate::_comparison_tools::bounds_checker::get_validity_flags;
use crate::enums::Layer::{OBJECT_LAYER, ARRAY_LAYER, SINGLE_VALUE_LAYER};
use crate::enums::Token::{
    BEGIN_OBJECT_TOKEN, END_OBJECT_TOKEN, BEGIN_ARRAY_TOKEN, END_ARRAY_TOKEN, KEY_SEPARATOR_TOKEN,
    VALUE_SEPARATOR_TOKEN, STRING_TOKEN, NUMERIC_TOKEN, LITERAL_TOKEN, KEY_TOKEN, NUM_TOKENS,
};
use crate::enums::ScanMode::{GRAMMAR_SCAN, STRING_SCAN, NUMERIC_SCAN, LITERAL_SCAN};
use crate::get_literal::JSONLiteral;
use crate::json_entry::{JSONContextStackEntry, JSONEntry, JSONEntryPacked};
use crate::json_tables::{
    TOKEN_VALIDATION_TABLE, PROCESS_RAW_TRANSCRIPT_TABLE, JSON_CAPTURE_TABLE, TOKEN_FLAGS_TABLE,
    TOKEN_IS_ARRAY_OBJECT_OR_VALUE,
};
use crate::token_flags::TokenFlags;
use crate::transcript_entry::{
    ValidationFlags, TranscriptEntry, RawTranscriptEntry, ScanData, PostProcessScanData,
};

/**
 * @brief records a value in a json blob
 **/
struct JSONValue<let MaxLength: u32> {
    value: BoundedVec<u8, MaxLength>, // raw bytes that constitute the json value entry
    value_type: Field, // either STRING_TOKEN, NUMERIC_TOKEN or LITERAL_TOKEN
}

impl<let MaxLength: u32> JSONValue<MaxLength> {
    fn is_string(self) -> bool {
        self.value_type == STRING_TOKEN
    }
    fn is_number(self) -> bool {
        self.value_type == NUMERIC_TOKEN
    }
    fn is_literal(self) -> bool {
        self.value_type == LITERAL_TOKEN
    }
}

/**
 * @brief It's a JSON struct! Contains the raw and processed information required to extract data from a json blob
 * @description The "root" of the JSON refers to the parent object or array (or a value if the json is just a single value e.g. text = "\"foo\": \"bar\"")
 * @note text that describes just a single JSON value is not yet fully supported. Only use this library for processing objects or arrays for now
 **/
struct JSON<let NumBytes: u32, let NumPackedFields: u32, let MaxNumTokens: u32, let MaxNumValues: u32, let MaxKeyFields: u32> {
    json: [u8; NumBytes], // the raw json bytes
    json_packed: [Field; NumPackedFields], // raw bytes, but packed into 31-byte Field elements
    raw_transcript: [Field; MaxNumTokens], // transcript of json tokens after basic processing
    transcript: [Field; MaxNumTokens], // complete transcript of json tokens
    transcript_length: u32, // how big is the transcript?
    key_data: [Field; MaxNumValues], // description of each key, packed into a Field element
    key_hashes: [Field; MaxNumValues], // a sorted list of key hashes
    unsorted_json_entries_packed: [JSONEntryPacked; MaxNumValues], // a list of all the processed json values (objects, arrays, numerics, literals, strings)
    json_entries_packed: [JSONEntryPacked; MaxNumValues], // a sorted list of all the processed json values (objects, arrays, numerics, literals, strings)
    layer_type_of_root: Field, // is the root an OBJECT_LAYER, ARRAY_LAYER or SINGLE_VALUE_LAYER?
    root_id: Field, // the unique identifier of the root (if an object or array)
    root_index_in_transcript: Field, // location in json_entries_packed of the root
}

/**
 * @brief are two JSON objects equal?
 * @note VERY EXPENSIVE! Currently only used in tests
 **/
impl<let NumBytes: u32, let NumPackedFields: u32, let MaxNumTokens: u32, let MaxNumValues: u32, let MaxKeyFields: u32> std::cmp::Eq for JSON<NumBytes, NumPackedFields, MaxNumTokens, MaxNumValues, MaxKeyFields> {
    fn eq(self, other: Self) -> bool {
        (self.json == other.json)
            & (self.raw_transcript == other.raw_transcript)
            & (self.transcript == other.transcript)
            & (self.transcript_length == other.transcript_length)
            & (self.key_data == other.key_data)
            & (self.key_hashes == other.key_hashes)
            & (self.layer_type_of_root == other.layer_type_of_root)
            & (self.root_id == other.root_id)
            & (self.root_index_in_transcript == other.root_index_in_transcript)
            & (self.json_entries_packed == other.json_entries_packed)
            & (self.json_packed == other.json_packed)
    }
}

// TODO: casting entry_ptr to u16 is kind of expensive when generating witnesses, can we fix?
unconstrained fn __check_entry_ptr_bounds(entry_ptr: Field, max: u32) {
    // n.b. even though this assert is in an unconstrained function, an out of bounds error will be triggered when writing into self.key_data[entry_ptr]
    assert(entry_ptr as u32 < max - 1, "create_json_entries: MaxNumValues limit exceeded!");
}

impl<let NumBytes: u32, let NumPackedFields: u32, let MaxNumTokens: u32, let MaxNumValues: u32, let MaxKeyFields: u32> JSON<NumBytes, NumPackedFields, MaxNumTokens, MaxNumValues, MaxKeyFields> {

    /**
     * @brief pack the json bytes into Field elements, where each Field element represents 31 bytes
     * @description we do this because we need to extract substrings from the json bytes, where the position and length of the substring are witness values.
     *              Doing this on packed Field elements using `slice_string` is cheaper than the direct method of iterating byte-by-byte.
     *              Also, by extracting data at unknown locations exclusively from the packed json, we do not need to represent the raw bytes `self.json` as a ROM table
     *              (which would have an expensive initialization cost of 2*NumBytes gates)
     **/
    fn compute_json_packed(&mut self) {
        let NumWholeLimbs = NumBytes / 31;
        for i in 0..NumWholeLimbs {
            let mut limb: Field = 0;
            for j in 0..31 {
                limb *= 0x100;
                limb += self.json[i * 31 + j] as Field;
            }
            std::as_witness(limb);
            self.json_packed[i] = limb;
        }
        let NumRemainingBytes = NumBytes - NumWholeLimbs * 31;
        let mut limb: Field = 0;
        for j in 0..NumRemainingBytes {
            limb *= 0x100;
            limb += self.json[NumWholeLimbs * 31 + j] as Field;
        }
        for _ in NumRemainingBytes..31 {
            limb *= 0x100;
        }
        std::as_witness(limb);
        self.json_packed[NumWholeLimbs + (NumRemainingBytes == 0) as u32] = limb;
    }

    // TODO: when impl is more mature, merge this into create_json_entries
    fn keyswap(&mut self) {
        // TODO: this won't work if 1st entry is a key!
        let mut current = TranscriptEntry::from_field(self.transcript[0]);
        let mut next: TranscriptEntry = TranscriptEntry::new();

        for i in 0..MaxNumTokens - 1 {
            next = TranscriptEntry::from_field(self.transcript[i + 1]);

            let next_is_key = (next.token == KEY_SEPARATOR_TOKEN) as Field;

            let valid_token = TOKEN_IS_ARRAY_OBJECT_OR_VALUE[current.token];
            assert(
                (valid_token * next_is_key) + (1 - next_is_key) == 1,
                "Cannot find key/value straddling KEY_DELIMITER_TOKEN",
            );

            let old_transcript = self.transcript[i];
            let new_transcript = TranscriptEntry::to_field(
                TranscriptEntry { token: KEY_TOKEN, index: current.index, length: current.length },
            );
            let updated_transcript =
                (new_transcript - old_transcript) * next_is_key + old_transcript;
            self.transcript[i] = updated_transcript;

            current = next;
        }
    }

    /**
     * @brief Once we have processed the json into a transcript of tokens, validate these tokens represent valid JSON!
     * @description To avoid a lot of painful if/else statements, we construct a state transition function out of the lookup table TOKEN_VALIDATION_TABLE
     *              The inputs to TOKEN_VALIDATION_TABLE are:
     *                  1. The current token (at some position `i` i.e. `self.transcript[i])
     *                  2. The previous token (`self.transcript[i-1]`)
     *                  3. The context of the previous token (i.e. is it within an object or an array?)
     *              The lookup table maps these inputs into the following outputs:
     *                  1. Are we moving into a new context? i.e. is current token a `{` or `[` character?
     *                  2. If so, what context are we moving into? (`OBJECT_LAYER` or `ARRAY_LAYER`)
     *                  3. Are we exiting from the current context? i.e. is the current token a `}` or `]` character?
     *                  4. Have we entered an error state? e.g. a `[` token followed by a `,` token would be invalid JSON
     * 
     * @note To shave some gates, we represent the error state in a nonstandard way.
     *       If we have entered an error state, the value of `push_layer` will be 0x1000000
     *       This will then update `depth` to a value that exceeds the size of `parent_layer_stack` (32),
     *       which will trigger an out-of-bounds array access, which creates unsatisfiable constraints
     **/
    fn validate_tokens(self, tokens: [Field; MaxNumTokens]) {
        let mut current_layer = self.layer_type_of_root;
        let mut parent_layer_stack: [Field; 32] = [0; 32];
        let mut depth = 0;
        let mut previous_token = tokens[0];
        let NN = NUM_TOKENS * NUM_TOKENS;

        let is_object = previous_token == BEGIN_OBJECT_TOKEN;
        let is_array = previous_token == BEGIN_ARRAY_TOKEN;

        depth = is_object as Field + is_array as Field;

        // todo is this correct?
        parent_layer_stack[0] = is_object as Field * OBJECT_LAYER + is_array as Field * ARRAY_LAYER;
        assert(
            TOKEN_IS_ARRAY_OBJECT_OR_VALUE[previous_token] == 1,
            "first json token does not describe an object, array or key",
        );

        // 17 gates per iteration?
        for i in 1..MaxNumTokens {
            // 0 gates
            let current_token = tokens[i];

            // 1 gate
            let index = current_layer * (NN as Field)
                + previous_token * (NUM_TOKENS as Field)
                + current_token;

            // 5 gates
            let ValidationFlags { push_layer, push_layer_type_of_root, pop_layer } =
                ValidationFlags::from_field(TOKEN_VALIDATION_TABLE[index]);

            // 3.5 gates
            parent_layer_stack[depth] = current_layer;

            // 1 gate
            // we encode an error flag into `push_layer` by making its value such that `depth` will exceed the size of `parent_layer_stack`
            depth = depth + push_layer - pop_layer;
            std::as_witness(depth);

            // 6.5 gates
            let parent_layer = parent_layer_stack[depth];
            let mut updated_layer = (1 - pop_layer - push_layer);
            std::as_witness(updated_layer);
            updated_layer = updated_layer * current_layer + push_layer_type_of_root;
            std::as_witness(updated_layer);
            updated_layer = updated_layer + parent_layer * pop_layer;
            std::as_witness(updated_layer);
            current_layer = updated_layer;

            previous_token = current_token;
        }
        assert(depth == 0, "validate_tokens: unclosed objects or arrays");
    }

    /**
     * @brief given a processed transcript of json tokens, compute a list of json entries that describes the values within the JSON blob
     * @details a 'value' here is either an Object, Array, String, Numeric or Literal.
     *          e.g. "[ 1, 2, 3 ]" contains 4 values (3 Numeric types and the Array that contains them)
     *
     *          To avoid branches and if statements, we construct a state transition function out of the lookup table TOKEN_FLAGS_TABLE
     *          This table takes as an input the following:
     *              1. The token value of an element in the transcript
     *              2. The layer type the previous token is located in (i.e. are we in an array or an object?)
     *          The table outputs the following data:
     *              1. Should we create a new json entry? (i.e. is the token a STRING_TOKEN, LITERAL_TOKEN, NUMERIC_TOKEN, END_ARRAY_TOKEN, END_OBJECT_TOKEN)
     *              2. Is the token `}` or `]`?
     *              3. Is the token `{` or `[`?
     *              4. Given the current layer type and the token being queried, what should the new layer type be?
     *              5. Is the token `KEY_TOKEN`?
     *              6. Is the token a `STRING_TOKEN`, `NUMERIC_TOKEN` OR `VALUE_TOKEN`?
     *              7. Is the token one that we should skip over? `,` or `:`
     **/
    fn create_json_entries(&mut self) {
        let mut entry_ptr = 0;
        let mut depth: Field = 1;
        let mut num_entries_at_current_depth: Field = 0;
        let mut next_identity_value: Field = 1;
        let mut current_identity_value: Field = 0;
        let mut context = OBJECT_LAYER;

        let mut current_key_index_and_length: Field = 0;

        let mut parent_context_stack: [Field; 32] = [0; 32];
        let mut tokens: [Field; MaxNumTokens] = [0; MaxNumTokens];
        //  maybe 71.75 gates per iteration
        for i in 0..MaxNumTokens {
            __check_entry_ptr_bounds(entry_ptr, MaxNumValues);
            // 5.25 gates
            let TranscriptEntry { token, index, length } =
                TranscriptEntry::from_field(self.transcript[i]);

            tokens[i] = token;
            // 13 gates
            let TokenFlags {
    create_json_entry,
    is_end_of_object_or_array,
    is_start_of_object_or_array,
    new_context,
    is_key_token: update_key,
    is_value_token,
    preserve_num_entries,} =
                TokenFlags::from_field(TOKEN_FLAGS_TABLE[token + context * (NUM_TOKENS as Field)]);

            // 2 gates
            let diff = (index + length * 0x10000) - current_key_index_and_length;
            std::as_witness(diff);
            current_key_index_and_length = diff * update_key + current_key_index_and_length;
            std::as_witness(current_key_index_and_length);

            // 2 gates
            let new_context_stack_entry = JSONContextStackEntry::to_field(
                JSONContextStackEntry {
                    num_entries: num_entries_at_current_depth,
                    context,
                    current_key_index_and_length,
                    json_index: index,
                    current_identity: current_identity_value,
                },
            );
            // subtotal 22.25
            // 1 gate
            let depth_index: Field = (depth - 1);
            // 3.5 gates
            let previous_stack_entry_packed = parent_context_stack[depth_index];

            // 9.5 gates
            let previous_stack_entry =
                JSONContextStackEntry::from_field(previous_stack_entry_packed);

            let object_or_array_entry: JSONEntry = JSONEntry {
                array_pointer: previous_stack_entry.num_entries,
                entry_type: token,
                child_pointer: 0,
                num_children: num_entries_at_current_depth,
                json_pointer: previous_stack_entry.json_index,
                json_length: length,
                parent_index: previous_stack_entry.current_identity,
                id: current_identity_value,
            };
            // 0
            let value_entry: JSONEntry = JSONEntry {
                array_pointer: num_entries_at_current_depth,
                entry_type: token,
                child_pointer: 0,
                num_children: 0,
                json_pointer: index,
                json_length: length,
                parent_index: current_identity_value,
                id: 0,
            };

            // 3 gates
            let object_or_array_entry_packed = object_or_array_entry.to_field();
            // 2 gates
            let value_entry_packed = value_entry.to_field();

            // 2 gates
            let diff = object_or_array_entry_packed - value_entry_packed;
            std::as_witness(diff);
            let new_entry = diff * is_end_of_object_or_array + value_entry_packed;
            std::as_witness(new_entry);

            // 3 gates
            // subtotal 24 + 22.25 = 46.25
            let old = current_identity_value;
            current_identity_value = (next_identity_value * is_start_of_object_or_array);
            std::as_witness(current_identity_value);
            current_identity_value = current_identity_value
                + (previous_stack_entry.current_identity * is_end_of_object_or_array);
            std::as_witness(current_identity_value);
            current_identity_value = current_identity_value + old * preserve_num_entries;
            std::as_witness(current_identity_value);

            // 2 gates
            num_entries_at_current_depth =
                num_entries_at_current_depth * preserve_num_entries + is_value_token;
            std::as_witness(num_entries_at_current_depth);
            num_entries_at_current_depth = num_entries_at_current_depth
                + (previous_stack_entry.num_entries + 1) * is_end_of_object_or_array;
            std::as_witness(num_entries_at_current_depth);

            // 1 gate
            // if `is_end_of_object_or_array == 1`, `new_context = 0` so we can do something cheaper than a conditional select:
            context = previous_stack_entry.context * is_end_of_object_or_array + new_context;
            std::as_witness(context);
            // 3 gates
            let common_term = current_identity_value
                + context * (num_entries_at_current_depth - 1) * 0x1000000000000;
            std::as_witness(common_term);
            let mut new_key_data =
                current_key_index_and_length * is_value_token * 0x10000 + common_term;
            std::as_witness(new_key_data);
            new_key_data = new_key_data
                + previous_stack_entry.current_key_index_and_length
                    * is_end_of_object_or_array
                    * 0x10000;
            std::as_witness(new_key_data);

            // 3.5 gates
            self.key_data[entry_ptr] = new_key_data * create_json_entry;

            // 3.5 gates
            parent_context_stack[depth] = new_context_stack_entry;

            // 4.5 gates
            self.json_entries_packed[entry_ptr] =
                JSONEntryPacked { value: new_entry * create_json_entry };

            // 1 gate
            next_identity_value = next_identity_value + is_start_of_object_or_array;
            std::as_witness(next_identity_value);

            // 1 gate
            depth = depth + is_start_of_object_or_array - is_end_of_object_or_array;

            // 1 gate
            // 2105 + 46.25
            // subtotal 66.75?
            entry_ptr += create_json_entry;
            std::as_witness(entry_ptr);
        }
        self.validate_tokens(tokens);
    }

    /**
     * @brief Perform the 1st transcript processing step as an unconstrained function
     *        We will validate this transcript is correct via a constrained function
     *        This is a bit cheaper than doing everything in a constrained function,
     *        because we can use ROM arrays instead of RAM arrays
     *        (i.e. we're only reading from our arrays, we don't write to them in constrained functions)
     **/
    unconstrained fn __build_transcript(self) -> [Field; MaxNumTokens] {
        let mut raw_transcript: [Field; MaxNumTokens] = [0; MaxNumTokens];
        let mut transcript_ptr: u32 = 0;
        let mut scan_mode = GRAMMAR_SCAN as Field;
        let mut length: Field = 0;
        let mut previous_was_potential_escape_sequence = 0;
        for i in 0..NumBytes {
            // while this assert is in an unconstrained function, the out of bounds accesss `raw_transcript[transcript_ptr]` in build_transcript also generates failing constraints
            assert(transcript_ptr < MaxNumTokens, "build_transcript: MaxNumTokens limit exceeded!");
            let ascii = self.json[i];

            let encoded_ascii =
                previous_was_potential_escape_sequence * 1024 + scan_mode * 256 + ascii as Field;
            let ScanData { scan_token, push_transcript, increase_length, is_potential_escape_sequence } =
                ScanData::from_field(JSON_CAPTURE_TABLE[encoded_ascii]);
            let mut push_transcript = push_transcript;
            let mut scan_token = scan_token;
            let mut increase_length = increase_length;

            let new_entry = RawTranscriptEntry::to_field(
                RawTranscriptEntry { encoded_ascii, index: i as Field - length, length },
            );

            raw_transcript[transcript_ptr] = new_entry;
            length = length * (1 - push_transcript) + increase_length;
            transcript_ptr += (push_transcript as bool) as u32;

            previous_was_potential_escape_sequence = is_potential_escape_sequence;

            scan_mode = scan_token;
        }

        // ensure an error isn't hiding in the last scanned token
        scan_mode.assert_max_bit_size::<2>();
        raw_transcript
    }

    /**
     * @brief Construct a token transcript by iterating through self.json and using a lookup table `JSON_CAPTURE_TABLE` to define a state transition function
     * @details JSON_CAPTURE_TABLE takes the following as input:
     *          1. the ascii byte at the current location in the json
     *          2. the current scan mode (are we searching for grammar, strings, numbers or literals?)
     *          3. could this byte potentially be an escape sequence? (i.e. the previous byte was a backslash character "\" and scan_mode == STRING_SCAN)
     *          The table outputs the following flags:
     *          1. what token have we scanned? (listed in enums::Token)
     *          2. should we push this token to the transcript (no push if token == NO_TOKEN)
     *          3. should we increase the length of the current entry we're evaluating?
     *              (i.e. if token == STRING_TOKEN and scan_mode == STRING_SCAN, then increase the length because we're in the process of scanning a string)
     *          4. is this scanned ascii character a potential escape sequence? i.e. scan_mode == STRING_SCAN and ascii = "\"
     *          5. have we entered an error state? (i.e. invalid grammar e.g. ":" is followed by "}")
     *
     * NOTE: we represent error states in a nonstandard way to reduce gate count. Instead of handling an error flag,
     *       an error state will increase the value of `scan_token` by 0x100000000. This will cause the next access into `JSON_CAPTURE_TABLE` to trigger an out of bounds error
     *
     * NOTE: the scanned transcript will be missing some edge cases that are caught via `swap_keys` and `capture_missing_tokens`:
     *          1. If the scan mode is NUMERIC_SCAN or LITERAL_SCAN and the next character is a "," or "}" or "]",
     *             we will push a NUMERIC_TOKEN or LITERAL_TOKEN into the transcript but we will MISS the VALUE_SEPARATOR_TOKEN, END_OBJECT_TOKEN or END_ARRAY_TOKEN
     *             (accomodating this edge case requires conditionally pushing two transcript entries per iteration, so we do this in a separate step where we iterate over the transcript and not the json bytes)
     *          2. We can't yet tell if an entry is a KEY_TOKEN or a STRING_TOKEN. All keys are represented as STRING_TOKEN. This gets fixed after `swap_keys` is evaluated
     **/
    fn build_transcript(self) -> Self {
        let mut raw_transcript: [Field; MaxNumTokens] = [0; MaxNumTokens];
        let mut transcript_ptr: Field = 0;
        let mut scan_mode = GRAMMAR_SCAN;
        let mut length: Field = 0;

        let raw_transcript = self.__build_transcript();

        // 14 gates per iteration, plus fixed cost for initing 2,048 size lookup table (4,096 gates)
        let mut previous_was_potential_escape_sequence = 0;
        for i in 0..NumBytes {
            let ascii = self.json[i];

            // 1 gate
            let encoded_ascii =
                previous_was_potential_escape_sequence * 1024 + scan_mode * 256 + ascii as Field;
            std::as_witness(encoded_ascii);

            // 2 gates
            let capture_flags = JSON_CAPTURE_TABLE[encoded_ascii];
            // 5 gates
            let ScanData { scan_token, push_transcript, increase_length, is_potential_escape_sequence } =
                ScanData::from_field(capture_flags);

            // 2 gates
            let raw = raw_transcript[transcript_ptr];

            // 1 gate
            let diff = raw
                - RawTranscriptEntry::to_field(
                    RawTranscriptEntry { encoded_ascii, index: i as Field - length, length },
                );
            std::as_witness(diff);
            // 1 gate
            assert(diff * push_transcript == 0);

            // 1 gate
            length = length * (1 - push_transcript) + increase_length;
            std::as_witness(length);

            // 1 gate
            transcript_ptr += push_transcript;

            previous_was_potential_escape_sequence = is_potential_escape_sequence;
            scan_mode = scan_token;
        }

        // we encode error flag into the scan_token value, which must be less than 4
        // the lookup into JSON_CAPTURE_TABLE applies an implicit 2-bit range check on `scan_token`
        // however this does not get triggered if the final byte scanned produces an error state
        length.assert_max_bit_size::<2>();

        JSON {
            json: self.json,
            raw_transcript,
            transcript: self.transcript,
            transcript_length: transcript_ptr as u32,
            key_data: self.key_data,
            key_hashes: self.key_hashes,
            layer_type_of_root: self.layer_type_of_root,
            root_id: 1,
            root_index_in_transcript: 0,
            json_entries_packed: self.json_entries_packed,
            unsorted_json_entries_packed: self.unsorted_json_entries_packed,
            json_packed: self.json_packed,
        }
    }

    /**
     * @brief We compute the output of `capture_missing_tokens` via an unconstrained function, then validate the result is correct.
     *        Saves some gates for same reason as in __build_transcript
     **/
    unconstrained fn __capture_missing_tokens(self) -> [Field; MaxNumTokens] {
        let mut updated_transcript: [Field; MaxNumTokens] = [0; MaxNumTokens];
        let mut transcript_ptr: u32 = 0;
        // TODO: do we need a null transcript value?!?!
        for i in 0..MaxNumTokens {
            let RawTranscriptEntry { encoded_ascii, index, length } =
                RawTranscriptEntry::from_field(self.raw_transcript[i]);

            let PostProcessScanData { token, new_grammar, scan_token } =
                PostProcessScanData::from_field(PROCESS_RAW_TRANSCRIPT_TABLE[encoded_ascii]);

            let entry = TranscriptEntry::to_field(TranscriptEntry { token, index, length });
            updated_transcript[transcript_ptr] = entry;

            let index_valid: u32 = (i < self.transcript_length) as u32;
            transcript_ptr += index_valid;

            let index_of_possible_grammar = (index + length);
            let new_entry =
                TranscriptEntry { token: scan_token, index: index_of_possible_grammar, length: 0 };

            let update = new_grammar * index_valid as Field;
            let new_transcript = TranscriptEntry::to_field(new_entry);
            assert(
                transcript_ptr < MaxNumTokens,
                "capture_missing_tokens: MaxNumTokens limit exceeded!",
            );
            updated_transcript[transcript_ptr] = new_transcript;
            transcript_ptr += update as bool as u32;
        }
        updated_transcript
    }

    /**
     * @brief Check for missing tokens that we could have missed in `build_transcript`
     * @details If we had a json string where a NUMERIC_TOKEN or LITERAL_TOKEN is directly succeeded by a VALUE_SEPARATOR_TOKEN, END_OBJECT_TOKEN, END_ARRAY_TOKEN,
     *          we will have missed the latter token.
     *          We pick these up via the lookup table PROCESS_RAW_TRANSCRIPT_TABLE
     **/
    fn capture_missing_tokens(&mut self) {
        let mut transcript_ptr: Field = 0;
        // hmm probably need a null transcript value?!?!
        let updated_transcript = self.__capture_missing_tokens();
        // 26? gates per iteration
        let range_valid: [Field; MaxNumTokens] = get_validity_flags(self.transcript_length);
        for i in 0..MaxNumTokens {
            // 5.25 gates
            let RawTranscriptEntry { encoded_ascii, index, length } =
                RawTranscriptEntry::from_field(self.raw_transcript[i]);
            // 6.75 gates
            let PostProcessScanData { token, new_grammar, scan_token } =
                PostProcessScanData::from_field(PROCESS_RAW_TRANSCRIPT_TABLE[encoded_ascii]);
            // 2 gates
            let index_valid: Field = range_valid[i];
            // 1 gate
            let entry = TranscriptEntry::to_field(TranscriptEntry { token, index, length });
            // 2 gates
            let diff = updated_transcript[transcript_ptr] - entry;
            std::as_witness(diff);
            assert(diff * index_valid == 0);
            // 1 gate
            transcript_ptr += index_valid;
            // 0 gate (merged into TranscriptEntry::to_field)
            let index_of_possible_grammar = (index + length);
            // 0 gates
            let new_entry =
                TranscriptEntry { token: scan_token, index: index_of_possible_grammar, length: 0 };
            // 2 gates
            let update = new_grammar as Field * index_valid;
            std::as_witness(update);
            // 1 gate
            let new_transcript = TranscriptEntry::to_field(new_entry);
            // 4 gates
            let diff = updated_transcript[transcript_ptr] - new_transcript;
            std::as_witness(diff);
            assert(diff * update == 0);
            // 1 gate
            transcript_ptr += update;
        }
        self.transcript = updated_transcript;

        // TODO we could make this more efficient...probably not a big deal though
        let first = TranscriptEntry::from_field(self.transcript[0]);
        if (first.token == BEGIN_OBJECT_TOKEN) {
            self.layer_type_of_root = OBJECT_LAYER;
        } else if (first.token == BEGIN_ARRAY_TOKEN) {
            self.layer_type_of_root = ARRAY_LAYER;
        } else if (first.token == STRING_TOKEN) {
            self.layer_type_of_root = SINGLE_VALUE_LAYER as Field;
        }
    }

    fn parse_json<let StringBytes: u32>(stringbytes: [u8; StringBytes]) -> Self {
        assert(StringBytes <= NumBytes, "json length exceeds NumBytes!");
        let mut text: [u8; NumBytes] = [0; NumBytes];
        for i in 0..StringBytes {
            text[i] = stringbytes[i];
        }
        for i in StringBytes..NumBytes {
            text[i] = 32; // whitespace character
        }
        let mut json = JSON {
            json: text,
            raw_transcript: [0; MaxNumTokens],
            transcript: [0; MaxNumTokens],
            transcript_length: 0,
            key_data: [0; MaxNumValues],
            key_hashes: [0; MaxNumValues],
            layer_type_of_root: 0,
            root_id: 1,
            root_index_in_transcript: 0,
            json_entries_packed: [JSONEntryPacked::default(); MaxNumValues],
            unsorted_json_entries_packed: [JSONEntryPacked::default(); MaxNumValues],
            json_packed: [0; NumPackedFields],
        };

        json = json.build_transcript();
        json.capture_missing_tokens();
        json.keyswap();
        json.compute_json_packed();
        json.create_json_entries();

        json.compute_keyhash_and_sort_json_entries();

        json
    }

    fn parse_json_from_string<let StringBytes: u32>(s: str<StringBytes>) -> Self {
        JSON::parse_json(s.as_bytes())
    }
}

// TODO: our capture tables are not correctly set up to process a JSON blob that does not begin with an object or array
// #[test]
// fn test_single_value() {
//     let text = "100";
//     let mut json: JSON<3, 10, 20, 20> = JSON::parse_json_from_string(text);
//
//     assert(json.get_length() == 0);
//     assert(json.get_array_element_as_number(0) == 100);
// }

#[test]
fn test_numbers() {
    let text = "{ \"a\": 9, \"b\": 99, \"c\": 999, \"d\": 9999, \"e\": 99999, \"f\": 999999, \"g\": 9999999, \"h\": 99999999, \"i\": 999999999, \"j\": 9999999999, \"k\": 99999999999, \"l\": 999999999999, \"m\": 9999999999999, \"n\": 99999999999999, \"o\": 999999999999999, \"p\": 999999999999999,\"q\": 9999999999999999, \"r\": 99999999999999999, \"s\": 999999999999999999, \"t\": 9999999999999999999, \"u\": 18446744073709551615}";
    let mut json: JSON<372, 16, 100, 24, 2> = JSON::parse_json_from_string(text);

    let a = json.get_number_unchecked("a".as_bytes());
    let b = json.get_number_unchecked("b".as_bytes());
    let c = json.get_number_unchecked("c".as_bytes());
    let d = json.get_number_unchecked("d".as_bytes());
    let e = json.get_number_unchecked("e".as_bytes());
    let f = json.get_number_unchecked_var(BoundedVec { storage: "ftrololol".as_bytes(), len: 1 });
    let g = json.get_number("g".as_bytes()).unwrap();
    let h = json.get_number_var(BoundedVec { storage: "h".as_bytes(), len: 1 }).unwrap();
    let i = json.get_number_unchecked("i".as_bytes());
    let j = json.get_number_unchecked("j".as_bytes());
    let k = json.get_number_unchecked("k".as_bytes());
    let l = json.get_number_unchecked("l".as_bytes());
    let m = json.get_number_unchecked("m".as_bytes());
    let n = json.get_number_unchecked("n".as_bytes());
    let o = json.get_number_unchecked("o".as_bytes());
    let p = json.get_number_unchecked("p".as_bytes());
    let q = json.get_number_unchecked("q".as_bytes());
    let r = json.get_number_unchecked("r".as_bytes());
    let s = json.get_number_unchecked("s".as_bytes());
    let t = json.get_number_unchecked("t".as_bytes());
    let u = json.get_number_unchecked("u".as_bytes());

    assert(a == 9);
    assert(b == 99);
    assert(c == 999);
    assert(d == 9999);
    assert(e == 99999);
    assert(f == 999999);
    assert(g == 9999999);
    assert(h == 99999999);
    assert(i == 999999999);
    assert(j == 9999999999);
    assert(k == 99999999999);
    assert(l == 999999999999);
    assert(m == 9999999999999);
    assert(n == 99999999999999);
    assert(o == 999999999999999);
    assert(p == 999999999999999);
    assert(q == 9999999999999999);
    assert(r == 99999999999999999);
    assert(s == 999999999999999999);
    assert(t == 9999999999999999999);
    assert(u == 18446744073709551615);
}

#[test]
fn test_parent_array() {
    let text = "[0,10,21,32,44]";
    let mut json: JSON<15, 10, 20, 20, 2> = JSON::parse_json_from_string(text);
    assert(json.get_length() == 5);
    assert(json.get_number_from_array_unchecked(0) == 0);
    assert(json.get_number_from_array_unchecked(1) == 10);
    assert(json.get_number_from_array_unchecked(2) == 21);
    assert(json.get_number_from_array_unchecked(3) == 32);
    assert(json.get_number_from_array_unchecked(4) == 44);
}

#[test]
fn test_escaped_strings() {
    let text = "{   \"name\": \"\\\"Ade\\nel Solangi\\\"\", \"testA\": false, \"testB\": true, \"testC\": null }                                                                   ";
    let mut json: JSON<148, 10, 20, 20, 2> = JSON::parse_json_from_string(text);
    let result: BoundedVec<u8, 19> = json.get_string_unchecked("name".as_bytes());
    assert(result.storage == BoundedVec::from_array("\"Ade\nel Solangi\"".as_bytes()).storage);
    assert(result.len == 16);
}

#[test]
fn test_parse_json() {
    let text = "{ \"foo\": 1234, \"bar\": { \"foo\": 9876, \"bar\": true }, \"baz\": \"hello\" }";
    let mut json: JSON<68, 7, 30, 30, 2> = JSON::parse_json_from_string(text);

    let result = json.get_string_unchecked("baz".as_bytes());
    assert(result.storage == "hello".as_bytes());

    let result: Option<BoundedVec<u8, 5>> = json.get_string("baz".as_bytes());
    assert(result.is_some());
    assert(result.unwrap().storage == "hello".as_bytes());

    let result: Option<BoundedVec<u8, 1>> = json.get_string("wibble".as_bytes());
    assert(result.is_some() == false);

    let result: u64 = json.get_number_unchecked("foo".as_bytes());
    assert(result == 1234);

    let result: Option<u64> = json.get_number("foo".as_bytes());
    assert(result.is_some());
    assert(result.unwrap() == 1234);

    let result: Option<u64> = json.get_number("fooo".as_bytes());
    assert(result.is_some() == false);

    let mut nested_json = json.get_object("bar".as_bytes()).unwrap();
    let result: Option<u64> = nested_json.get_number_var(
        BoundedVec { storage: "foounusedkeybyteslolol".as_bytes(), len: 3 },
    );
    assert(result.is_some() == true);
    assert(result.unwrap() == 9876);

    let key0: BoundedVec<u8, 3> = BoundedVec::from_array("bar".as_bytes());
    let key1: BoundedVec<u8, 3> = BoundedVec::from_array("baz".as_bytes());

    let result: Option<BoundedVec<u8, 10>> = json.get_string_from_path([key0, key1]);
    assert(result.is_some() == false);
}

#[test]
fn test_literal() {
    let text = "{   \"name\": \"Adeel Solangi\", \"testA\": false, \"testB\": true, \"testC\": null }                                                                   ";
    let mut json: JSON<142, 10, 20, 20, 2> = JSON::parse_json_from_string(text);

    let result: JSONLiteral = json.get_literal_unchecked("testA".as_bytes());
    assert(result.is_false() == true);
    assert(result.is_true() == false);
    assert(result.is_null() == false);
    assert(result.to_bool() == false);

    let result_option: Option<JSONLiteral> = json.get_literal("testA".as_bytes());
    assert(result_option.is_some());
    assert(result_option.unwrap().value == result.value);
}

#[test]
fn test_arrays() {
    let text = "{   \"name\": \"Adeel Solangi\", \"age\": 62, \"portfolio\": { \"vibe_ratings\": [1,2],\"elemental_lorem\": false }}                                                 ";
    let mut json: JSON<153, 10, 60, 60, 2> = JSON::parse_json_from_string(text);

    assert(json.key_exists(BoundedVec { storage: "foo".as_bytes(), len: 3 }) == false);
    assert(json.key_exists(BoundedVec { storage: "name".as_bytes(), len: 4 }));
    assert(json.key_exists(BoundedVec { storage: "age".as_bytes(), len: 3 }));
    assert(json.key_exists(BoundedVec { storage: "portfolio".as_bytes(), len: 9 }));
}

#[test(should_fail_with = "build_transcript: MaxNumTokens limit exceeded!")]
fn test_json_not_enough_tokens_fails() {
    let text = "{ \"hello \": \"world\" }";
    let _: JSON<26, 10, 2, 20, 2> = JSON::parse_json_from_string(text);
}

#[test(should_fail_with = "capture_missing_tokens: MaxNumTokens limit exceeded!")]
fn test_json_not_enough_tokens_fails_2() {
    // we should exceed the limit of 8 tokens here, when capturing the `,` token missed by build_transcript
    let text = "{ \"hello \": false,\"world\": true }";
    let _: JSON<33, 10, 8, 20, 2> = JSON::parse_json_from_string(text);
}

#[test(should_fail_with = "create_json_entries: MaxNumValues limit exceeded!")]
fn test_json_not_enough_values_fails() {
    let text = "{ \"hello \": false,\"world\": true }";
    let _: JSON<33, 10, 10, 4, 2> = JSON::parse_json_from_string(text);
}

#[test(should_fail_with = "ValidationFlags: grammar error")]
fn test_json_object_without_key_fails() {
    let text = "{ \"hello \": \"world\", 100 }";
    let _: JSON<26, 10, 20, 20, 2> = JSON::parse_json_from_string(text);
}

#[test(should_fail_with = "ValidationFlags: grammar error")]
fn test_json_array_with_key_fails() {
    let text = "[ \"hello \": \"world\" ]";
    let _: JSON<26, 10, 20, 20, 2> = JSON::parse_json_from_string(text);
}

#[test(should_fail_with = "ValidationFlags: grammar error")]
fn test_json_unclosed_object_fails() {
    let text = "{ \"hello \": \"world\" ";
    let _: JSON<26, 10, 20, 20, 2> = JSON::parse_json_from_string(text);
}

#[test(should_fail_with = "ValidationFlags: grammar error")]
fn test_json_object_closed_with_array_fails() {
    let text = "{ \"hello \": \"world\" ]";
    let _: JSON<26, 10, 20, 20, 2> = JSON::parse_json_from_string(text);
}

#[test(should_fail_with = "ValidationFlags: grammar error")]
fn test_json_object_with_trailing_comma_fails() {
    let text = "{ \"hello \" : \"world\", }";
    let _: JSON<26, 10, 20, 20, 2> = JSON::parse_json_from_string(text);
}

#[test(should_fail_with = "ValidationFlags: grammar error")]
fn test_json_unclosed_array_fails() {
    let text = "[ \"hello \", \"world\"";
    let _: JSON<19, 10, 20, 20, 2> = JSON::parse_json_from_string(text);
}

#[test(should_fail_with = "validate_tokens: unclosed objects or arrays")]
fn test_json_unclosed_array_fails_2() {
    let text = "[ \"hello \", \"world\", [1,2,3,4] ";
    let _: JSON<31, 10, 20, 20, 2> = JSON::parse_json_from_string(text);
}

#[test(should_fail_with = "ValidationFlags: grammar error")]
fn test_json_array_with_trailing_comma_fails() {
    let text = "[ \"hello \", \"world\", ]";
    let _: JSON<26, 10, 20, 20, 2> = JSON::parse_json_from_string(text);
}

#[test(should_fail_with = "ValidationFlags: grammar error")]
fn test_json_array_closed_with_object_fails() {
    let text = "[ \"hello \": \"world\" }";
    let _: JSON<26, 10, 20, 20, 2> = JSON::parse_json_from_string(text);
}

#[test(should_fail_with = "ScanData: Invalid token")]
fn test_json_key_not_wrapped_in_quotes_fails() {
    let text = "{ false: \"world\" }";
    let _: JSON<26, 10, 20, 20, 2> = JSON::parse_json_from_string(text);
}

#[test(should_fail_with = "ScanData: Invalid token")]
fn test_json_string_not_wrapped_in_quotes_fails() {
    let text = "{ \"hello \": world }";
    let _: JSON<26, 10, 20, 20, 2> = JSON::parse_json_from_string(text);
}

#[test(should_fail_with = "ScanData: Invalid token")]
fn test_json_char_outside_of_string_fails() {
    let text = "{ \"hello \", \"world\" a}";
    let _: JSON<26, 10, 20, 20, 2> = JSON::parse_json_from_string(text);
}

#[test(should_fail_with = "ValidationFlags: grammar error")]
fn test_json_char_outside_of_string_fails_2() {
    // n could be the start of the literal "null", so this passes the ScanData check but fails ValidationFlags
    let text = "{ \"hello \", \"world\" n}";
    let _: JSON<26, 10, 20, 20, 2> = JSON::parse_json_from_string(text);
}

#[test(should_fail_with = "ValidationFlags: grammar error")]
fn test_json_array_with_invalid_tokens_fails() {
    // n could be the start of the literal "null", so this passes the ScanData check but fails ValidationFlags
    let text = "[,,,]";
    let _: JSON<26, 10, 20, 20, 2> = JSON::parse_json_from_string(text);
}

#[test(should_fail_with = "Cannot find key/value straddling KEY_DELIMITER_TOKEN")]
fn test_json_object_with_invalid_tokens_fails() {
    // n could be the start of the literal "null", so this passes the ScanData check but fails ValidationFlags
    let text = "{:::}";
    let _: JSON<26, 10, 20, 20, 2> = JSON::parse_json_from_string(text);
}

#[test]
fn test_json_empty_object_passes() {
    // n could be the start of the literal "null", so this passes the ScanData check but fails ValidationFlags
    let text = "{}";
    let _: JSON<26, 10, 20, 20, 2> = JSON::parse_json_from_string(text);
}

#[test]
fn test_json_empty_array_passes() {
    // n could be the start of the literal "null", so this passes the ScanData check but fails ValidationFlags
    let text = "[]";
    let _: JSON<26, 10, 20, 20, 2> = JSON::parse_json_from_string(text);
}

