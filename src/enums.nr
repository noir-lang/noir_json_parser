mod ScanMode {
    global GRAMMAR_SCAN = 0;
    global STRING_SCAN = 1;
    global NUMERIC_SCAN = 2;
    global LITERAL_SCAN: Field = 3;
}

mod Token {
    global NO_TOKEN = 0;
    global BEGIN_OBJECT_TOKEN = 1;
    global END_OBJECT_TOKEN = 2;
    global BEGIN_ARRAY_TOKEN = 3;
    global END_ARRAY_TOKEN: Field = 4;
    global KEY_SEPARATOR_TOKEN = 5;
    global VALUE_SEPARATOR_TOKEN = 6;
    global STRING_TOKEN = 7;
    global NUMERIC_TOKEN = 8;
    global LITERAL_TOKEN  =9;
    global KEY_TOKEN = 10;
    global NUM_TOKENS = 11;
    global NUM_TOKENS_MUL_2 = 22;
}

mod Layer {
    global OBJECT_LAYER = 0;
    global ARRAY_LAYER = 1;
    global SINGLE_VALUE_LAYER = 2;
}

