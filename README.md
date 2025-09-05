# noir_json_parse

A JSON parsing library for the Noir Language. This library adheres to the IETF RFC 8259 specifications (mostly, see [edge_cases](#edge_cases)).

Features:

- handles _arbitrary-length_ JSON strings (up to a defined maximum bound)
- flexible interface can process arbitrary JSON schemas
- O(1) algorithms to query whether keys exist

## Noir version compatibility

This library is tested with all Noir stable releases from v0.37.0.

# Usage and Interface

Multiple JSON parser types are exposed that accomodate different maximum length parameters:

> Notation explainer: a _token_ is a distinct JSON element, either `{` `}` `[` `]` `,` `:` , strings, numbers of literals (`false`, `true`, `null`)
> Notation explainer: a _value_ is an object, array, string, number of literal

- `JSON512b` a parser that can handle up to 512 bytes of JSON, up to 64 _tokens_ and 32 _values_
- `JSON1kb` a parser that can handle up to 1kb of JSON, up to 128 _tokens_ and 64 _values_
- `JSON2kb` a parser that can handle up to 2kb bytes of JSON, up to 256 _tokens_ and 128 _values_
- `JSON4kb` a parser that can handle up to 4kb bytes of JSON, up to 512 _tokens_ and 256 _values_
- `JSON8kb` a parser that can handle up to 8kb bytes of JSON, up to 1,024 _tokens_ and 512 _values_
- `JSON16kb` a parser that can handle up to 16kb bytes of JSON, up to 2,048 _tokens_ and 1,024 _values_

The maximum length of keys in the JSON blob is _62 bytes_. All of these parameters are configurable, see [Advanced usage](#advanced-usage) for more info.

## Usage

```
use crate::json_parser::JSON1kb;
use crate::json_parser::JSONLiteral;
/*
example schema. In this example we require every field to exist except "dlc_enabled", which is optional.
We also demonstrate escaped strings. To escape a string in JSON, we must escape the escape characters in noir!
{
    "hero": "Tony Harrison",
    "is_player": false,
    "stats": [
        {
            "hero_quote": "\\\"This is an outrage!\\\"",
            "power_level": 1
        },
        {
            "hero_quote": "\"The Crunch? You know nothing of the crunch!\"",
            "power_level": 9001
        }
    ],
    "dlc_enabled": true
}
*/
fn process_schema(text: [u8; NUM_BYTES])
{
    let json: JSON = JSON::parse_json(text);

    // we use the "unchecked" method because we want to assert this field exists
    let hero_name: BoundedVec<u8, 20> = json.get_string_unchecked("hero".as_array());
    assert(hero_name == BoundedVec::from_array("Tony Harrison".to_array()));

    // json literals can be "null", which doesn't map perfectly to a bool, so we use a custom type
    let is_player: JSONLiteral = json.get_literal_unchecked("is_player".as_array());
    let is_player = is_player.to_bool(); // can cast to bool if you don't mind null mapping to false

    // to move into a nested object or array, call `get_object` or `get_array`
    let stats_array: JSON = json.get_array_unchecked("stats".as_array());
    let stats: [JSON; 2] = [stats.get_object_as_array_unchecked(0), stats.get_object_as_array_unchecked(1)];

    let hero_quote: BoundedVec<u8, 30> = stats[0].get_string_unchecked("hero_quote".as_array());
    assert(hero_quote == BoundedVec::from_array("\"This is an outrage!\"".as_array()));

    let power_levels: [u64; 2] = [
        stats[0].get_number_unchecked("power_level"),
        stats[1].get_number_unchecked("power_level"),
    ];
    assert(power_levels[1] > power_levels[0]);

    // All getter methods have a basic version that returns the element as an Option,
    // to support cases where a field may or may not exist
    let dlc_enabled: Option<JSONLiteral> = json.get_literal("dlc_enabled");

    let has_dlc_field = dlc_enabled.is_some();
}
```

# Edge Cases

### single value JSON

1. A single value is a valid JSON schema but is not currently supported.

i.e. `let json: JSON = JSON::parse_json("9999")` will fail

### no support for floating point or scientific notation numbers

Numbers must currently fit within a u64 for `get_number` and associated methods to work.
In addition, numbers with decimal points currently are not supported, as well as numbers that use scientific notation (e.g. a json blob with `3e5` will create a failing proof)

For numbers larger than 64 bits, the method `get_value` will work, which will return the ascii raw bytes of the value.

# Advanced Usage

### Fine-grained maximum parameter control

If the predefined JSON types are not sufficient for your use case, you can define a JSON object with a custom parameterization:

The JSON struct in `dep::json_parser::json::JSON` is parameterized with the following parameters:

`struct JSON<let NumBytes: u32, let NumPackedFields: u32, let MaxNumTokens: u32, let MaxNumValues: u32, let MaxKeyFields: u32>`

- `NumBytes` : the maximum size of the initial json blob
- `NumPackedFields` : take `NumBytes / 31`, round up to the nearest integer, then add 3!
- `MaxNumTokens`: the maximum number of tokens in the json blob
- `MaxNumValues`: the maximum number of values in the json blob _plus one_
- `MaxKeyFields`: the largest size a key can take (in bytes) equals `MaxKeyFields * 31`

e.g. to take the existing 1kb JSON parameters, but also support 124-byte keys, use `JSON<1024, 37, 128, 65, 4>`

### Making queries with keys of unknown length

If you are deriving a key to look up in-circuit and you do not know the maximum length of the key, all query methods accept the key as a `BoundedVec`

#  Architecture
### Overview
The JSON parser uses 5 steps to efficiently parse and index JSON data:

1. **build_transcript** - Convert raw bytes to a transcript of tokens using state machine defined by by JSON_CAPTURE_TABLE. Categorize each character as string, number, ...
2. **capture_missing_tokens & keyswap** - Fix missing tokens and correctly identify keys. Complete a second scan of the tokens, check for missing tokens (e.g.commas after literals), and for strings that are keys to an object, relabel them as keys, 
3. **compute_json_packed** - Pack bytes into Field elements for efficient substring extraction
4. **create_json_entries** - Create structured JSON entries with parent-child relationships
5. **compute_keyhash_and_sort_json_entries** - Sort entries by key hash for efficient lookups

### Key Design Patterns
- **Using table lookups**: Uses many lookup tables to avoid branching logic to reduce circuit size
- **Packing data to Field elements**: Combines multiple fields that encodes different features into a single Field element for comparison

### Table Generation
The parser uses several lookup tables generated from `src/_table_generation/`:
- `TOKEN_FLAGS_TABLE`: State transitions for token processing
- `JSON_CAPTURE_TABLE`: Character-by-character parsing rules
- `TOKEN_VALIDATION_TABLE`: JSON grammar validation

### Example walkthrough
We can take a look at raw Json text {"name": "Alice", "age": 30} and how it is being parsed.
First, The parser reads the JSON one character at a time and uses lookup tables to decide what to do with each character. For {"name": "Alice"}, 
Character: {  → "Start scanning an object (grammar_capture)"
Character: "  → "Start scanning a string" 
Character: n  → "Continue scanning the string"
Character: a  → "Continue scanning the string"
Character: m  → "Continue scanning the string"
Character: e  → "Continue scanning the string"
Character: "  → "End the string"
Character: :  → "Key-value separator"
Character: "  → "Start scanning a string"
Character: A  → "Continue scanning the string"
Character: l  → "Continue scanning the string"
Character: i  → "Continue scanning the string"
Character: c  → "Continue scanning the string"
Character: e  → "Continue scanning the string"
Character: "  → "End the string"
Character: }  → "End the object"

The parser builds a list of "tokens", the basic building blocks of the JSON, which becomes
1. BEGIN_OBJECT_TOKEN ({)
2. STRING_TOKEN ("name")
3. KEY_SEPARATOR_TOKEN (:)
4. STRING_TOKEN ("Alice")
5. END_OBJECT_TOKEN (})

The parser converts tokens into structured entries with parent-child relationships.
Each entry knows:
What type it is (object, string, number, etc.)
Who its parent is
How many children it has
Where it is in the original JSON

Finally, the parser sorts entries by their key hashes for fast lookups.
Original order: [{"name": "Alice"}, {"age": 30}]
Sorted order:   [{"age": 30}, {"name": "Alice"}]

# Acknowledgements

Many thanks to the authors of the OG noir json library https://github.com/RontoSOFT/noir-json-parser
