pub(crate) mod ScanMode {
    pub(crate) global GRAMMAR_SCAN: Field = 0;
}

pub(crate) mod Token {
    pub(crate) global NO_TOKEN: u32 = 0;
    pub(crate) global BEGIN_OBJECT_TOKEN: u32 = 1;
    pub(crate) global END_OBJECT_TOKEN: u32 = 2;
    pub(crate) global BEGIN_ARRAY_TOKEN: u32 = 3;
    pub(crate) global END_ARRAY_TOKEN: u32 = 4;
    pub(crate) global KEY_SEPARATOR_TOKEN: u32 = 5;
    pub(crate) global VALUE_SEPARATOR_TOKEN: u32 = 6;
    pub(crate) global STRING_TOKEN: u32 = 7;
    pub(crate) global NUMERIC_TOKEN: u32 = 8;
    pub(crate) global LITERAL_TOKEN: u32 = 9;
    pub(crate) global KEY_TOKEN: u32 = 10;
    pub(crate) global NUM_TOKENS: u32 = 11;
    pub(crate) global NUM_TOKENS_MUL_2: u32 = 22;
}

pub(crate) mod Layer {
    pub(crate) global OBJECT_LAYER: u32 = 0;
    pub(crate) global ARRAY_LAYER: u32 = 1;
    pub(crate) global SINGLE_VALUE_LAYER: u32 = 2;
}
