# noir_json_parse

A JSON parsing library for the Noir Language. This library adheres to the IETF RFC 8259 specifications (mostly, see [edge_cases](#edge_cases)).

Features:

- handles _arbitrary-length_ JSON strings (up to a defined maximum bound)
- flexible interface can process arbitrary JSON schemas
- O(1) algorithms to query whether keys exist

> **requires Noir v0.32 or greater**

> **if using bb backend, megaplonk (`bb prove_mega_honk`) will give best performance as json-parser uses a megaplonk-friendly hash function Poseidon2**
> (see [bb documentation](https://github.com/AztecProtocol/aztec-packages/blob/master/barretenberg/cpp/src/barretenberg/bb/readme.md#installation) for install/upgrade details)

# Usage and Interface

Multiple JSON parser types are exposed that accomodate different maximum length parameters:

> Notation explainer: a _token_ is a distinct JSON element, either `{` `}` `[` `]` `,` `:` , strings, numbers of literals (`false`, `true`, `null`)
> Notation explainer: a _value_ is an object, array, string, number of literal

- `JSON512b::JSON` a parser that can handle up to 512 bytes of JSON, up to 64 _tokens_ and 32 _values_
- `JSON1kb::JSON` a parser that can handle up to 1kb of JSON, up to 128 _tokens_ and 64 _values_
- `JSON2kb::JSON` a parser that can handle up to 2kb bytes of JSON, up to 256 _tokens_ and 128 _values_
- `JSON4kb::JSON` a parser that can handle up to 4kb bytes of JSON, up to 512 _tokens_ and 256 _values_
- `JSON8kb::JSON` a parser that can handle up to 8kb bytes of JSON, up to 1,024 _tokens_ and 512 _values_
- `JSON16kb::JSON` a parser that can handle up to 16kb bytes of JSON, up to 2,048 _tokens_ and 1,024 _values_

The maximum length of keys in the JSON blob is _62 bytes_. All of these parameters are configurable, see [Advanced usage](#advanced-usage) for more info.

## Usage

```
use crate::json_parser::1kbJSON::JSON;
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

# Cost

How much does this thing cost to use? Details below:

There is an up-front processing cost, as well as a per-query cost.

| json type | cost to parse (in megaplonk gates) |
| --------- | ---------------------------------- |
| 512b      | 42k                                |
| 1kb       | 71k                                |
| 2kb       | 128k                               |
| 4kb       | 160k                               |
| 8kb       | 307k                               |
| 16kb      | 574k                               |

| query type | query cost (in megaplonk gates) |
|-|-|
| `get_value` | 364 |
| `get_number` | 454 |
| `get_literal` | 416 |
| `get_string` | 435 |
| `get_object` | 165 |
| `get_array` | 165 |
| `get_value_unchecked` | 327 |
| `get_number_unchecked` | 415 |
| `get_literal_unchecked` | 346 |
| `get_string_unchecked` | 547 |
| `get_object_unchecked` | 143 |
| `get_array_unchecked` | 143 |

# Advanced Usage

### Fine-grained maximum parameter control

If the predefined JSON types are not sufficient for your use case, you can define a JSON object with a custom parametrisation:

The JSON struct in `dep::json_parser::json::JSON` is parametrised with the following parameters:

`struct JSON<let NumBytes: u32, let NumPackedFields: u32, let MaxNumTokens: u32, let MaxNumValues: u32, let MaxKeyFields: u32>`

- `NumBytes` : the maximum size of the initial json blob
- `NumPackedFields` : take `NumBytes / 31`, round up to the nearest integer, then add 3!
- `MaxNumTokens`: the maximum number of tokens in the json blob
- `MaxNumValues`: the maximum number of values in the json blob _plus one_
- `MaxKeyFields`: the largest size a key can take (in bytes) equals `MaxKeyFields * 31`

e.g. to take the existing 1kb JSON paramters, but also support 124-byte keys, use `JSON<1024, 37, 128, 65, 4>`

### Making queries with keys of unknown length

If you are deriving a key to look up in-circuit and you do not know the maximum length of the key, all query methods have a version with a `_var` suffix (e.g. `JSON::get_string_var`), which accepts the key as a `BoundedVec`

# Acknowledgements

Many thanks to the authors of the OG noir json library https://github.com/RontoSOFT/noir-json-parser
