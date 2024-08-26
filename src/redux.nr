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
    NUM_TOKENS_MUL_2, CAPTURE_TABLE_ENCODED_FLAT, NUM_TOKENS, NO_TOKEN, TOKEN_IS_ARRAY_OBJECT_OR_VALUE,
    TOKEN_IS_NUMERIC_OR_LITERAL, OBJECT_LAYER, ARRAY_LAYER, SINGLE_VALUE_LAYER, CAPTURE_TABLE_ENCODED,
    GRAMMAR_CAPTURE_INCREASE_LENGTH, STRING_CAPTURE_INCREASE_LENGTH, NUMERIC_CAPTURE_INCREASE_LENGTH,
    LITERAL_CAPTURE_INCREASE_LENGTH, GRAMMAR_CAPTURE_ERROR_FLAG, STRING_CAPTURE_ERROR_FLAG,
    NUMERIC_CAPTURE_ERROR_FLAG, LITERAL_CAPTURE_ERROR_FLAG, LITERAL_CAPTURE_PUSH_TRANSCRIPT,
    LITERAL_CAPTURE_TOKEN, LITERAL_CAPTURE_TABLE, NUMERIC_CAPTURE_PUSH_TRANSCRIPT,
    NUMERIC_CAPTURE_TOKEN, NUMERIC_CAPTURE_TABLE, STRING_CAPTURE_PUSH_TRANSCRIPT, STRING_CAPTURE_TOKEN,
    STRING_CAPTURE_TABLE, GRAMMAR_CAPTURE_PUSH_TRANSCRIPT, GRAMMAR_CAPTURE_TOKEN, GRAMMAR_CAPTURE_TABLE,
    GRAMMAR_CAPTURE, STRING_CAPTURE, NUMERIC_CAPTURE, LITERAL_CAPTURE, ERROR_CAPTURE,
    BEGIN_OBJECT_TOKEN, END_OBJECT_TOKEN, BEGIN_ARRAY_TOKEN, END_ARRAY_TOKEN, KEY_SEPARATOR_TOKEN,
    VALUE_SEPARATOR_TOKEN, STRING_TOKEN, NUMERIC_TOKEN, LITERAL_TOKEN, KEY_TOKEN
};

fn get_flattened_capture_table() {}
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

struct TranscriptMetaData {
    entry_ptr: Field,
    depth: Field,
    num_entries_at_current_depth: Field,
    next_identity_value: Field,
    current_identity_value: Field,
    context: Field,
    key_ptr: Field,
    current_key_index: Field,
    current_key_length: Field,
}
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
        // 19 + 6 = 25
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
    is_value_token: Field,
    is_value_token_in_array_context: Field,
    create_key_entry: Field,
    is_end_of_object_or_array_in_array_context: Field,
    preserve_identity_value: Field,
    preserve_num_entries: Field,
}

impl TokenFlags {

    fn from_field(f: Field) -> Self {
        // 18 gates!
        let bytes = f.to_be_bytes(12);
        let create_json_entry = bytes[0] as Field;
        let json_entry_type = bytes[1] as Field;
        let is_end_of_object_or_array = bytes[2] as Field;
        let is_start_of_object_or_array = bytes[3] as Field;
        let new_context = bytes[4] as Field;
        let is_key_token = bytes[5] as Field;

        let is_value_token = bytes[6] as Field;
        let is_value_token_in_array_context = bytes[7] as Field;
        let create_key_entry = bytes[8] as Field;
        let is_end_of_object_or_array_in_array_context = bytes[9] as Field;
        let preserve_identity_value = bytes[10] as Field;
        let preserve_num_entries = bytes[11] as Field;

        TokenFlags {
            create_json_entry,
            json_entry_type,
            is_end_of_object_or_array,
            is_start_of_object_or_array,
            new_context,
            is_key_token,
            is_value_token,
            is_value_token_in_array_context,
            create_key_entry,
            is_end_of_object_or_array_in_array_context,
            preserve_identity_value,
            preserve_num_entries
        }
    }

    fn to_field(self) -> Field {
        self.preserve_num_entries
            + self.preserve_identity_value * 0x100
            + self.is_end_of_object_or_array_in_array_context * 0x10000
            + self.create_key_entry * 0x1000000
            + self.is_value_token_in_array_context * 0x100000000
            + self.is_value_token * 0x10000000000
            + self.is_key_token * 0x1000000000000
            + self.new_context * 0x100000000000000
            + self.is_start_of_object_or_array * 0x10000000000000000
            + self.is_end_of_object_or_array * 0x1000000000000000000
            + self.json_entry_type * 0x100000000000000000000
            + self.create_json_entry
                                                        * 0x10000000000000000000000
    }

    fn default() -> Self {
        TokenFlags {
            create_json_entry: 0,
            json_entry_type: 0,
            is_end_of_object_or_array: 0,
            is_start_of_object_or_array: 0,
            new_context: 0,
            is_key_token: 0,
            preserve_num_entries: 0,
            preserve_identity_value: 0,
            is_end_of_object_or_array_in_array_context: 0,
            create_key_entry: 0,
            is_value_token_in_array_context: 0,
            is_value_token: 0
        }
    }
    // fn new(a: Field, b: Field, c: Field, d: Field, e: Field, f: Field) -> Self {
    //     TokenFlags {
    //         create_json_entry: a,
    //         json_entry_type: b,
    //         is_end_of_object_or_array: c,
    //         is_start_of_object_or_array: d,
    //         new_context: e,
    //         is_key_token: f
    //     }
    // }
}
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
        is_value_token_in_array_context: 0,
        create_key_entry: 0,
        is_end_of_object_or_array_in_array_context: 0,
        preserve_identity_value: 1,
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
        is_value_token_in_array_context: 0,
        create_key_entry: 0,
        is_end_of_object_or_array_in_array_context: 0,
        preserve_identity_value: 1,
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
        is_value_token_in_array_context: 0,
        create_key_entry: 0,
        is_end_of_object_or_array_in_array_context: 0,
        preserve_identity_value: 0,
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
        is_value_token_in_array_context: 0,
        create_key_entry: 0,
        is_end_of_object_or_array_in_array_context: 0,
        preserve_identity_value: 0,
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
        is_value_token_in_array_context: 0,
        create_key_entry: 1,
        is_end_of_object_or_array_in_array_context: 0,
        preserve_identity_value: 0,
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
        is_value_token_in_array_context: 0,
        create_key_entry: 1,
        is_end_of_object_or_array_in_array_context: 0,
        preserve_identity_value: 0,
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
        is_value_token_in_array_context: 0,
        create_key_entry: 1,
        is_end_of_object_or_array_in_array_context: 0,
        preserve_identity_value: 1,
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
        is_value_token_in_array_context: 0,
        create_key_entry: 1,
        is_end_of_object_or_array_in_array_context: 0,
        preserve_identity_value: 1,
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
        is_value_token_in_array_context: 0,
        create_key_entry: 1,
        is_end_of_object_or_array_in_array_context: 0,
        preserve_identity_value: 1,
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

    end_object_flags.is_end_of_object_or_array_in_array_context = 1;
    end_array_flags.is_end_of_object_or_array_in_array_context = 1;
    string_flags.is_value_token_in_array_context = 1;
    numeric_flags.is_value_token_in_array_context = 1;
    literal_flags.is_value_token_in_array_context = 1;
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
    println(f"TOKEN FLAGS TABLE = {result}");
    assert(result[4] == -1);
    result
}

global TokenFlagsTable: [Field; NUM_TOKENS_MUL_2] = [0x0101, 0x010000000000000000, 0x010101000000000001000000, 0x010100000000000000, 0x010301000000000001000000, 0x0101, 0x0101, 0x010700000000010001000101, 0x010800000000010001000101, 0x010900000000010001000101, 0x01000000000101, 0x0100000000000101, 0x010000000000000000, 0x010101000000000001010000, 0x010100000000000000, 0x010301000000000001010000, 0x0100000000000101, 0x0100000000000101, 0x010700000100010101000101, 0x010800000100010101000101, 0x010900000100010101000101, 0x0101000000000101];

// #[test]
// fn woo() {
//     make_capture_table_full();
// }
// global CAPTURE_TABLE_ENCODED = make_capture_table_full();

struct JSON<let NumBytes: u32, let NumPackedFields: u16, let TranscriptEntries: u32> {
    json: [u8; NumBytes],
    transcript: [Field; TranscriptEntries],
    transcript_length: u16,
    key_data: [Field; TranscriptEntries], // todo make smaller? somehow? urgh
    key_hashes: [Field; TranscriptEntries],
    layer_id: Field,
    layer_context: Field, // is the current layer an OBJECT_LAYER, ARRAY_LAYER or SINGLE_VALUE_LAYER
    layer_index_in_transcript: Field,
    packed_json_entries: [Field; TranscriptEntries],
    packed_json: [Field; NumPackedFields]
}

/*
NEXT UP: HANDLE ARRAYS
this requires adding an array index into the key data being hashed to form our list of objects

*/
impl<let NumBytes: u16, let NumPackedFields: u16, let TranscriptEntries: u16> JSON<NumBytes, NumPackedFields, TranscriptEntries> {

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
            println(f"{limb}"); //limb == 0);
        }
        let NumRemainingBytes = NumBytes - NumWholeLimbs * 31;
        let mut limb: Field = 0;
        for j in 0..NumRemainingBytes {
            limb *= 0x100;
            limb += self.json[NumWholeLimbs * 31 + j] as Field;
        }
        for j in NumRemainingBytes..31 {
            limb *= 0x100;
        }
        std::as_witness(limb);
        self.packed_json[NumWholeLimbs + (NumRemainingBytes == 0) as u16] = limb;
    }
    fn capture_missing_tokens(&mut self) {
        let mut updated_transcript: [Field; TranscriptEntries] = [0; TranscriptEntries];
        let mut transcript_ptr: Field = 0;
        // hmm probably need a null transcript value?!?!

        for i in 0..TranscriptEntries {
            let index_valid = (i < self.transcript_length) as Field; // 4.5 gates?
            // 5.25 gates
            let TranscriptEntry{token, index, length} = TranscriptEntry::from_field(self.transcript[i]);
            // let old = updated_transcript[transcript_ptr];
            // let new = self.transcript[i];
            // let updated = (new - old) * index_valid + old;
            // TODO: validate it's ok for the head to be invalid. i.e. x[transcript_ptr] will repeatedly be overwritten once i >= transcript_length
            // this should be fine because num_entries <= transcript_ptr
            // 7 gates? self.transcript is a RAM array, as is updated_transcript
            updated_transcript[transcript_ptr] = self.transcript[i];
            // pdated_transcript[transcript_ptr] = self.transcript[i];
            // 1 gate
            // subtotal 17.75 gates
            transcript_ptr += index_valid;

            // 2 gates
            let token_is_numeric_or_literal= TOKEN_IS_NUMERIC_OR_LITERAL[token];
            // TODO we might be able to remove `* token_is_numeric_or_literal`. we do this so that we don't overflow the json
            // but the original parse shouldn't produce a token where index + length can overflow?
            // 1 gate or 2 gates
            let index_of_possible_grammar = (index + length) * token_is_numeric_or_literal;
            // 2 gates
            let ascii = self.json[index_of_possible_grammar];

            // TODO: combine new_grammar and scan_token into a single lookup
            // 2 gates eventually
            let new_grammar = GRAMMAR_CAPTURE_PUSH_TRANSCRIPT[ascii];
            let scan_token = GRAMMAR_CAPTURE_TOKEN[ascii];
            let new_entry = TranscriptEntry { token: scan_token, index: index_of_possible_grammar, length: 0 };

            // let old_transcript = updated_transcript[transcript_ptr];
            // TODO: the head of the transcript will likely always be filled with a garbage entry
            // 1 gate
            let new_transcript = TranscriptEntry::to_field(new_entry);
            // 3 gates (ow)
            // 11 + 17.75 = 28.75
            let update = new_grammar as Field * token_is_numeric_or_literal * index_valid;
            // let result_transcript = (new_transcript - old_transcript) * update + old_transcript;
            // 3.5 gates
            updated_transcript[transcript_ptr] = new_transcript;
            // 1 gate
            transcript_ptr += update;
            // subtotal 33.25 gates. ow
        }
        self.transcript = updated_transcript;
    }

    // TODO: when impl is more mature, merge this into create_json_entries
    fn keyswap(&mut self) {
        // TODO: this won't work if 1st entry is a key!
        let mut current= TranscriptEntry::from_field(self.transcript[0]);
        let mut next: TranscriptEntry = TranscriptEntry::new();

        for i in 0..TranscriptEntries - 1 {
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

    //  fn process_transcript_entry(entry: TranscriptEntry)
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

        // TODO why 32?
        let mut parent_context_stack: [Field; 32] = [0; 32];
        // let mut key_data: [Field; TranscriptEntries] = [0; TranscriptEntries];
        // let mut packed_json_entries: [Field; TranscriptEntries] = [0; TranscriptEntries];

        for i in 0..TranscriptEntries {
            let TranscriptEntry{token, index, length} = TranscriptEntry::from_field(self.transcript[i]);

            // 18 gates
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
            } = TokenFlags::from_field(TokenFlagsTable[token + context * NUM_TOKENS]);

            // 1 gate
            current_key_index = (index - current_key_index) * update_key + current_key_index;
            std::as_witness(current_key_index);
            // 1 gate
            current_key_length = (length - current_key_length) * update_key + current_key_length;
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
            // let is_value_token: Field = create_json_entry - is_end_of_object_or_array; // TODO PUT IN JSONCONTEXTSTACKENTRY
            // let is_value_token_in_array_context: Field = is_value_token * context; // TODO PUT IN JSONCONTEXTSTACKENTRY

            // 1 gate
            let depth_index: Field = (depth - 1);
            std::as_witness(depth_index);
            // 2 gates
            let previous_stack_entry_packed = parent_context_stack[depth_index];

            // 25 gates
            let previous_stack_entry = JSONContextStackEntry::from_field(previous_stack_entry_packed);

            // 0
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
            let new_entry = (object_or_array_entry_packed - value_entry_packed) * is_end_of_object_or_array
                + value_entry_packed;
            std::as_witness(new_entry);

            // 6 gates
            let mut new_key_data = (current_identity_value + current_key_index * 0x10000 + current_key_length * 0x100000000)
                * is_value_token;
            std::as_witness(new_key_data);
            new_key_data = new_key_data
                + (num_entries_at_current_depth * 0x1000000000000) * is_value_token_in_array_context;
            std::as_witness(new_key_data);
            new_key_data = new_key_data
                + (previous_stack_entry.current_identity
                        + previous_stack_entry.current_key_index * 0x10000
                        + previous_stack_entry.current_key_length * 0x100000000)
                        * is_end_of_object_or_array;
            std::as_witness(new_key_data);
            new_key_data = new_key_data
                + (previous_stack_entry.num_entries * 0x1000000000000)
                            * is_end_of_object_or_array_in_array_context;
            std::as_witness(new_key_data);
            // subtotal 67
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
            // subtotal 79.5
            self.packed_json_entries[entry_ptr] = new_entry * create_json_entry;

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
            entry_ptr += create_json_entry;
            std::as_witness(entry_ptr);
            context = new_context;
        }
    }

    fn build_transcript(self) -> Self {
        let mut transcript: [Field; TranscriptEntries] = [0; TranscriptEntries];
        let mut transcript_ptr: Field = 0;
        let mut scan_mode = GRAMMAR_SCAN as Field;
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

            // 1 gate to compute index
            // 2 gates to read
            let capture_context = CAPTURE_TABLE_ENCODED_FLAT[scan_mode * 128 + ascii as Field];
            // 2 gates for 5 bytes + 1.25 range gates = 3.25
            let bytes = capture_context.to_be_bytes(5);
            let new_scan_mode = bytes[4] as Field;
            let scan_token = bytes[3] as Field;
            let push_transcript = bytes[2] as Field;
            let increase_length = bytes[1] as Field;
            let error_flag = bytes[0] as Field;

            // 1 gate for i - length
            // 1 gate for to_field
            // subtotal: 8.25
            let new_entry = TranscriptEntry::to_field(TranscriptEntry { token: scan_token, index: i as Field - length, length });

            // let old_entry = transcript[transcript_ptr];

            // let entry = (new_entry - old_entry) * push_transcript + old_entry;
            // 3.5 gates to write
            // TODO might be a problem this last token
            transcript[transcript_ptr] = new_entry; //  * push_transcript;
            // 1 gate to update length
            length = length * (1 - push_transcript) + increase_length;
            // 1 gate to update transcript_ptr
            // 13.75
            transcript_ptr += push_transcript;

            // hmm should be 0 gates but might be 1
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
            packed_json_entries: self.packed_json_entries,
            packed_json: self.packed_json
        }
    }
}

fn extend_array<let InBytes: u32, let OutBytes: u32>(input: [u8; InBytes]) -> [u8; OutBytes] {
    assert(InBytes <= OutBytes);
    let mut result: [u8; OutBytes] = [0; OutBytes];
    for i in 0..InBytes {
        result[i] = input[i];
    }
    result
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
    // TODO FIX PADDING ISSUE
    let text = "{ \"foo\": 1234, \"bar\": { \"foo\": 9876, \"bar\": true }, \"baz\": \"hello\" }                                    ";

    let mut json = JSON {
        json: text.as_bytes(),
        transcript: [0; 30],
        transcript_length: 0,
        key_data: [0; 30],
        key_hashes: [0; 30],
        layer_id: 0,
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

    // assert(
    //     json_entries[26] == JSONEntry {
    //         array_pointer: 1,
    //         entry_type: BEGIN_OBJECT_TOKEN,
    //         child_pointer: 28, // first child of object is json entry 1 // ah fuck wot
    //         num_children: 2,
    //         json_pointer: get(7).index,
    //         json_length: get(7).length,
    //         parent_index: 0,
    //         id: 0
    //     }
    // );
    // assert(
    //     json_entries[27] == JSONEntry {
    //         array_pointer: 0,
    //         entry_type: NUMERIC_TOKEN,
    //         child_pointer: 0,
    //         num_children: 0,
    //         json_pointer: get(3).index,
    //         json_length: get(3).length,
    //         parent_index: 0,
    //         id: 0
    //     }
    // );

    // assert(
    //     json_entries[25] == JSONEntry {
    //         array_pointer: 2,
    //         entry_type: STRING_TOKEN,
    //         child_pointer: 0, // first child of object is json entry 1
    //         num_children: 0,
    //         json_pointer: get(19).index,
    //         json_length: get(19).length,
    //         parent_index: 0,
    //         id: 0
    //     }
    // );

    // assert(
    //     json_entries[29] == JSONEntry {
    //         array_pointer: 0,
    //         entry_type: NUMERIC_TOKEN,
    //         child_pointer: 0,
    //         num_children: 0,
    //         json_pointer: get(10).index,
    //         json_length: get(10).length,
    //         parent_index: 0,
    //         id: 0
    //     }
    // );

    // assert(
    //     json_entries[28] == JSONEntry {
    //         array_pointer: 1,
    //         entry_type: LITERAL_TOKEN,
    //         child_pointer: 0,
    //         num_children: 0,
    //         json_pointer: get(14).index,
    //         json_length: get(14).length,
    //         parent_index: 0,
    //         id: 0
    //     }
    // );

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
    let text = "{   \"name\": \"Adeel Solangi\", \"testA\": false, \"testB\": true, \"testC\": null }                                                                   ";
    let mut json: JSON<142, 10, 20> = JSON {
        json: text.as_bytes(),
        transcript: [0; 20],
        transcript_length: 0,
        key_data: [0; 20],
        key_hashes: [0; 20],
        layer_id: 0,
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
    let text = "{   \"name\": \"Adeel Solangi\", \"age\": 62, \"portfolio\": { \"vibe_ratings\": [1,2],\"elemental_lorem\": false }}                                                 ";
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
