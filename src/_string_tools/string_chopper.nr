use crate::_string_tools::slice_packed_field::slice_fields;

struct StringChopper<let NeedlePackedFields: u32> {}

impl<let NeedlePackedFields: u32> StringChopper<NeedlePackedFields> {
    fn slice_string<let StringBytes: u32, let HaystackPackedFields: u32>(
        _: Self,
        haystack: [Field; HaystackPackedFields],
        start_bytes: Field,
        num_bytes: Field,
    ) -> [u8; StringBytes] {
        let mut parsed_string: [u8; StringBytes] = [0; StringBytes];

        let sliced: [Field; NeedlePackedFields] = slice_fields(haystack, start_bytes, num_bytes);

        let sliced_bytes = sliced.map(|x: Field| {
            let r: [u8; 31] = x.to_be_bytes();
            r
        });

        let num_slices = StringBytes / 31;
        let overflow = StringBytes % 31;
        for i in 0..num_slices {
            for j in 0..31 {
                parsed_string[i * 31 + j] = sliced_bytes[i][j];
            }
        }
        for j in 0..overflow {
            parsed_string[num_slices * 31 + j] = sliced_bytes[num_slices][j];
        }
        parsed_string
    }
}
