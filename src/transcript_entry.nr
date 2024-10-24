use crate::json_tables::ASCII_TO_TOKEN_TABLE;

struct ValidationFlags {
    push_layer: Field,
    push_layer_type_of_root: Field,
    pop_layer: Field,
}

impl ValidationFlags {
    fn to_field(self) -> Field {
        self.push_layer + self.push_layer_type_of_root * 0x100 + self.pop_layer * 0x10000
    }

    unconstrained fn __from_field(f: Field) -> Self {
        let bytes: [u8; 4] = f.to_be_bytes();
        let mut push_layer = bytes[3] as Field;
        let push_layer_type_of_root = bytes[2] as Field;
        let pop_layer = bytes[1] as Field;
        let error = bytes[0] as Field;

        assert(error == 0, "ValidationFlags: grammar error");
        // we are doing something very degenerate here.
        // in `validate_tokens` update a `depth` parameter via `depth = depth + push_layer - pop_layer`
        // we index a size-32 array `parent_layer_stack` using the `depth_parameter` immediately after updating `depth`
        // i.e. we implicitly validate `push_layer < 32`
        // If the Prover incorrectly generates the `push_layer` witness via encoding any other flag data within it,
        // an out of bounds error will be triggered
        // n.b. reason for doing this is that by only having 3 flags stored in our lookup table,
        // we can extract them all with 1 add gate. combined with 2 bool checks = 3 gates instead of 5/6 gates if we had 4 flags
        push_layer = push_layer + error * 0x1000000;
        ValidationFlags { push_layer, push_layer_type_of_root, pop_layer }
    }

    // 3 gates
    fn from_field(f: Field) -> Self {
        let r = ValidationFlags::__from_field(f);
        assert(r.pop_layer * r.pop_layer == r.pop_layer);
        assert(r.push_layer_type_of_root * r.push_layer_type_of_root == r.push_layer_type_of_root);
        assert(r.pop_layer * 0x10000 + r.push_layer_type_of_root * 0x100 + r.push_layer == f);
        r
    }
}

struct RawTranscriptEntry {
    encoded_ascii: Field,
    index: Field,
    length: Field,
}

impl RawTranscriptEntry {
    fn new() -> Self {
        RawTranscriptEntry { encoded_ascii: 0, index: 0, length: 0 }
    }
    fn to_field(self) -> Field {
        self.encoded_ascii + self.index * 0x10000 + self.length * (0x100000000)
    }

    unconstrained fn __from_field(felt: Field) -> Self {
        let slices: [u8; 6] = felt.to_be_bytes(); // 2 gates + 1.25 + 2 = 5.25
        let length = slices[1] as Field + slices[0] as Field * 0x100;
        let index = slices[3] as Field + slices[2] as Field * 0x100;
        let encoded_ascii = slices[5] as Field + slices[4] as Field * 0x100;
        Self { encoded_ascii, index, length }
    }
    // 2 gates to add bytes into sum
    // 1.25 gates for range checks
    // 2 gates to get u16s
    // 5.25 gates total
    fn from_field(felt: Field) -> Self {
        let result = RawTranscriptEntry::__from_field(felt);
        result.length.assert_max_bit_size::<16>();
        result.index.assert_max_bit_size::<16>();
        result.encoded_ascii.assert_max_bit_size::<14>();

        assert(result.encoded_ascii + result.index * 0x10000 + result.length * 0x100000000 == felt);
        result
    }

    unconstrained fn __extract_ascii(f: Field) -> (Field, Field) {
        let r = RawTranscriptEntry::__from_field(f);
        let ascii = r.encoded_ascii;
        let remainder = r.index + r.length * 0x10000;
        (ascii, remainder)
    }
    fn extract_ascii(f: Field) -> (Field, Field) {
        let (ascii, remainder) = RawTranscriptEntry::__extract_ascii(f);
        ascii.assert_max_bit_size::<14>();
        remainder.assert_max_bit_size::<32>();
        assert(ascii + remainder * 0x10000 == f);
        (ascii, remainder)
    }
}

struct TranscriptEntry {
    token: Field,
    index: Field,
    length: Field,
}

struct ScanData {
    scan_token: Field,
    push_transcript: Field,
    increase_length: Field,
    is_potential_escape_sequence: Field,
}

impl ScanData {
    unconstrained fn __from_field(f: Field) -> Self {
        let bytes: [u8; 6] = f.to_le_bytes();

        let mut scan_token = bytes[0] as Field;
        let push_transcript = bytes[1] as Field;
        let increase_length = bytes[2] as Field;
        let is_potential_escape_sequence = bytes[3] as Field;
        let error = bytes[4] as Field * 0x100 + bytes[5] as Field;
        assert(error == 0, "ScanData: Invalid token");
        // TODO document this
        scan_token = scan_token + error * 0x100000000;
        ScanData { scan_token, push_transcript, increase_length, is_potential_escape_sequence }
    }
    fn from_field(f: Field) -> Self {
        let result = ScanData::__from_field(f);

        assert(result.increase_length * result.increase_length == result.increase_length);
        assert(result.push_transcript * result.push_transcript == result.push_transcript);
        assert(
            result.is_potential_escape_sequence * result.is_potential_escape_sequence
                == result.is_potential_escape_sequence,
        );
        assert(
            result.scan_token
                + result.push_transcript * 0x100
                + result.increase_length * 0x10000
                + result.is_potential_escape_sequence * 0x1000000
                == f,
        );
        result
    }
}

struct PostProcessScanData {
    token: Field,
    new_grammar: Field,
    scan_token: Field,
}
impl PostProcessScanData {
    fn from_field(f: Field) -> Self {
        let bytes: [u8; 3] = f.to_be_bytes();
        let token = bytes[2] as Field;
        let new_grammar = bytes[1] as Field;
        let scan_token = bytes[0] as Field;
        PostProcessScanData { token, new_grammar, scan_token }
    }
}
impl TranscriptEntry {
    fn new() -> Self {
        TranscriptEntry { token: 0, index: 0, length: 0 }
    }
    fn to_field(self) -> Field {
        self.token + self.index * 0x100 + self.length * (0x1000000)
    }
    unconstrained fn __from_field(felt: Field) -> Self {
        let slices: [u8; 5] = felt.to_be_bytes(); // 2 gates + 1.25 + 2 = 5.25
        let length = slices[1] as Field + slices[0] as Field * 256;
        let index = slices[3] as Field + slices[2] as Field * 256;
        let token = slices[4] as Field;
        Self { token, index, length }
    }
    unconstrained fn __get_token(f: Field) -> (Field, Field) {
        let r = TranscriptEntry::__from_field(f);
        (r.token, (r.index + r.length * 0x10000))
    }
    // 4 gates
    fn get_token(f: Field) -> Field {
        let (token, remainder) = TranscriptEntry::__get_token(f);
        remainder.assert_max_bit_size::<32>();
        token.assert_max_bit_size::<8>();
        assert(token + remainder * 0x100 == f);
        token
    }
    // 5.25 gates
    fn from_field(felt: Field) -> Self {
        let result = TranscriptEntry::__from_field(felt);
        result.length.assert_max_bit_size::<16>();
        result.index.assert_max_bit_size::<16>();
        result.token.assert_max_bit_size::<8>();
        assert(result.token + result.index * 0x100 + result.length * 0x1000000 == felt);
        result
    }

    fn get_token_and_index_length_combined(f: Field) -> (Field, Field) {
        let (token, remainder) = TranscriptEntry::__get_token(f);
        remainder.assert_max_bit_size::<32>();
        token.assert_max_bit_size::<8>();
        assert(token + remainder * 0x100 == f);
        (token, remainder)
    }

    // 5.75 gates
    fn from_raw(raw_encoded: Field) -> Field {
        let (ascii, remainder) = RawTranscriptEntry::__extract_ascii(raw_encoded);
        remainder.assert_max_bit_size::<32>();
        assert(ascii + remainder * 0x10000 == raw_encoded);
        // this lookup enforces an implicit 10 bit range check on ascii
        let token = ASCII_TO_TOKEN_TABLE[ascii];
        token + remainder * 0x100
    }
}
