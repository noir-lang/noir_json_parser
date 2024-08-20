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

use crate::getters;
use crate::getters::JSONLiteral;
use crate::test_data::JSON_WITH_ARRAYS;
use dep::noir_sort;
use crate::transcript_entry::TranscriptEntry;
use crate::json_entry::JSONEntry;
use crate::keymap;
use crate::lt::{lt_field_8_bit, lt_field_16_bit};
use crate::redux_tables::{
    NUM_TOKENS, NO_TOKEN, TOKEN_IS_ARRAY_OBJECT_OR_VALUE, TOKEN_IS_NUMERIC_OR_LITERAL, OBJECT_LAYER,
    ARRAY_LAYER, SINGLE_VALUE_LAYER, CAPTURE_TABLE_ENCODED, GRAMMAR_CAPTURE_INCREASE_LENGTH,
    STRING_CAPTURE_INCREASE_LENGTH, NUMERIC_CAPTURE_INCREASE_LENGTH, LITERAL_CAPTURE_INCREASE_LENGTH,
    GRAMMAR_CAPTURE_ERROR_FLAG, STRING_CAPTURE_ERROR_FLAG, NUMERIC_CAPTURE_ERROR_FLAG,
    LITERAL_CAPTURE_ERROR_FLAG, LITERAL_CAPTURE_PUSH_TRANSCRIPT, LITERAL_CAPTURE_TOKEN,
    LITERAL_CAPTURE_TABLE, NUMERIC_CAPTURE_PUSH_TRANSCRIPT, NUMERIC_CAPTURE_TOKEN,
    NUMERIC_CAPTURE_TABLE, STRING_CAPTURE_PUSH_TRANSCRIPT, STRING_CAPTURE_TOKEN, STRING_CAPTURE_TABLE,
    GRAMMAR_CAPTURE_PUSH_TRANSCRIPT, GRAMMAR_CAPTURE_TOKEN, GRAMMAR_CAPTURE_TABLE, GRAMMAR_CAPTURE,
    STRING_CAPTURE, NUMERIC_CAPTURE, LITERAL_CAPTURE, ERROR_CAPTURE, BEGIN_OBJECT_TOKEN,
    END_OBJECT_TOKEN, BEGIN_ARRAY_TOKEN, END_ARRAY_TOKEN, KEY_SEPARATOR_TOKEN, VALUE_SEPARATOR_TOKEN,
    STRING_TOKEN, NUMERIC_TOKEN, LITERAL_TOKEN, KEY_TOKEN
};

// todo: single value context?
global OBJECT_CONTEXT: Field = 0;
global ARRAY_CONTEXT: Field = 1;

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

/*
                parent_num_entries_stack[depth] = num_entries_at_current_depth; // add one because we include the array/object
                parent_context[depth] = context;
                parent_key_length[depth] = current_key_length;
                parent_key_index[depth] = current_key_index;
                parent_json_index[depth] = index;
                entry_ptr_stack[depth] = entry_ptr;
                parent_identity_stack[depth] = current_identity_value;

*/
struct JSONContextStackEntry {
    num_entries: Field,
    context: Field,
    current_key_length: Field,
    current_key_index: Field,
    json_index: Field,
    entry_pointer: Field,
    current_identity: Field
}
impl JSONContextStackEntry {
    fn from_field(f: Field) -> Self {
        let bytes = f.to_be_bytes(13);
        let context = bytes[0] as Field;
        let num_entries = bytes[1] as Field * 0x100 + bytes[2] as Field;
        let current_key_length = bytes[3] as Field * 0x100 + bytes[4] as Field;
        let current_key_index = bytes[5] as Field * 0x100 + bytes[6] as Field;
        let json_index = bytes[7] as Field * 0x100 + bytes[8] as Field;
        let entry_pointer = bytes[9] as Field * 0x100 + bytes[10] as Field;
        let current_identity = bytes[11] as Field * 0x100 + bytes[12] as Field;
        JSONContextStackEntry { num_entries, context, current_key_length, current_key_index, json_index, entry_pointer, current_identity }
    }

    fn to_field(self) -> Field {
        self.current_identity
            + self.entry_pointer * 0x10000
            + self.json_index * 0x100000000
            + self.current_key_index * 0x1000000000000
            + self.current_key_length * 0x10000000000000000
            + self.num_entries * 0x100000000000000000000
            + self.context * 0x1000000000000000000000000
    }
}

struct TokenFlags {
    create_json_entry: Field,
    json_entry_type: Field,
    is_end_of_object_or_array: Field,
    is_start_of_object_or_array: Field,
    new_context: Field,
    is_key_token: Field,
}

impl TokenFlags {

    fn from_field(f: Field) -> Self {
        let bytes = f.to_be_bytes(6);
        let create_json_entry = bytes[0] as Field;
        let json_entry_type = bytes[1] as Field;
        let is_end_of_object_or_array = bytes[2] as Field;
        let is_start_of_object_or_array = bytes[3] as Field;
        let new_context = bytes[4] as Field;
        let is_key_token = bytes[5] as Field;
        TokenFlags {
            create_json_entry,
            json_entry_type,
            is_end_of_object_or_array,
            is_start_of_object_or_array,
            new_context,
            is_key_token
        }
    }

    fn to_field(self) -> Field {
        self.is_key_token
            + self.new_context * 0x100
            + self.is_start_of_object_or_array * 0x10000
            + self.is_end_of_object_or_array * 0x1000000
            + self.json_entry_type * 0x100000000
            + self.create_json_entry * 0x10000000000
    }

    fn default() -> Self {
        TokenFlags {
            create_json_entry: 0,
            json_entry_type: 0,
            is_end_of_object_or_array: 0,
            is_start_of_object_or_array: 0,
            new_context: 0,
            is_key_token: 0
        }
    }

    fn new(a: Field, b: Field, c: Field, d: Field, e: Field, f: Field) -> Self {
        TokenFlags {
            create_json_entry: a,
            json_entry_type: b,
            is_end_of_object_or_array: c,
            is_start_of_object_or_array: d,
            new_context: e,
            is_key_token: f
        }
    }
}
unconstrained fn generate_token_flags_table() -> [Field; NUM_TOKENS * 2] {
    let mut flags: [TokenFlags; NUM_TOKENS * 2] = [TokenFlags::default(); NUM_TOKENS * 2];

    let mut no_token_flags: TokenFlags = TokenFlags::new(0, 0, 0, 0, OBJECT_CONTEXT, 0);
    let mut key_token_flags: TokenFlags = TokenFlags::new(0, 0, 0, 0, OBJECT_CONTEXT, 1);

    let begin_object_flags = TokenFlags {
        create_json_entry: 0,
        json_entry_type: 0,
        is_end_of_object_or_array: 0,
        is_start_of_object_or_array: 1,
        new_context: OBJECT_CONTEXT,
        is_key_token: 0
    };

    let begin_array_flags = TokenFlags {
        create_json_entry: 0,
        json_entry_type: 0,
        is_end_of_object_or_array: 0,
        is_start_of_object_or_array: 1,
        new_context: ARRAY_CONTEXT,
        is_key_token: 0
    };

    let end_object_flags = TokenFlags {
        create_json_entry: 1,
        json_entry_type: BEGIN_OBJECT_TOKEN,
        is_end_of_object_or_array: 1,
        is_start_of_object_or_array: 0,
        new_context: 0,
        is_key_token: 0
    };

    let end_array_flags = TokenFlags {
        create_json_entry: 1,
        json_entry_type: BEGIN_ARRAY_TOKEN,
        is_end_of_object_or_array: 1,
        is_start_of_object_or_array: 0,
        new_context: 0,
        is_key_token: 0
    };

    let mut string_flags = TokenFlags {
        create_json_entry: 1,
        json_entry_type: STRING_TOKEN,
        is_end_of_object_or_array: 0,
        is_start_of_object_or_array: 0,
        new_context: OBJECT_CONTEXT,
        is_key_token: 0
    };

    let mut numeric_flags = TokenFlags {
        create_json_entry: 1,
        json_entry_type: NUMERIC_TOKEN,
        is_end_of_object_or_array: 0,
        is_start_of_object_or_array: 0,
        new_context: OBJECT_CONTEXT,
        is_key_token: 0
    };

    let mut literal_flags = TokenFlags {
        create_json_entry: 1,
        json_entry_type: LITERAL_TOKEN,
        is_end_of_object_or_array: 0,
        is_start_of_object_or_array: 0,
        new_context: OBJECT_CONTEXT,
        is_key_token: 0
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

global TokenFlagsTable: [Field; NUM_TOKENS * 2] = generate_token_flags_table();

// #[test]
// fn woo() {
//     make_capture_table_full();
// }
// global CAPTURE_TABLE_ENCODED = make_capture_table_full();

struct JSON<let NumBytes: u32, let TranscriptEntries: u32> {
    json: [u8; NumBytes],
    transcript: [Field; TranscriptEntries],
    transcript_length: u16,
    key_data: [Field; TranscriptEntries], // todo make smaller? somehow? urgh
    key_hashes: [Field; TranscriptEntries],
    layer_id: Field,
    layer_context: Field, // is the current layer an OBJECT_LAYER, ARRAY_LAYER or SINGLE_VALUE_LAYER
    layer_index_in_transcript: Field,
    packed_json_entries: [Field; TranscriptEntries]
}

/*
NEXT UP: HANDLE ARRAYS
this requires adding an array index into the key data being hashed to form our list of objects

*/
impl<let NumBytes: u16, let TranscriptEntries: u16> JSON<NumBytes, TranscriptEntries> {

    fn capture_missing_tokens(&mut self) {
        let mut updated_transcript: [Field; TranscriptEntries] = [0; TranscriptEntries];
        let mut transcript_ptr: Field = 0;
        // hmm probably need a null transcript value?!?!

        for i in 0..TranscriptEntries {
            // TODO fix cast
            let index_valid = (i < self.transcript_length) as Field;
            let TranscriptEntry{token, index, length} = TranscriptEntry::from_field(self.transcript[i]);
            let old = updated_transcript[transcript_ptr];
            let new = self.transcript[i];
            let updated = (new - old) * index_valid + old;
            updated_transcript[transcript_ptr] = updated;
            // pdated_transcript[transcript_ptr] = self.transcript[i];
            transcript_ptr += index_valid;

            // TODO use lookup table 
            let token_is_numeric_or_literal= TOKEN_IS_NUMERIC_OR_LITERAL[token];
            let index_of_possible_grammar = (index + length) * token_is_numeric_or_literal;
            let ascii = self.json[index_of_possible_grammar];

            // TODO: combine new_grammar and scan_token into a single lookup
            let new_grammar = GRAMMAR_CAPTURE_PUSH_TRANSCRIPT[ascii];

            let scan_token = GRAMMAR_CAPTURE_TOKEN[ascii];
            let new_entry = TranscriptEntry { token: scan_token, index: index_of_possible_grammar, length: 0 };

            // TODO: replace with validating ROM array from unconstrained fn
            let old_transcript = updated_transcript[transcript_ptr];
            let new_transcript = TranscriptEntry::to_field(new_entry);
            let update = new_grammar as Field * token_is_numeric_or_literal * index_valid;
            let result_transcript = (new_transcript - old_transcript) * update + old_transcript;
            updated_transcript[transcript_ptr] = result_transcript;
            transcript_ptr += update;
            // if (i < self.transcript_length as u32) {
            //     let TranscriptEntry{token, index, length} = TranscriptEntry::from_field(self.transcript[i]);
            //     updated_transcript[transcript_ptr] = self.transcript[i];
            //     // pdated_transcript[transcript_ptr] = self.transcript[i];
            //     transcript_ptr += 1;
            //     if ((token == NUMERIC) | (token == LITERAL)) {
            //         // ok weird stuff now
            //         let index_of_possible_grammar = index + length;
            //         let ascii = self.json[index_of_possible_grammar];
            //         let new_grammar = GRAMMAR_CAPTURE_PUSH_TRANSCRIPT[ascii];
            //         if {
            //             (new_grammar)
            //         } {
            //             let scan_token = GRAMMAR_CAPTURE_TOKEN[ascii];
            //             let new_entry = TranscriptEntry { token: scan_token, index: index_of_possible_grammar, length: 0 };
            //             updated_transcript[transcript_ptr] = TranscriptEntry::to_field(new_entry);
            //             transcript_ptr += 1;
            //         }
            //     }
            // }
        }
        self.transcript = updated_transcript;
    }

    /*
    fn capture_missing_tokens(&mut self) {
        let mut transcript_ptr: Field = 0;
        // hmm probably need a null transcript value?!?!

        let updated_transcript = self.__capture_missing_tokens();
        for i in 0..TranscriptEntries {
            if (i < self.transcript_length as u32) {
                let TranscriptEntry{token, index, length} = TranscriptEntry::from_field(self.transcript[i]);
                assert(updated_transcript[transcript_ptr] == self.transcript[i]);
                transcript_ptr += 1;

                // TODO use lookup table 
                let token_is_numeric_or_literal= TOKEN_IS_NUMERIC_OR_LITERAL[token];
                let index_of_possible_grammar = (index + length) * token_is_numeric_or_literal;
                let ascii = self.json[index_of_possible_grammar];

                // TODO: combine new_grammar and scan_token into a single lookup
                let new_grammar = GRAMMAR_CAPTURE_PUSH_TRANSCRIPT[ascii];

                let scan_token = GRAMMAR_CAPTURE_TOKEN[ascii];
                let new_entry = TranscriptEntry { token: scan_token, index: index_of_possible_grammar, length: 0 };

                // TODO: replace with validating ROM array from unconstrained fn
                let new_transcript = TranscriptEntry::to_field(new_entry);
                let update = new_grammar as Field * token_is_numeric_or_literal;
                let result_transcript = updated_transcript[transcript_ptr];
                assert((result_transcript - new_transcript) * update == 0);
                // let result_transcript = (new_transcript - old_transcript) * update + old_transcript;
                // updated_transcript[transcript_ptr] = result_transcript;
                transcript_ptr += update;
                // if ((token == NUMERIC) | (token == LITERAL)) {
                //     // ok weird stuff now
                //     let index_of_possible_grammar = index + length;
                //     let ascii = self.json[index_of_possible_grammar];
                //     let new_grammar = GRAMMAR_CAPTURE_PUSH_TRANSCRIPT[ascii];
                //     if {
                //         (new_grammar)
                //     } {
                //         let scan_token = GRAMMAR_CAPTURE_TOKEN[ascii];
                //         let new_entry = TranscriptEntry { token: scan_token, index: index_of_possible_grammar, length: 0 };
                //         updated_transcript[transcript_ptr] = TranscriptEntry::to_field(new_entry);
                //         transcript_ptr += 1;
                //     }
                // }
            }
        }
        self.transcript = updated_transcript;
    }
    */
    // fn 
    fn keyswap(&mut self) {
        // TODO: this won't work if 1st entry is a key!
        let mut current= TranscriptEntry::from_field(self.transcript[0]);
        let mut next: TranscriptEntry = TranscriptEntry::new();

        for i in 0..TranscriptEntries - 1 {
            next = TranscriptEntry::from_field(self.transcript[i + 1]);

            let next_is_key = (next.token == KEY_SEPARATOR_TOKEN) as Field;

            let valid_token = TOKEN_IS_ARRAY_OBJECT_OR_VALUE[current.token];
            assert((valid_token * next_is_key) + (1 - next_is_key) == 1, "expected value");

            // // // TODO fix with ROM array
            let old_transcript = self.transcript[i];
            let new_transcript = TranscriptEntry::to_field(TranscriptEntry { token: KEY_TOKEN, index: current.index, length: current.length });
            let updated_transcript = (new_transcript - old_transcript) * next_is_key + old_transcript;
            self.transcript[i] = updated_transcript;

            /*
            if (next.token == KEY_SEPARATOR_TOKEN) {
                println(f"key separator token current idx {i}");

                // TODO: replace this with a lookup table
                assert(
                    (current.token == STRING_TOKEN)
                    | (current.token == NUMERIC_TOKEN)
                    | (current.token == LITERAL_TOKEN)
                    | (current.token == BEGIN_OBJECT_TOKEN)
                    | (current.token == BEGIN_ARRAY_TOKEN), "expected value"
                );
                self.transcript[i] = TranscriptEntry::to_field(TranscriptEntry{
                    token: KEY_TOKEN,
                    index: current.index,
                    length: current.length
                });
            }
            */
            current = next;
        }
    }

    fn create_json_entries(&mut self) {
        let mut json_entries: [JSONEntry; TranscriptEntries] = [JSONEntry::new(); TranscriptEntries];
        let mut entry_ptr = 0;
        let mut depth: Field = 0;
        let mut num_entries_at_current_depth: Field = 0;
        let mut next_identity_value: Field = 1;
        let mut current_identity_value: Field = 0;
        let mut context = OBJECT_CONTEXT;
        let mut key_ptr = 0;
        let mut current_key_index: Field = 0;
        let mut current_key_length: Field = 0;

        // TODO why 32?
        let mut parent_context_stack: [Field; 32] = [0; 32];
        let mut key_data: [Field; TranscriptEntries] = [0; TranscriptEntries];
        let mut packed_json_entries: [Field; TranscriptEntries] = [0; TranscriptEntries];

        for i in 0..TranscriptEntries {
            let TranscriptEntry{token, index, length} = TranscriptEntry::from_field(self.transcript[i]);

            let TokenFlags{
                create_json_entry,
                json_entry_type,
                is_end_of_object_or_array,
                is_start_of_object_or_array,
                new_context,
                is_key_token: update_key
            } = TokenFlags::from_field(TokenFlagsTable[token + context * NUM_TOKENS]);

            current_key_index = (index - current_key_index) * update_key + current_key_index;
            current_key_length = (length - current_key_length) * update_key + current_key_length;

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

            let is_value_token: Field = create_json_entry - is_end_of_object_or_array; // TODO PUT IN JSONCONTEXTSTACKENTRY
            let is_value_token_in_array_context: Field = is_value_token * context; // TODO PUT IN JSONCONTEXTSTACKENTRY
            let push_key = is_value_token + is_end_of_object_or_array;

            parent_context_stack[depth] = new_context_stack_entry;

            let depth_index = (depth - 1) + (depth == 0) as Field; // TODO fix

            let previous_stack_entry_packed = parent_context_stack[depth_index];

            let previous_stack_entry = JSONContextStackEntry::from_field(previous_stack_entry_packed);

            depth = depth + is_start_of_object_or_array - is_end_of_object_or_array;

            let object_or_array_entry: JSONEntry = JSONEntry {
                    array_pointer: previous_stack_entry.num_entries, // duplicated lookup remove once working 
                    entry_type: json_entry_type,
                    child_pointer: previous_stack_entry.entry_pointer, // need a stack to figure this out. is depth value correct here?
                    num_children: num_entries_at_current_depth, // no children
                    json_pointer: previous_stack_entry.json_index,
                    json_length: length,
                    parent_index: previous_stack_entry.current_identity,
                    id: current_identity_value
                };

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

            let object_or_array_entry_packed = object_or_array_entry.to_field();
            let value_entry_packed = value_entry.to_field();
            let new_entry = (object_or_array_entry_packed - value_entry_packed) * is_end_of_object_or_array
                + value_entry_packed;
            packed_json_entries[entry_ptr] = new_entry * create_json_entry;

            // TODO remove this once we store everything packed
            json_entries[entry_ptr] = JSONEntry::from_field(new_entry * create_json_entry);

            current_identity_value = (next_identity_value * is_start_of_object_or_array)
            + (previous_stack_entry.current_identity * is_end_of_object_or_array)
            + current_identity_value * (1 - is_start_of_object_or_array - is_end_of_object_or_array);
            println(f"AB");

            let new_key_data = (current_identity_value + current_key_index * 0x10000 + current_key_length * 0x100000000)
                * is_value_token
                + (num_entries_at_current_depth * 0x1000000000000) * is_value_token_in_array_context
                + (current_identity_value
                        + previous_stack_entry.current_key_index * 0x10000
                        + previous_stack_entry.current_key_length * 0x100000000)
                        * is_end_of_object_or_array
                + (previous_stack_entry.num_entries * 0x1000000000000)
                            * (is_end_of_object_or_array * previous_stack_entry.context/*context = 1 => array context*/);

            key_data[key_ptr] = new_key_data * push_key;
            key_ptr += push_key;

            next_identity_value = next_identity_value + is_start_of_object_or_array;

            num_entries_at_current_depth = 
            (num_entries_at_current_depth + 1) * is_value_token
            + (previous_stack_entry.num_entries + 1) * is_end_of_object_or_array
            + (num_entries_at_current_depth) * (1 - is_value_token - is_end_of_object_or_array - is_start_of_object_or_array);

            entry_ptr += create_json_entry;
            context = new_context;
        }
        self.packed_json_entries = packed_json_entries;
        self.key_data = key_data;
    }

    fn create_json_entries_old(&mut self) {
        let mut json_entries: [JSONEntry; TranscriptEntries] = [JSONEntry::new(); TranscriptEntries];
        let mut entry_ptr = 0;
        let mut depth: Field = 0;
        let mut num_entries_at_current_depth: Field = 0;
        let mut parent_context: [Field; 32] = [0; 32];
        let mut parent_key_index: [Field; 32] = [0; 32];
        let mut parent_num_entries_stack: [Field; 32] = [0; 32];
        let mut parent_json_index: [Field; 32] = [0; 32];
        let mut entry_ptr_stack: [Field; 32] = [0; 32];
        let mut parent_identity_stack: [Field; 32] = [0; 32];
        let mut next_identity_value: Field = 1;
        let mut current_identity_value: Field = 0;
        let mut context = OBJECT_CONTEXT;
        let mut parent_key_length: [Field; 32] = [0; 32];
        let mut key_ptr = 0;
        let mut key_data: [Field; TranscriptEntries] = [0; TranscriptEntries];
        let mut current_key_index: Field = 0;
        let mut current_key_length: Field = 0;
        for i in 0..TranscriptEntries {
            // todo length check on validity
            let TranscriptEntry{token, index, length} = TranscriptEntry::from_field(self.transcript[i]);

            if (token == KEY_TOKEN) {
                current_key_index = index;
                current_key_length = length;
            }
            if (token == BEGIN_ARRAY_TOKEN) | (token == BEGIN_OBJECT_TOKEN) {
                // this right?
                parent_num_entries_stack[depth] = num_entries_at_current_depth; // add one because we include the array/object
                parent_context[depth] = context;
                parent_key_length[depth] = current_key_length;
                parent_key_index[depth] = current_key_index;
                parent_json_index[depth] = index;
                entry_ptr_stack[depth] = entry_ptr;
                parent_identity_stack[depth] = current_identity_value;
                current_identity_value = next_identity_value;
                next_identity_value += 1;

                if (token == BEGIN_ARRAY_TOKEN) {
                    context = ARRAY_CONTEXT;
                }
                if (token == BEGIN_OBJECT_TOKEN) {
                    context = OBJECT_CONTEXT;
                }
                depth += 1;
                num_entries_at_current_depth = 0;
            }
            if token == END_OBJECT_TOKEN {
                assert(context == OBJECT_CONTEXT, "`}` found but we are not in an object context");
                parent_num_entries_stack[depth] = num_entries_at_current_depth;

                let entry: JSONEntry = JSONEntry {
                    array_pointer: parent_num_entries_stack[depth - 1], // duplicated lookup remove once working 
                    entry_type: BEGIN_OBJECT_TOKEN,
                    child_pointer: entry_ptr_stack[depth - 1], // need a stack to figure this out. is depth value correct here?
                    num_children: num_entries_at_current_depth, // no children
                    json_pointer: parent_json_index[depth - 1],
                    json_length: length,
                    parent_index: parent_identity_stack[depth - 1],
                    id: current_identity_value
                };
                json_entries[entry_ptr] = entry;
                entry_ptr += 1;

                depth -= 1;
                num_entries_at_current_depth = parent_num_entries_stack[depth] + 1;
                context = parent_context[depth];
                current_identity_value = parent_identity_stack[depth];

                key_data[key_ptr] = current_identity_value + parent_key_index[depth] * 0x10000 + parent_key_length[depth] * 0x100000000;
                key_ptr += 1;
            }
            if token == END_ARRAY_TOKEN {
                assert(context == ARRAY_CONTEXT, "`]` found but we are not in an array context");
                parent_num_entries_stack[depth] = num_entries_at_current_depth;

                let entry: JSONEntry = JSONEntry {
                    array_pointer: parent_num_entries_stack[depth - 1], // duplicated lookup remove once working 
                    entry_type: BEGIN_ARRAY_TOKEN,
                    child_pointer: entry_ptr_stack[depth - 1], // need a stack to figure this out. is depth value correct here?
                    num_children: num_entries_at_current_depth, // no children
                    json_pointer: parent_json_index[depth - 1],
                    json_length: length,
                    parent_index: parent_identity_stack[depth - 1],
                    id: current_identity_value
                };
                json_entries[entry_ptr] = entry;
                entry_ptr += 1;

                depth -= 1;
                num_entries_at_current_depth = parent_num_entries_stack[depth] + 1;
                context = parent_context[depth];
                current_identity_value = parent_identity_stack[depth];

                key_data[key_ptr] = current_identity_value + parent_key_index[depth] * 0x10000 + parent_key_length[depth] * 0x10000000;
                key_ptr += 1;
            }

            if (token == STRING_TOKEN) | (token == NUMERIC_TOKEN) | (token == LITERAL_TOKEN) {
                // if context is array then array_pointer is num_entries_at_current_depth
                let entry: JSONEntry = JSONEntry {
                    array_pointer: num_entries_at_current_depth,
                    entry_type: token,
                    child_pointer: 0, // no children
                    num_children: 0, // no children
                    json_pointer: index,
                    json_length: length,
                    parent_index: current_identity_value,
                    id: 0
                };

                json_entries[entry_ptr] = entry;
                entry_ptr += 1;

                // can't we just unilaterally inrease this?
                if (context == ARRAY_CONTEXT) {
                    key_data[key_ptr] = current_identity_value + current_key_index * 0x10000 + current_key_length * 0x100000000 + num_entries_at_current_depth * 0x1000000000000;
                    num_entries_at_current_depth += 1;
                    key_ptr += 1;
                } else if (context == OBJECT_CONTEXT) {
                    num_entries_at_current_depth += 1;
                    key_data[key_ptr] = current_identity_value + current_key_index * 0x10000 + current_key_length * 0x100000000;
                    key_ptr += 1;
                }
            }
        }

        println(f"exit?!");

        for i in 0..10 {
            let ff = json_entries[i];
            println(f"Transcript Entry[{i}] = {ff}");
        }
        assert(context == 100);

        self.key_data = key_data;
    }

    fn build_transcript(self) -> Self {
        let mut transcript: [Field; TranscriptEntries] = [0; TranscriptEntries];
        let mut transcript_ptr: Field = 0;
        let mut scan_mode = GRAMMAR_SCAN;
        let mut length: Field = 0;
        for i in 0..NumBytes {
            // assert(lt_field_8_bit(transcript_ptr, TranscriptEntries as Field), "too many tokens");
            let ascii = self.json[i];

            // read from json = 0
            // capture table idx computation = 1
            // capture table read = 2
            // 5 bytes = 3.25
            // read RAM = 3.5
            // write RAM = 3.5
            // compute transcript entry = 1
            // update length = 1
            // update transcript_ptr = 1
            // assert error flag = 1 (should be 0)
            // 16.25 or 17.25 per byte. pain.

            // we could improve by using unconstrained fn to compute transcript
            // we then are validating what transcript[transcript_ptr] *should* be (because we don't update)
            // which would cut 5 gates off
            // 11.25 per byte?
            let capture_context = CAPTURE_TABLE_ENCODED[scan_mode][ascii];
            let bytes = capture_context.to_be_bytes(5);
            let new_scan_mode = bytes[4] as Field;
            let scan_token = bytes[3] as Field;
            let push_transcript = bytes[2] as Field;
            let increase_length = bytes[1] as Field; // todo don't case
            let error_flag = bytes[0] as Field; // todo don't cast

            let new_entry = TranscriptEntry::to_field(TranscriptEntry { token: scan_token, index: i as Field - length, length });

            let old_entry = transcript[transcript_ptr];

            let entry = (new_entry - old_entry) * push_transcript + old_entry;
            transcript[transcript_ptr] = entry;
            length = length * (1 - push_transcript) + increase_length;
            transcript_ptr += push_transcript;

            assert(error_flag == 0, "bad token?");

            scan_mode = new_scan_mode;
        }
        JSON {
            json: self.json,
            transcript,
            transcript_length: transcript_ptr as u16,
            key_data: self.key_data,
            key_hashes: self.key_hashes,
            layer_id: 0,
            layer_context: OBJECT_LAYER, // TODO support arrays and single values,
            layer_index_in_transcript: 0,
            packed_json_entries: self.packed_json_entries
        }
    }
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
    let text = "{ \"foo\": 1234, \"bar\": { \"foo\": 9876, \"bar\": true }, \"baz\": \"hello\" }";

    let mut json: JSON<68, 30> = JSON {
        json: text.as_bytes(),
        transcript: [0; 30],
        transcript_length: 0,
        key_data: [0; 30],
        key_hashes: [0; 30],
        layer_id: 0,
        layer_context: OBJECT_LAYER,
        layer_index_in_transcript: 0,
        packed_json_entries: [0; 30]
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
            child_pointer: 1, // first child of object is json entry 1
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

    assert(
        json_entries[25] == JSONEntry {
            array_pointer: 1,
            entry_type: BEGIN_OBJECT_TOKEN,
            child_pointer: 28, // first child of object is json entry 1 // ah fuck wot
            num_children: 2,
            json_pointer: get(7).index,
            json_length: get(7).length,
            parent_index: 0,
            id: 0
        }
    );
    assert(
        json_entries[27] == JSONEntry {
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

    assert(
        json_entries[26] == JSONEntry {
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

    assert(
        json_entries[29] == JSONEntry {
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

    assert(
        json_entries[28] == JSONEntry {
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

    let result: [u8; 5] = json.get_string_unchecked("baz".as_bytes(), 3);
    assert(result == "hello".as_bytes());

    let result: Option<[u8; 5]> = json.get_string("baz".as_bytes(), 3);
    assert(result.is_some());
    assert(result.unwrap() == "hello".as_bytes());

    let result: Option<[u8; 1]> = json.get_string("wibble".as_bytes(), 5);
    assert(result.is_some() == false);

    let result: u64 = json.get_number_unchecked("foo".as_bytes(), 3);
    assert(result == 1234);

    let result: Option<u64> = json.get_number("foo".as_bytes(), 3);
    assert(result.is_some());
    assert(result.unwrap() == 1234);

    let result: Option<u64> = json.get_number("fooo".as_bytes(), 4);
    assert(result.is_some() == false);

    let mut nested_json = json.get_object("bar".as_bytes(), 3).unwrap();
    let result: Option<u64> = nested_json.get_number("foo".as_bytes(), 3);
    assert(result.is_some() == true);
    assert(result.unwrap() == 9876);
}

// next big TODOs:
// 1. fix off-by-one layer_id values
// 2. add layer_context into JSON. differentiate between single values, arrays and objects

// despite objects not being sorted in element order, the JSON entries *do* have array_id values
// so we CAN iterate through them!
#[test]
fn test_literal() {
    let text = "{   \"name\": \"Adeel Solangi\", \"testA\": false, \"testB\": true, \"testC\": null }";
    let mut json = JSON {
        json: text.as_bytes(),
        transcript: [0; 20],
        transcript_length: 0,
        key_data: [0; 20],
        key_hashes: [0; 20],
        layer_id: 0,
        layer_context: OBJECT_LAYER,
        layer_index_in_transcript: 0,
        packed_json_entries: [0; 20]
    };

    json = json.build_transcript();
    json.capture_missing_tokens();
    json.keyswap();
    json.create_json_entries();
    json.compute_keyhash_and_sort_json_entries();

    let result: JSONLiteral = json.get_literal_unchecked("testA".as_bytes(), 5);
    assert(result.is_false() == true);
    assert(result.is_true() == false);
    assert(result.is_null() == false);
    assert(result.to_bool() == false);

    let result_option: Option<JSONLiteral> = json.get_literal("testA".as_bytes(), 5);
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
    let text = "{   \"name\": \"Adeel Solangi\", \"age\": 62, \"portfolio\": { \"vibe_ratings\": [1,2],\"elemental_lorem\": false }}";
    // this one is fucked?
    // let text = "{\"name\": \"Adeel Solangi\",\"age\": 62,\"portfolio\": {\"vibe_ratings\": [1, 4, 6, 89],\"elemental_lorem_ipsum\": [{\"flim\": \"flam\",\"polar\": \"bear\",\"watson\": false},{\"flim\": \"malf\",\"polar\": \"penguin\",\"watson\": true}]}}";
    // let text = "{    \"name\": \"Adeel Solangi\",    \"age\": 62,  \"portfolio\": { \"vibe_ratings\": [1,2,3,89], \"elemental_lorem \": [ { \"flim\": \"flam\", \"polar\": \"bear\" }, { \"f\": [1,2] } ] } }";
    let mut json = JSON {
        json: text.as_bytes(),
        transcript: [0; 60],
        transcript_length: 0,
        key_data: [0; 60],
        key_hashes: [0; 60],
        layer_id: 0,
        layer_context: OBJECT_LAYER,
        layer_index_in_transcript: 0,
        packed_json_entries: [0; 60]
    };

    json = json.build_transcript();
    json.capture_missing_tokens();
    json.keyswap();
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
    assert(json_entries[57].entry_type == LITERAL_TOKEN);
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
