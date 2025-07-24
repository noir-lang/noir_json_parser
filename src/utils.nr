pub fn cast_num_to_u32<E>(f: E) -> u32
where
    E: Into<Field>,
{
    let field_val: Field = f.into();
    field_val.assert_max_bit_size::<32>();
    field_val as u32
}
