pub(crate) fn cast_num_to_u32(field_val: Field) -> u32 {
    field_val.assert_max_bit_size::<32>();
    field_val as u32
}
