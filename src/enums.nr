pub mod ScanMode {
    pub global GRAMMAR_SCAN: Field = 0;
    pub global STRING_SCAN: Field = 1;
    pub global NUMERIC_SCAN: Field = 2;
    pub global LITERAL_SCAN: Field = 3;
}

pub mod Token {
    pub global NO_TOKEN: Field = 0;
    pub global BEGIN_OBJECT_TOKEN: Field = 1;
    pub global END_OBJECT_TOKEN: Field = 2;
    pub global BEGIN_ARRAY_TOKEN: Field = 3;
    pub global END_ARRAY_TOKEN: Field = 4;
    pub global KEY_SEPARATOR_TOKEN: Field = 5;
    pub global VALUE_SEPARATOR_TOKEN: Field = 6;
    pub global STRING_TOKEN: Field = 7;
    pub global NUMERIC_TOKEN: Field = 8;
    pub global LITERAL_TOKEN: Field = 9;
    pub global KEY_TOKEN: Field = 10;
    pub global NUM_TOKENS: u32 = 11;
    pub global NUM_TOKENS_MUL_2: u32 = 22;
}

pub mod Layer {
    pub global OBJECT_LAYER: Field = 0;
    pub global ARRAY_LAYER: Field = 1;
    pub global SINGLE_VALUE_LAYER: Field = 2;
}

