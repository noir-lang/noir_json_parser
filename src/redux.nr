global GRAMMAR_SCAN = 0;
global STRING_SCAN = 1;
global NUMERIC_SCAN = 2;
global LITERAL_SCAN = 3;

global OBJECT_OPEN = 0;
global OBJECT_CLOSE = 1;
global ARRAY_OPEN = 2;
global ARRAY_CLOSE = 3;
global KEY_DELIMITER = 4;
global VALUE_DELIMITER = 5;
global KEY = 6;
global STRING  = 7;
global NUMERIC = 8;
global LITERAL = 9;

global OBJECT_TYPE = 0;
global ARRAY_TYPE = 1;
global STRING_TYPE = 2;
global NUMBER_TYPE = 3;
global LITERAL_TYPE = 4;

use crate::token_flags::TokenFlags;
use crate::getters;
use crate::get_literal::JSONLiteral;
use crate::test_data::JSON_WITH_ARRAYS;
use dep::noir_sort;
use crate::transcript_entry::{ValidationFlags, TranscriptEntry, RawTranscriptEntry, ScanData, PostProcessScanData};
use crate::json_entry::{JSONContextStackEntry, JSONEntry};
use crate::keymap;
use crate::redux_tables::{
    TOKEN_VALIDATION_TABLE, OBJECT_CONTEXT, ARRAY_CONTEXT, PROCESS_RAW_TRANSCRIPT_TABLE,
    REDUCED_CAPTURE_TABLE, TOKEN_FLAGS_TABLE, CAPTURE_TABLE_ENCODED_FLAT, NUM_TOKENS,
    TOKEN_IS_ARRAY_OBJECT_OR_VALUE, TOKEN_IS_NUMERIC_OR_LITERAL, OBJECT_LAYER, ARRAY_LAYER,
    SINGLE_VALUE_LAYER, BEGIN_OBJECT_TOKEN, END_OBJECT_TOKEN, BEGIN_ARRAY_TOKEN, END_ARRAY_TOKEN,
    KEY_SEPARATOR_TOKEN, VALUE_SEPARATOR_TOKEN, STRING_TOKEN, NUMERIC_TOKEN, LITERAL_TOKEN, KEY_TOKEN
};

use crate::keymap::KeyIndexData;

struct JSON<let NumBytes: u32, let NumPackedFields: u16, let MaxNumTokens: u16, let MaxNumValues: u16> {
    json: [u8; NumBytes],
    raw_transcript: [Field; MaxNumTokens],
    transcript: [Field; MaxNumTokens],
    transcript_length: u16,
    key_data: [Field; MaxNumValues], // todo make smaller? somehow? urgh
    key_hashes: [Field; MaxNumValues],
    layer_id: Field,
    root_id: Field,
    layer_context: Field, // is the current layer an OBJECT_LAYER, ARRAY_LAYER or SINGLE_VALUE_LAYER
    layer_index_in_transcript: Field,
    packed_json_entries: [Field; MaxNumValues],
    packed_json: [Field; NumPackedFields]
}

impl<let NumBytes: u16, let NumPackedFields: u16, let MaxNumTokens: u16, let MaxNumValues: u16> std::cmp::Eq for JSON<NumBytes, NumPackedFields, MaxNumTokens, MaxNumValues> {

    fn eq(self, other: Self) -> bool {
        (self.json == other.json) & (self.raw_transcript == other.raw_transcript)
        & (self.transcript_length == other.transcript_length)
        & (self.key_data == other.key_data)
        & (self.key_hashes == other.key_hashes)
        & (self.layer_id == other.layer_id)
        & (self.root_id == other.root_id)
        & (self.layer_context == other.layer_context)
        & (self.layer_index_in_transcript == other.layer_index_in_transcript)
        & (self.packed_json_entries == other.packed_json_entries)
        & (self.packed_json == other.packed_json)
    }
}
impl<let NumBytes: u16, let NumPackedFields: u16, let MaxNumTokens: u16, let MaxNumValues: u16> JSON<NumBytes, NumPackedFields, MaxNumTokens, MaxNumValues> {

    fn compute_packed_json(&mut self) {
        let NumWholeLimbs = NumBytes / 31;
        for i in 0..NumWholeLimbs {
            let mut limb: Field = 0;
            for j in 0..31 {
                limb *= 0x100;
                limb += self.json[i * 31 + j] as Field;
            }
            std::as_witness(limb);
            self.packed_json[i] = limb;
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
        self.packed_json[NumWholeLimbs + (NumRemainingBytes == 0) as u16] = limb;
    }

    // TODO: when impl is more mature, merge this into create_json_entries
    fn keyswap(&mut self) {
        // TODO: this won't work if 1st entry is a key!
        let mut current= TranscriptEntry::from_field(self.transcript[0]);
        let mut next: TranscriptEntry = TranscriptEntry::new();

        for i in 0..MaxNumTokens - 1 {
            next = TranscriptEntry::from_field(self.transcript[i + 1]);

            let next_is_key = (next.token == KEY_SEPARATOR_TOKEN) as Field;

            let valid_token = TOKEN_IS_ARRAY_OBJECT_OR_VALUE[current.token];
            assert((valid_token * next_is_key) + (1 - next_is_key) == 1, "expected value");

            let old_transcript = self.transcript[i];
            let new_transcript = TranscriptEntry::to_field(TranscriptEntry { token: KEY_TOKEN, index: current.index, length: current.length });
            let updated_transcript = (new_transcript - old_transcript) * next_is_key + old_transcript;
            self.transcript[i] = updated_transcript;

            current = next;
        }
    }

    fn validate_tokens(self, tokens: [Field; MaxNumTokens]) {
        let mut current_layer = self.layer_context;
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
            TOKEN_IS_ARRAY_OBJECT_OR_VALUE[previous_token] == 1, "first json token does not describe an object, array or key"
        );

        // 17 gates per iteration?
        for i in 1..MaxNumTokens {
            // 0 gates
            let current_token = tokens[i];

            // 1 gate
            let index = current_layer * NN + previous_token * NUM_TOKENS + current_token;

            // 5 gates
            let  ValidationFlags{push_layer, push_layer_id, pop_layer, error:_ } = ValidationFlags::from_field(TOKEN_VALIDATION_TABLE[index]);

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
            updated_layer = updated_layer * current_layer + push_layer_id;
            std::as_witness(updated_layer);
            updated_layer = updated_layer + parent_layer * pop_layer;
            std::as_witness(updated_layer);
            current_layer = updated_layer;

            previous_token = current_token;
        }
        assert(depth == 0, "invalid object or array description");
    }

    // unconstrained fn __create_json_
    fn create_json_entries(&mut self) {
        let mut entry_ptr = 0;
        let mut depth: Field = 1;
        let mut num_entries_at_current_depth: Field = 0;
        let mut next_identity_value: Field = 1;
        let mut current_identity_value: Field = 0;
        let mut context = OBJECT_CONTEXT;
        let mut key_ptr = 0;
        let mut current_key_index: Field = 0;
        let mut current_key_length: Field = 0;

        let mut parent_context_stack: [Field; 32] = [0; 32];
        // let mut key_data: [Field; TranscriptEntries] = [0; TranscriptEntries];
        // let mut packed_json_entries: [Field; TranscriptEntries] = [0; TranscriptEntries];
        let mut tokens: [Field; MaxNumTokens] = [0; MaxNumTokens];
        // 93.25 gates per iteration
        for i in 0..MaxNumTokens {
            // 5.25 gates
            let TranscriptEntry{token, index, length} = TranscriptEntry::from_field(self.transcript[i]);

            tokens[i] = token;
            // 21 gates
            let TokenFlags{
                create_json_entry,
                json_entry_type,
                is_end_of_object_or_array,
                is_start_of_object_or_array,
                new_context,
                is_key_token: update_key,
                is_value_token,
                is_value_token_in_array_context,
                create_key_entry,
                is_end_of_object_or_array_in_array_context,
                preserve_identity_value,
                preserve_num_entries
            } = TokenFlags::from_field(TOKEN_FLAGS_TABLE[token + context * NUM_TOKENS]);

            // 1 gate
            let diff = index - current_key_index;
            std::as_witness(diff);
            // 1 gate
            current_key_index = diff * update_key + current_key_index;
            std::as_witness(current_key_index);
            // 1 gate
            let diff = length - current_key_length;
            std::as_witness(diff);
            // 1 gate
            current_key_length = diff * update_key + current_key_length;
            std::as_witness(current_key_length);

            // 3 gates
            let new_context_stack_entry = JSONContextStackEntry::to_field(
                JSONContextStackEntry {
                num_entries: num_entries_at_current_depth,
                context,
                current_key_length,
                current_key_index,
                json_index: index,
                entry_pointer: entry_ptr,
                current_identity: current_identity_value
            }
            );
            // subtotal 23.25

            // 1 gate
            let depth_index: Field = (depth - 1);
            // 2 gates
            let previous_stack_entry_packed = parent_context_stack[depth_index];

            // 13.25 gates
            let previous_stack_entry = JSONContextStackEntry::from_field(previous_stack_entry_packed);

            // subtotal 39.5
            // 0
            let object_or_array_entry: JSONEntry = JSONEntry {
                    array_pointer: previous_stack_entry.num_entries, // duplicated lookup remove once working 
                    entry_type: json_entry_type,
                    child_pointer: 0,// previous_stack_entry.entry_pointer, // need a stack to figure this out. is depth value correct here?
                    num_children: num_entries_at_current_depth, // no children
                    json_pointer: previous_stack_entry.json_index,
                    json_length: length,
                    parent_index: previous_stack_entry.current_identity,
                    id: current_identity_value
                };
            // 0
            let value_entry: JSONEntry = JSONEntry {
                    array_pointer: num_entries_at_current_depth, // duplicated lookup remove once working 
                    entry_type: json_entry_type,
                    child_pointer: 0, // need a stack to figure this out. is depth value correct here?
                    num_children: 0, // no children
                    json_pointer: index,
                    json_length: length,
                    parent_index: current_identity_value,
                    id: 0
                };

            // 4 gates
            let object_or_array_entry_packed = object_or_array_entry.to_field();
            // 4 gates
            let value_entry_packed = value_entry.to_field();

            // 2 gates
            let diff = object_or_array_entry_packed - value_entry_packed;
            std::as_witness(diff);
            let new_entry = diff * is_end_of_object_or_array + value_entry_packed;
            std::as_witness(new_entry);

            // TODO fix!
            let previous_context_array = (previous_stack_entry.context == ARRAY_CONTEXT) as Field;
            let real_is_end_of_object_or_array_in_array_context = is_end_of_object_or_array * previous_context_array;

            // 6 gates
            let diff = current_identity_value + current_key_index * 0x10000 + current_key_length * 0x100000000;
            std::as_witness(diff);
            let mut new_key_data = diff * is_value_token;
            std::as_witness(new_key_data);
            new_key_data = new_key_data
                + (num_entries_at_current_depth * 0x1000000000000) * is_value_token_in_array_context;
            std::as_witness(new_key_data);
            let diff = (previous_stack_entry.current_identity
                + previous_stack_entry.current_key_index * 0x10000
                + previous_stack_entry.current_key_length * 0x100000000);
            std::as_witness(diff);
            new_key_data = new_key_data + diff * is_end_of_object_or_array;
            std::as_witness(new_key_data);
            new_key_data = new_key_data
                + (previous_stack_entry.num_entries * 0x1000000000000)
                            * real_is_end_of_object_or_array_in_array_context;
            // N.B. tests pass if we replace above with `is_end_of_object_or_array`???
            // do we create problems if key/value entries have an array index value?
            std::as_witness(new_key_data);

            // subtotal 55.5

            // 3.5 gates
            parent_context_stack[depth] = new_context_stack_entry;
            // 41876 41740 = 136 = 2.125 gates + 1 from assert = 3.125 eh
            // 4.5 gates
            self.key_data[key_ptr] = new_key_data * create_key_entry;

            // (read from key_data ROM = 2)
            // (assert value == new_key_data * create_key_entry = 1)
            // (save 1.5 gates * 1.5 init delta = 3)
            // (repeat with packed_json_entries)
            // 4.5 gates
            self.packed_json_entries[entry_ptr] = new_entry * create_json_entry;

            // subtotal 68

            // 3 gates
            let old = current_identity_value;
            current_identity_value = (next_identity_value * is_start_of_object_or_array);
            std::as_witness(current_identity_value);
            current_identity_value = current_identity_value + (previous_stack_entry.current_identity * is_end_of_object_or_array);
            std::as_witness(current_identity_value);
            current_identity_value = current_identity_value
            + old * preserve_identity_value;
            std::as_witness(current_identity_value);

            // 2 gates
            num_entries_at_current_depth = num_entries_at_current_depth * preserve_num_entries;
            std::as_witness(num_entries_at_current_depth);
            num_entries_at_current_depth = num_entries_at_current_depth + is_value_token +
            (previous_stack_entry.num_entries + 1) * is_end_of_object_or_array;
            std::as_witness(num_entries_at_current_depth);
            // 1 gate
            next_identity_value = next_identity_value + is_start_of_object_or_array;
            std::as_witness(next_identity_value);
            // 1 gate
            key_ptr += create_key_entry;
            std::as_witness(key_ptr);
            // 1 gate
            depth = depth + is_start_of_object_or_array - is_end_of_object_or_array;
            // 1 gate
            // subtotal 88.5
            // 1 gate
            entry_ptr += create_json_entry;
            std::as_witness(entry_ptr);

            // subtotal 78??
            // +10.5 for initializing 3 ram arrays = 88.5?
            // actual value = 93.25
            // 2 gate
            context = new_context * (1 - is_end_of_object_or_array) + is_end_of_object_or_array * previous_stack_entry.context;
        }
        self.validate_tokens(tokens);

        for i in 0..MaxNumValues {
            let A = JSONEntry::from_field(self.packed_json_entries[i]);
            let B = KeyIndexData::from_field(self.key_data[i]);

            if (A.entry_type == BEGIN_ARRAY_TOKEN) {
                assert(A.parent_index == B.parent_id);
            }
        }
    }

    unconstrained fn __build_transcript(self) -> [Field; MaxNumTokens] {
        let mut raw_transcript: [Field; MaxNumTokens] = [0; MaxNumTokens];
        let mut transcript_ptr: Field = 0;
        let mut scan_mode = GRAMMAR_SCAN as Field;
        let mut length: Field = 0;
        // let mut previous_scan_mode = scan_mode;
        // let mut previous_char = 0;

        // let backslash: u8 = "\\".as_bytes()[0];
        // let quotes: u8 = "\"".as_bytes()[0];
        let mut previous_was_potential_escape_sequence = 0;
        for i in 0..NumBytes {
            let ascii = self.json[i];

            let encoded_ascii = previous_was_potential_escape_sequence * 1024 + scan_mode * 256 + ascii as Field;

            let ScanData{ scan_token, push_transcript, increase_length, is_potential_escape_sequence } = ScanData::from_field(REDUCED_CAPTURE_TABLE[encoded_ascii]);

            let mut push_transcript = push_transcript;
            let mut scan_token = scan_token;
            let mut increase_length = increase_length;
            // if (previous_scan_mode == STRING_SCAN)
            //     & (previous_char == backslash as Field)
            //     & (ascii == quotes) {
            //     push_transcript = 0;
            //     scan_token = scan_mode; // or STRING_SCAN
            //     increase_length = 1;
            // }
            let new_entry = RawTranscriptEntry::to_field(RawTranscriptEntry { encoded_ascii, index: i as Field - length, length });

            raw_transcript[transcript_ptr] = new_entry;
            length = length * (1 - push_transcript) + increase_length;
            transcript_ptr += push_transcript;

            previous_was_potential_escape_sequence = is_potential_escape_sequence;

            scan_mode = scan_token;
        }

        raw_transcript
    }

    fn build_transcript(self) -> Self {
        let mut raw_transcript: [Field; MaxNumTokens] = [0; MaxNumTokens];
        let mut transcript_ptr: Field = 0;
        let mut scan_mode = GRAMMAR_SCAN;
        let mut length: Field = 0;

        let raw_transcript = self.__build_transcript();

        // 14 gates per iteration
        let mut previous_was_potential_escape_sequence = 0;
        for i in 0..NumBytes {
            let ascii = self.json[i];

            // 1 gate
            let encoded_ascii = previous_was_potential_escape_sequence * 1024 + scan_mode * 256 + ascii as Field;
            std::as_witness(encoded_ascii);

            // 2 gates
            let capture_flags = REDUCED_CAPTURE_TABLE[encoded_ascii];
            // 5 gates
            let ScanData{ scan_token, push_transcript, increase_length, is_potential_escape_sequence } = ScanData::from_field(capture_flags);

            // 2 gates
            let raw = raw_transcript[transcript_ptr];

            // 1 gate
            let diff = raw
                - RawTranscriptEntry::to_field(RawTranscriptEntry { encoded_ascii, index: i as Field - length, length });
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
        // the lookup into REDUCED_CAPTURE_TABLE applies an implicit 2-bit range check on `scan_token`
        // however this does not get triggered if the final byte scanned produces an error state
        length.assert_max_bit_size(2);

        // 5.75 gates per iteration, plus init cost for 1,024 lookup table (2048 gates)
        // for i in 0..MaxNumTokens {
        //     let transcript_entry = TranscriptEntry::from_raw(raw_transcript[i]);
        //     assert(transcript[i] == transcript_entry);
        // }
        JSON {
            json: self.json,
            raw_transcript,
            transcript: self.transcript,
            transcript_length: transcript_ptr as u16,
            key_data: self.key_data,
            key_hashes: self.key_hashes,
            layer_id: 0,
            root_id: 1,
            layer_context: OBJECT_LAYER, // layer_context updated in `capture_missing_tokens`
            layer_index_in_transcript: 0,
            packed_json_entries: self.packed_json_entries,
            packed_json: self.packed_json
        }
    }

    /*
        NEXT PROBLEM: layer_index_in_transcript WE NEED TO PROPERLY SET THIS FOR THE ROOT OBJECT
        HOW DO WE DO THIS?????

        WE CAN FIND A JSON ENTRY THAT IS EITHER `BEGIN_OBJECT` OR `BEGIN_ARRAY`
        WE MUST ALSO COVER THE SINGLE-VALUE CASE

    */
    unconstrained fn __capture_missing_tokens(self) -> [Field; MaxNumTokens] {
        let mut updated_transcript: [Field; MaxNumTokens] = [0; MaxNumTokens];
        let mut transcript_ptr: Field = 0;
        // hmm probably need a null transcript value?!?!

        for i in 0..MaxNumTokens {
            let RawTranscriptEntry{ encoded_ascii, index, length} = RawTranscriptEntry::from_field(self.raw_transcript[i]);

            let PostProcessScanData{ token, new_grammar, scan_token } = PostProcessScanData::from_field(PROCESS_RAW_TRANSCRIPT_TABLE[encoded_ascii]);

            let entry = TranscriptEntry::to_field(TranscriptEntry { token, index, length });
            updated_transcript[transcript_ptr] = entry;

            let index_valid: Field = (i < self.transcript_length) as Field;
            transcript_ptr += index_valid;

            let index_of_possible_grammar = (index + length);
            let new_entry = TranscriptEntry { token: scan_token, index: index_of_possible_grammar, length: 0 };

            let update = new_grammar as Field * index_valid;
            let new_transcript = TranscriptEntry::to_field(new_entry);
            updated_transcript[transcript_ptr] = new_transcript;
            transcript_ptr += update;
        }
        updated_transcript
    }

    fn capture_missing_tokens(&mut self) {
        let mut transcript_ptr: Field = 0;
        // hmm probably need a null transcript value?!?!
        let updated_transcript = self.__capture_missing_tokens();
        // 28.5 gates per iteration
        for i in 0..MaxNumTokens {
            // 5.25 gates
            let RawTranscriptEntry{ encoded_ascii, index, length} = RawTranscriptEntry::from_field(self.raw_transcript[i]);
            // 6.75 gates
            let PostProcessScanData{ token, new_grammar, scan_token } = PostProcessScanData::from_field(PROCESS_RAW_TRANSCRIPT_TABLE[encoded_ascii]);
            // 4.5 gates
            let index_valid: Field = (i < self.transcript_length) as Field;
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
            let new_entry = TranscriptEntry { token: scan_token, index: index_of_possible_grammar, length: 0 };
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
            self.layer_context = OBJECT_LAYER;
        } else if (first.token == BEGIN_ARRAY_TOKEN) {
            self.layer_context = ARRAY_LAYER;
        } else if (first.token == STRING_TOKEN) {
            self.layer_context = SINGLE_VALUE_LAYER;
        }
    }

    fn parse_json(s: str<NumBytes>) -> Self {
        let mut json = JSON {
            json: s.as_bytes(),
            raw_transcript: [0; MaxNumTokens],
            transcript: [0; MaxNumTokens],
            transcript_length: 0,
            key_data: [0; MaxNumValues],
            key_hashes: [0; MaxNumValues],
            layer_id: 0,
            root_id: 1,
            layer_context: 0,
            layer_index_in_transcript: 0,
            packed_json_entries: [0; MaxNumValues],
            packed_json: [0; NumPackedFields]
        };

        json = json.build_transcript();
        json.capture_missing_tokens();
        json.keyswap();
        json.compute_packed_json();
        json.create_json_entries();

        json.compute_keyhash_and_sort_json_entries();

        json
    }
}

// TODO: our capture tables are not correctly set up to process a JSON blob that does not begin with an object or array
// #[test]
// fn test_single_value() {
//     let text = "100";
//     let mut json = JSON {
//         json: text.as_bytes(),
//         raw_transcript: [0; 20],
//         transcript: [0; 20],
//         transcript_length: 0,
//         key_data: [0; 20],
//         key_hashes: [0; 20],
//         layer_id: 0,
//         root_id: 1,
//         layer_context: 0,
//         layer_index_in_transcript: 1,
//         packed_json_entries: [0; 20],
//         packed_json: [0; 10]
//     };

//     json = json.build_transcript();
//     json.capture_missing_tokens();
//     json.keyswap();
//     json.compute_packed_json();
//     json.create_json_entries();

//     json.compute_keyhash_and_sort_json_entries();

//     assert(json.get_length() == 0);
//     assert(json.get_array_element_as_number(0) == 100);
// }
// \"i\": 999999999, \"j\": 9999999999, \"k\": 99999999999, \"l\": 999999999999, \"m\": 9999999999999, \"n\": 99999999999999, \"o\": 999999999999999, \"p\": 999999999999999
// \"q\": 999999999, \"r\": 9999999999, \"s\": 99999999999, \"l\": 999999999999, \"m\": 9999999999999, \"n\": 99999999999999, \"o\": 999999999999999, \"p\": 999999999999999
// \"q\": 9999999999999999, \"r\": 99999999999999999, \"s\": 999999999999999999, \"t\": 9999999999999999999, \"u\": 18446744073709551615
#[test]
fn test_numbers() {
    let text = "{ \"a\": 9, \"b\": 99, \"c\": 999, \"d\": 9999, \"e\": 99999, \"f\": 999999, \"g\": 9999999, \"h\": 99999999, \"i\": 999999999, \"j\": 9999999999, \"k\": 99999999999, \"l\": 999999999999, \"m\": 9999999999999, \"n\": 99999999999999, \"o\": 999999999999999, \"p\": 999999999999999,\"q\": 9999999999999999, \"r\": 99999999999999999, \"s\": 999999999999999999, \"t\": 9999999999999999999, \"u\": 18446744073709551615}";
    let mut json: JSON<372, 16, 100, 23> = JSON {
        json: text.as_bytes(),
        raw_transcript: [0; 100],
        transcript: [0; 100],
        transcript_length: 0,
        key_data: [0; 23],
        key_hashes: [0; 23],
        layer_id: 0,
        root_id: 1,
        layer_context: 0,
        layer_index_in_transcript: 1,
        packed_json_entries: [0; 23],
        packed_json: [0; 16]
    };

    json = json.build_transcript();
    json.capture_missing_tokens();
    json.keyswap();
    json.compute_packed_json();
    json.create_json_entries();

    json.compute_keyhash_and_sort_json_entries();

    let a = json.get_number_unchecked("a".as_bytes());
    let b = json.get_number_unchecked("b".as_bytes());
    let c = json.get_number_unchecked("c".as_bytes());
    let d = json.get_number_unchecked("d".as_bytes());
    let e = json.get_number_unchecked("e".as_bytes());
    let f = json.get_number_unchecked_var("ftrololol".as_bytes(), 1);
    let g = json.get_number("g".as_bytes()).unwrap();
    let h = json.get_number_var("h".as_bytes(), 1).unwrap();
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
    let mut json = JSON {
        json: text.as_bytes(),
        raw_transcript: [0; 20],
        transcript: [0; 20],
        transcript_length: 0,
        key_data: [0; 20],
        key_hashes: [0; 20],
        layer_id: 0,
        root_id: 1,
        layer_context: 0,
        layer_index_in_transcript: 1,
        packed_json_entries: [0; 20],
        packed_json: [0; 10]
    };

    json = json.build_transcript();
    json.capture_missing_tokens();
    json.keyswap();
    json.compute_packed_json();
    json.create_json_entries();

    json.compute_keyhash_and_sort_json_entries();

    assert(json.get_length() == 5);
    assert(json.get_number_from_array_unchecked(0) == 0);
    assert(json.get_number_from_array_unchecked(1) == 10);
    assert(json.get_number_from_array_unchecked(2) == 21);
    assert(json.get_number_from_array_unchecked(3) == 32);
    assert(json.get_number_from_array_unchecked(4) == 44);
    // let result: JSONLiteral = json.get("testA".as_bytes(), 5);
    // assert(result.is_false() == true);
    // assert(result.is_true() == false);
    // assert(result.is_null() == false);
    // assert(result.to_bool() == false);
    // let result_option: Option<JSONLiteral> = json.get_literal("testA".as_bytes(), 5);
    // assert(result_option.is_some());
    // assert(result_option.unwrap().value == result.value);
}

#[test]
fn test_escaped_strings() {
    // "{   "name": "\"Ade\nel Solangi\""
    let text = "{   \"name\": \"\\\"Ade\\nel Solangi\\\"\", \"testA\": false, \"testB\": true, \"testC\": null }                                                                   ";
    let mut json = JSON {
        json: text.as_bytes(),
        raw_transcript: [0; 20],
        transcript: [0; 20],
        transcript_length: 0,
        key_data: [0; 20],
        key_hashes: [0; 20],
        layer_id: 0,
        root_id: 1,
        layer_context: OBJECT_LAYER,
        layer_index_in_transcript: 0,
        packed_json_entries: [0; 20],
        packed_json: [0; 10]
    };

    json = json.build_transcript();
    json.capture_missing_tokens();
    json.keyswap();
    json.compute_packed_json();
    json.create_json_entries();
    json.compute_keyhash_and_sort_json_entries();

    let result: BoundedVec<u8,19>  = json.get_string_unchecked("name".as_bytes());

    assert(result.storage == BoundedVec::from_array("\"Ade\nel Solangi\"".as_bytes()).storage);
    assert(result.len == 16);
}

#[test]
fn test_redux() {
    /*
0: {    0
1: 
2: "
3: f    3
4: o
5: o
6: "
7: :    7
8:  
9: 1    9
10: 2
11: 3
12: 4
13: ,   13
14:  
15: "
16: b   16
17: a
18: r
19: "
20: :   20
21:  
22: {   22
23:  
24: "
25: f   25
26: o
27: o
28: "
29: :   29
30:  
31: 9   31
32: 8
33: 7
34: 6
35: ,   35
36:  
37: "
38: b   38
39: a
40: r
41: "
42: :   42
43:  
44: t   44
45: r
46: u
47: e
48:  
49:  }  49
50:  ,  50
51:   
52:  "
53:  b  53
54:  a
55:  z
56:  "
57:  :  57
58:   
59:  "
60:  h  60
61:  e
62:  l
63:  l
64:  o
65:  "
66:  
67:  }
*/
    let text= "{ \"foo\": 1234, \"bar\": { \"foo\": 9876, \"bar\": true }, \"baz\": \"hello\" }";

    let mut json = JSON {
        json: text.as_bytes(),
        raw_transcript: [0; 30],
        transcript: [0; 30],
        transcript_length: 0,
        key_data: [0; 30],
        key_hashes: [0; 30],
        layer_id: 0,
        root_id: 1,
        layer_context: OBJECT_LAYER,
        layer_index_in_transcript: 0,
        packed_json_entries: [0; 30],
        packed_json: [0; 7]
    };

    json = json.build_transcript();
    json.capture_missing_tokens();
    let get = |idx| TranscriptEntry::from_field(json.transcript[idx]);

    assert(get(0).index == 0);
    assert(get(1).index == 3);
    let xx = get(2).index;
    println(f"index = {xx}");
    assert(get(2).index == 7);
    assert(get(3).index == 9);
    assert(get(4).index == 13);
    assert(get(5).index == 16);
    assert(get(6).index == 20);
    assert(get(7).index == 22);
    assert(get(8).index == 25);
    assert(get(9).index == 29);
    assert(get(10).index == 31);
    assert(get(11).index == 35);
    assert(get(12).index == 38);
    assert(get(13).index == 42);
    assert(get(14).index == 44);
    assert(get(15).index == 49);
    assert(get(16).index == 50);
    assert(get(17).index == 53);
    assert(get(18).index == 57);
    assert(get(19).index == 60);

    //let t0 = TranscriptEntry::from_field(json.transcript[0]);
    assert(get(0).token == BEGIN_OBJECT_TOKEN);
    assert(get(1).token == STRING_TOKEN);
    assert(get(2).token == KEY_SEPARATOR_TOKEN);
    assert(get(3).token == NUMERIC_TOKEN);
    assert(get(4).token == VALUE_SEPARATOR_TOKEN);
    assert(get(5).token == STRING_TOKEN);
    assert(get(6).token == KEY_SEPARATOR_TOKEN);
    assert(get(7).token == BEGIN_OBJECT_TOKEN);
    assert(get(8).token == STRING_TOKEN);
    assert(get(9).token == KEY_SEPARATOR_TOKEN);
    assert(get(10).token == NUMERIC_TOKEN);
    assert(get(11).token == VALUE_SEPARATOR_TOKEN);
    assert(get(12).token == STRING_TOKEN);
    assert(get(13).token == KEY_SEPARATOR_TOKEN);
    assert(get(14).token == LITERAL_TOKEN);
    assert(get(15).token == END_OBJECT_TOKEN);
    assert(get(16).token == VALUE_SEPARATOR_TOKEN);
    assert(get(17).token == STRING_TOKEN);
    assert(get(18).token == KEY_SEPARATOR_TOKEN);
    assert(get(19).token == STRING_TOKEN);
    assert(get(20).token == END_OBJECT_TOKEN);

    assert(get(1).length == 3);
    assert(get(3).length == 4);
    assert(get(5).length == 3);
    assert(get(8).length == 3);
    assert(get(10).length == 4);
    assert(get(12).length == 3);
    assert(get(14).length == 4);
    assert(get(17).length == 3);
    assert(get(19).length == 5);

    assert(get(0).length == 0);
    assert(get(2).length == 0);
    assert(get(4).length == 0);
    assert(get(6).length == 0);
    assert(get(7).length == 0);
    assert(get(9).length == 0);
    assert(get(11).length == 0);
    assert(get(13).length == 0);
    assert(get(15).length == 0);
    assert(get(16).length == 0);
    assert(get(18).length == 0);
    assert(get(20).length == 0);

    // validate key swap works
    json.keyswap();

    let get = |idx| TranscriptEntry::from_field(json.transcript[idx]);

    assert(get(0).token == BEGIN_OBJECT_TOKEN);
    assert(get(1).token == KEY_TOKEN);
    assert(get(2).token == KEY_SEPARATOR_TOKEN);
    assert(get(3).token == NUMERIC_TOKEN);
    assert(get(4).token == VALUE_SEPARATOR_TOKEN);
    assert(get(5).token == KEY_TOKEN);
    assert(get(6).token == KEY_SEPARATOR_TOKEN);
    assert(get(7).token == BEGIN_OBJECT_TOKEN);
    assert(get(8).token == KEY_TOKEN);
    assert(get(9).token == KEY_SEPARATOR_TOKEN);
    assert(get(10).token == NUMERIC_TOKEN);
    assert(get(11).token == VALUE_SEPARATOR_TOKEN);
    assert(get(12).token == KEY_TOKEN);
    assert(get(13).token == KEY_SEPARATOR_TOKEN);
    assert(get(14).token == LITERAL_TOKEN);
    assert(get(15).token == END_OBJECT_TOKEN);
    assert(get(16).token == VALUE_SEPARATOR_TOKEN);
    assert(get(17).token == KEY_TOKEN);
    assert(get(18).token == KEY_SEPARATOR_TOKEN);
    assert(get(19).token == STRING_TOKEN);
    assert(get(20).token == END_OBJECT_TOKEN);

    // create json entries
    json.compute_packed_json();
    json.create_json_entries();

    let mut json_entries: [JSONEntry; 30] = [JSONEntry::new(); 30];
    for i in 0..30 {
        json_entries[i] = JSONEntry::from_field(json.packed_json_entries[i]);
    }
    /*

struct JSONEntry {
    key_pointer: Field,
    array_pointer: Field,
    entry_type: Field,
    child_pointer: Field,
    num_children: Field,
    json_pointer: Field,
    json_length: Field,
    depth: Field,
}
    */

    assert(json_entries[0].entry_type == NUMERIC_TOKEN);
    assert(json_entries[0].json_pointer == get(3).index);
    assert(json_entries[0].json_length == get(3).length);
    let k = json.key_data[0];
    let g = 1 + get(1).index * 0x10000 + get(1).length * 0x100000000;
    println(f"{k}");
    println(f"{g}");

    assert(json.key_data[0] == 1 + get(1).index * 0x10000 + get(1).length * 0x100000000);
    assert(
        json_entries[0] == JSONEntry {
            array_pointer: 0,
            entry_type: NUMERIC_TOKEN,
            child_pointer: 0,
            num_children: 0,
            json_pointer: get(3).index,
            json_length: get(3).length,
            parent_index: 0,
            id: 0
        }
    );

    let k = json.key_data[1];
    let gg = 2 + get(8).index * 0x10000;
    println(f"{k}");
    println(f"recon{gg}");
    assert(json.key_data[1] == 2 + get(8).index * 0x10000 + get(8).length * 0x100000000);
    assert(
        json_entries[1] == JSONEntry {
            array_pointer: 0,
            entry_type: NUMERIC_TOKEN,
            child_pointer: 0,
            num_children: 0,
            json_pointer: get(10).index,
            json_length: get(10).length,
            parent_index: 0,
            id: 0
        }
    );

    assert(json.key_data[2] == 2 + get(12).index * 0x10000 + get(12).length * 0x100000000);
    assert(
        json_entries[2] == JSONEntry {
            array_pointer: 1,
            entry_type: LITERAL_TOKEN,
            child_pointer: 0,
            num_children: 0,
            json_pointer: get(14).index,
            json_length: get(14).length,
            parent_index: 0,
            id: 0
        }
    );

    assert(json.key_data[3] == 1 + get(5).index * 0x10000 + get(5).length * 0x100000000);

    assert(
        json_entries[3] == JSONEntry {
            array_pointer: 1,
            entry_type: BEGIN_OBJECT_TOKEN,
            child_pointer: 0, // first child of object is json entry 1
            num_children: 2,
            json_pointer: get(7).index,
            json_length: get(7).length,
            parent_index: 0,
            id: 0
        }
    );

    let q = json.key_data[4];
    println(f"key[4] = {q}");

    // what if depth is...hmm hmm hmm

    assert(json.key_data[4] == 1 + get(17).index * 0x10000 + get(17).length * 0x100000000);

    assert(
        json_entries[4] == JSONEntry {
            array_pointer: 2,
            entry_type: STRING_TOKEN,
            child_pointer: 0, // first child of object is json entry 1
            num_children: 0,
            json_pointer: get(19).index,
            json_length: get(19).length,
            parent_index: 0,
            id: 0
        }
    );

    assert(json.key_data[5] == 0 + 0 * 0x10000);

    // TODO: what to do with this? If JSON is an object, we shouldn't have a json entry that describes the top level object, no?
    assert(
        json_entries[5] == JSONEntry {
            array_pointer: 0,
            entry_type: BEGIN_OBJECT_TOKEN,
            child_pointer: 0, // first child of object is json entry 1
            num_children: 3,
            json_pointer: get(0).index,
            json_length: get(0).length,
            parent_index: 0,
            id: 0
        }
    );

    json.compute_keyhash_and_sort_json_entries();

    for i in 0..30 {
        json_entries[i] = JSONEntry::from_field(json.packed_json_entries[i]);
    }
    // #####################
    // let text = "{ \"foo\": 1234, \"bar\": { \"foo\": 9876, \"bar\": true }, \"baz\": \"hello\" }";

    // begin object
    // foo
    // begin object
    // bar.foo
    // TODO: what to do with this? If JSON is an object, we shouldn't have a json entry that describes the top level object, no?
    for i in 0..30 {
        let jsonentries = json_entries[i];
        println(f"NEW ENTRY[{i}]= {jsonentries}");
    }

    let result = json.get_string_unchecked("baz".as_bytes());
    assert(result.storage == "hello".as_bytes());

    let result: Option<BoundedVec<u8, 5>> = json.get_string("baz".as_bytes());
    assert(result.is_some());
    assert(result.unwrap().storage == "hello".as_bytes());

    let result: Option<BoundedVec<u8, 1>> = json.get_string("wibble".as_bytes());
    assert(result.is_some() == false);

    let result: u64 = json.get_number_unchecked("foo".as_bytes());
    println(f"result = {result}");
    assert(result == 1234);

    let result: Option<u64> = json.get_number("foo".as_bytes());
    assert(result.is_some());
    assert(result.unwrap() == 1234);

    let result: Option<u64> = json.get_number("fooo".as_bytes());
    assert(result.is_some() == false);

    let mut nested_json = json.get_object("bar".as_bytes()).unwrap();
    let result: Option<u64> = nested_json.get_number_var("foounusedkeybyteslolol".as_bytes(), 3);
    assert(result.is_some() == true);
    assert(result.unwrap() == 9876);

    let key0: BoundedVec<u8, 3> = BoundedVec::from_array("bar".as_bytes());
    let key1: BoundedVec<u8, 3> = BoundedVec::from_array("baz".as_bytes());

    let result: Option<BoundedVec<u8, 10>> = json.get_string_from_path([key0, key1]);
    assert(result.is_some() == false);
}

// next big TODOs:
// 1. fix off-by-one layer_id values
// 2. add layer_context into JSON. differentiate between single values, arrays and objects

// despite objects not being sorted in element order, the JSON entries *do* have array_id values
// so we CAN iterate through them!
#[test]
fn test_literal() {
    let text = "{   \"name\": \"Adeel Solangi\", \"testA\": false, \"testB\": true, \"testC\": null }                                                                   ";
    let mut json: JSON<142, 10, 20, 20> = JSON {
        json: text.as_bytes(),
        raw_transcript: [0; 20],
        transcript: [0; 20],
        transcript_length: 0,
        key_data: [0; 20],
        key_hashes: [0; 20],
        layer_id: 0,
        root_id: 1,
        layer_context: OBJECT_LAYER,
        layer_index_in_transcript: 0,
        packed_json_entries: [0; 20],
        packed_json: [0; 10]
    };

    json = json.build_transcript();
    json.capture_missing_tokens();
    json.keyswap();

    json.compute_packed_json();
    json.create_json_entries();
    json.compute_keyhash_and_sort_json_entries();

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
    /*
{   
    "name": "Adeel Solangi",
    "age": 62,
    "portfolio": {
        "vibe_ratings": [1,2],
        "elemental_lorem ": false
    }
}
*/
    // false produces a numeric not a literal. fix
    let text = "{   \"name\": \"Adeel Solangi\", \"age\": 62, \"portfolio\": { \"vibe_ratings\": [1,2],\"elemental_lorem\": false }}                                                 ";
    // this one is fucked?
    // let text = "{\"name\": \"Adeel Solangi\",\"age\": 62,\"portfolio\": {\"vibe_ratings\": [1, 4, 6, 89],\"elemental_lorem_ipsum\": [{\"flim\": \"flam\",\"polar\": \"bear\",\"watson\": false},{\"flim\": \"malf\",\"polar\": \"penguin\",\"watson\": true}]}}";
    // let text = "{    \"name\": \"Adeel Solangi\",    \"age\": 62,  \"portfolio\": { \"vibe_ratings\": [1,2,3,89], \"elemental_lorem \": [ { \"flim\": \"flam\", \"polar\": \"bear\" }, { \"f\": [1,2] } ] } }";
    let mut json = JSON {
        json: text.as_bytes(),
        raw_transcript: [0; 60],
        transcript: [0; 60],
        transcript_length: 0,
        key_data: [0; 60],
        key_hashes: [0; 60],
        layer_id: 0,
        root_id: 1,
        layer_context: OBJECT_LAYER,
        layer_index_in_transcript: 0,
        packed_json_entries: [0; 60],
        packed_json: [0; 10]
    };

    json = json.build_transcript();
    json.capture_missing_tokens();
    json.keyswap();
    json.compute_packed_json();
    json.create_json_entries();
    json.compute_keyhash_and_sort_json_entries();

    /*
{   
    "name": "Adeel Solangi",
    "age": 62,
    "portfolio": {
        "vibe_ratings": [1,2,3,89],
        "elemental_lorem ": [
            {
                "flim": "flam",
                "polar": "bear",
                "watson": false
            },
            {
                "flim": "malf",
                "polar": "penguin",
                "watson": true
            }
        ]
    }
}
*/
    let mut json_entries: [JSONEntry; 60] = [JSONEntry::new(); 60];
    for i in 0..60 {
        json_entries[i] = JSONEntry::from_field(json.packed_json_entries[i]);
    }
    assert(json_entries[56].entry_type == LITERAL_TOKEN);
    assert(json_entries[56].parent_index == 2);

    assert(json_entries[57].entry_type == BEGIN_ARRAY_TOKEN);
    assert(json_entries[57].parent_index == 2);

    assert(json_entries[58].entry_type == NUMERIC_TOKEN);
    assert(json_entries[58].parent_index == 3);

    assert(json_entries[59].entry_type == NUMERIC_TOKEN);
    assert(json_entries[59].parent_index == 3);

    assert(json.key_exists("foo".as_bytes(), 3) == false);
    assert(json.key_exists("name".as_bytes(), 4));
    assert(json.key_exists("age".as_bytes(), 3));
    assert(json.key_exists("portfolio".as_bytes(), 9));
}
