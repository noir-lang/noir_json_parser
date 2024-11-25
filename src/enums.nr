mod ScanMode {
    global GRAMMAR_SCAN: Field  = 0;
    global STRING_SCAN: Field =    1;
    global NUMERIC_SCAN: Field = 2;
    global LITERAL_SCAN: Field = 3;
}

mod Token {
    global NO_TOKEN: Field = 0;
    global BEGIN_OBJECT_TOKEN: Field = 1;
    global END_OBJECT_TOKEN: Field = 2;
    global BEGIN_ARRAY_TOKEN: Field = 3;
    global END_ARRAY_TOKEN: Field = 4;
    global KEY_SEPARATOR_TOKEN: Field = 5;
    global VALUE_SEPARATOR_TOKEN: Field = 6;
    global STRING_TOKEN: Field = 7;
    global NUMERIC_TOKEN: Field = 8;
    global LITERAL_TOKEN: Field = 9;
    global KEY_TOKEN: Field = 10;
    global NUM_TOKENS: u32 = 11;
    global NUM_TOKENS_MUL_2: u32 = 22;
}

mod Layer {
    global OBJECT_LAYER: Field  = 0;
    global ARRAY_LAYER: Field = 1;
    global SINGLE_VALUE_LAYER: Field = 2;
}

