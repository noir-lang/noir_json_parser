use crate::redux_tables::ASCII_TO_TOKEN_TABLE;

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
        let slices = felt.to_be_bytes(6); // 2 gates + 1.25 + 2 = 5.25
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
        result.length.assert_max_bit_size(16);
        result.index.assert_max_bit_size(16);
        result.encoded_ascii.assert_max_bit_size(14);

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
        ascii.assert_max_bit_size(14);
        remainder.assert_max_bit_size(32);
        assert(ascii + remainder * 0x10000 == f);
        (ascii, remainder)
    }
}

struct TranscriptEntry {
    token: Field,
    index: Field,
    length: Field
}

struct ScanData {
    scan_token: Field,
    push_transcript: Field,
    increase_length: Field
}

impl ScanData {
    unconstrained fn __from_field(f: Field) -> Self {
        let nibbles = f.to_le_radix(4, 4);

        let mut scan_token = nibbles[0] as Field;
        let push_transcript = nibbles[1] as Field;
        let increase_length = nibbles[2] as Field;
        let error = nibbles[3] as Field;
        assert(error == 0, "ScanData: Invalid token");
        // TODO document this
        scan_token = scan_token + error * 64;
        ScanData { scan_token, push_transcript, increase_length }
    }
    fn from_field(f: Field) -> Self {
        let result = ScanData::__from_field(f);

        assert(result.increase_length * result.increase_length == result.increase_length);
        assert(result.push_transcript * result.push_transcript == result.push_transcript);
        assert(result.scan_token + result.push_transcript * 4 + result.increase_length * 16 == f);
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
        let bytes = f.to_be_bytes(3);
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
        let slices = felt.to_be_bytes(5); // 2 gates + 1.25 + 2 = 5.25
        let length = slices[1] as Field + slices[0] as Field * 256;
        let index = slices[3] as Field + slices[2] as Field * 256;
        let token = slices[4] as Field;
        Self { token, index, length }
    }

    fn from_field(felt: Field) -> Self {
        // 2 gates to add bytes into sum
        // 1.25 gates for range checks
        // 2 gates to get u16s
        // 5.25 gates total

        let result = TranscriptEntry::__from_field(felt);
        result.length.assert_max_bit_size(16);
        result.index.assert_max_bit_size(16);
        result.token.assert_max_bit_size(8);

        assert(result.token + result.index * 0x100 + result.length * 0x1000000 == felt);
        result
    }

    // cost 5.75 gates
    fn from_raw(raw_encoded: Field) -> Field {
        let (ascii, remainder) = RawTranscriptEntry::__extract_ascii(raw_encoded);
        remainder.assert_max_bit_size(32);
        assert(ascii + remainder * 0x10000 == raw_encoded);

        // let (ascii, remainder) = RawTranscriptEntry::extract_ascii(raw_encoded);
        // this lookup enforces an implicit 10 bit range check on ascii
        let token = ASCII_TO_TOKEN_TABLE[ascii];
        token + remainder * 0x100
    }
}
