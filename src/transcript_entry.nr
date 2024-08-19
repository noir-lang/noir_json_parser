struct TranscriptEntry {
    token: Field,
    index: Field,
    length: Field
}

impl TranscriptEntry {
    fn new() -> Self {
        TranscriptEntry { token: 0, index: 0, length: 0 }
    }
    fn to_field(self) -> Field {
        self.token + self.index * 256 + self.length * (256 * 256 * 256)
    }

    fn from_field(felt: Field) -> Self {
        let slices = felt.to_be_bytes(5); // 2 gates + 1.25 + 2 = 5.25
        let length = slices[1] as Field + slices[0] as Field * 256;
        let index = slices[3] as Field + slices[2] as Field * 256;
        let token = slices[4] as Field;
        Self { token, index, length }
    }
}
