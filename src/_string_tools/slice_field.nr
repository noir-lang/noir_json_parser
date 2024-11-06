global PLO: Field = 0x2833E84879B9709143E1F593F0000001;
global PHI: Field = 0x30644E72E131A029B85045B68181585D;

global PLO_200_felt: Field = 0x29B85045B68181585D2833E84879B9709143E1F593F0000001;
global PHI_54_felt: Field = 0x30644E72E131A0;
global TWO_POW_200 = 0x100000000000000000000000000000000000000000000000000;
struct Slice200 {
    hihi: u64, // 7 bytes
    hilo: u64, // 7 bytes
    lohi: u64, // 7 bytes
    lolo: u32, // 4 bytes
}
global PHI_54: u64 = 0x30644E72E131A0;
global PLO_200: Slice200 = Slice200 {
    hihi: 0x29B85045B68181,
    hilo: 0x585D2833E84879,
    lohi: 0xB9709143E1F593,
    lolo: 0xF0000001,
};

unconstrained fn __slice_200_bits_from_field(f: Field) -> (Field, Field, bool) {
    let b: [u8; 32] = f.to_be_bytes();

    let mut res200: Slice200 = Slice200 { hihi: 0, hilo: 0, lohi: 0, lolo: 0 };
    let mut res54: u64 = 0;
    for i in 0..7 {
        res200.hihi <<= 8;
        res200.hilo <<= 8;
        res200.lohi <<= 8;
        res200.hihi += b[i + 7] as u64;
        res200.hilo += b[i + 14] as u64;
        res200.lohi += b[i + 21] as u64;
    }
    for i in 0..4 {
        res200.lolo <<= 8;
        res200.lolo += b[28 + i] as u32;
    }
    for i in 0..7 {
        res54 <<= 8;
        res54 += b[i] as u64;
    }

    let mut lo: Field = res200.hihi as Field; // 56 bits
    lo *= 0x100000000000000; // 56 + 56 bits
    lo += res200.hilo as Field; // 56 + 56 bits
    lo *= 0x100000000000000; // 56 + 56 + 56 bits
    lo += res200.lohi as Field; // 56 + 56 + 56 bits = 168 bits
    lo *= 0x100000000; // 56 + 56 + 56 + 32 bits = 200 bits?
    lo += res200.lolo as Field;

    let mut hi = res54 as Field;

    let mut PLO = PLO_200;
    let mut borrow: bool = false;
    // p - x
    borrow = PLO.lolo < res200.lolo;
    PLO.lohi -= borrow as u64;
    borrow = PLO.lohi < res200.lohi;
    PLO.hilo -= borrow as u64;
    borrow = PLO.hilo < res200.hilo;
    PLO.hihi -= borrow as u64;
    borrow = PLO.hihi < res200.hihi;
    (lo, hi, borrow)
}

pub fn slice_200_bits_from_field(f: Field) -> Field {
    let (lo, hi, borrow) = __slice_200_bits_from_field(f);
    assert(hi * TWO_POW_200 + lo == f);
    lo.assert_max_bit_size::<200>();
    hi.assert_max_bit_size::<56>();
    let lo_diff = PLO_200_felt - lo + (borrow as Field * TWO_POW_200);
    let hi_diff = PHI_54_felt - hi - borrow as Field;
    lo_diff.assert_max_bit_size::<200>();
    hi_diff.assert_max_bit_size::<56>();
    lo
}
