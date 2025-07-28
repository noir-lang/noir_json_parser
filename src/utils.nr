<<<<<<< HEAD
pub(crate) fn cast_num_to_u32(field_val: Field) -> u32
{
=======
pub(crate) fn cast_num_to_u32(field_val: Field) -> u32 {
>>>>>>> dc8ad05fd63ef7518bf3adf3e5b61a87feb143b8
    field_val.assert_max_bit_size::<32>();
    field_val as u32
}
