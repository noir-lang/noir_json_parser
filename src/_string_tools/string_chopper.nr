use crate::_string_tools::slice_packed_field::slice_fields;

pub(crate) fn slice_string<let StringBytes: u32, let HaystackPackedFields: u32>(
    haystack: [Field; HaystackPackedFields],
    start_bytes: Field,
    num_bytes: Field,
) -> [u8; StringBytes] {
    // We want to round up the quotient of StringBytes to the next multiple of 31
    let sliced: [Field; (StringBytes + 30) / 31] = slice_fields(haystack, start_bytes, num_bytes);

    let num_slices = StringBytes / 31;
    let overflow = StringBytes % 31;

    let mut parsed_string: [u8; StringBytes] = [0; StringBytes];
    for i in 0..num_slices {
        let sliced_bytes: [u8; 31] = sliced[i].to_be_bytes();
        for j in 0..31 {
            parsed_string[i * 31 + j] = sliced_bytes[j];
        }
    }

    let sliced_bytes: [u8; 31] = sliced[num_slices].to_be_bytes();
    for j in 0..overflow {
        parsed_string[num_slices * 31 + j] = sliced_bytes[j];
    }
    parsed_string
}
