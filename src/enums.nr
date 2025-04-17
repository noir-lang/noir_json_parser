pub(crate) mod ScanMode {
    pub(crate) global GRAMMAR_SCAN: Field = 0;
    pub(crate) global STRING_SCAN: Field = 1;
    pub(crate) global NUMERIC_SCAN: Field = 2;
    pub(crate) global LITERAL_SCAN: Field = 3;
}

pub(crate) mod Token {
    pub(crate) global NO_TOKEN: Field = 0;
    pub(crate) global BEGIN_OBJECT_TOKEN: Field = 1;
    pub(crate) global END_OBJECT_TOKEN: Field = 2;
    pub(crate) global BEGIN_ARRAY_TOKEN: Field = 3;
    pub(crate) global END_ARRAY_TOKEN: Field = 4;
    pub(crate) global KEY_SEPARATOR_TOKEN: Field = 5;
    pub(crate) global VALUE_SEPARATOR_TOKEN: Field = 6;
    pub(crate) global STRING_TOKEN: Field = 7;
    pub(crate) global NUMERIC_TOKEN: Field = 8;
    pub(crate) global LITERAL_TOKEN: Field = 9;
    pub(crate) global KEY_TOKEN: Field = 10;
    pub(crate) global NUM_TOKENS: u32 = 11;
    pub(crate) global NUM_TOKENS_MUL_2: u32 = 22;
}

pub(crate) mod Layer {
    pub(crate) global OBJECT_LAYER: Field = 0;
    pub(crate) global ARRAY_LAYER: Field = 1;
    pub(crate) global SINGLE_VALUE_LAYER: Field = 2;
}
