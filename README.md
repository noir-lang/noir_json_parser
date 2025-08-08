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

## Getters API

#### Function name differences

- **Checked vs Unchecked**
  - `get_*`/`get_*_var` return `Option<T>`; use when a key or index may be absent.
  - `get_*_unchecked`/`get_*_unchecked_var` return `T` and will error on missing/mismatched types.

- **Fixed key vs Variable key**
  - Functions taking `key: [u8; KeyBytes]` expect a fixed-length key known at compile time.
  - Functions with `_var` take `key: BoundedVec<u8, KeyBytes>` for variable-length keys up to `KeyBytes`.

### Object getters API

- **`get_object<let KeyBytes>(key: [u8; KeyBytes])` → `Option<JSON>`**: From an object root, returns `Some(JSON)` if `key` exists and is an object, `None` if `key` is missing; errors if `key` exists but is not an object, or if called when the current root is an array.

- **`get_object_unchecked<let KeyBytes>(key: [u8; KeyBytes])` → `JSON`**: From an object root, returns the object at `key`; errors otherwise.

- **`get_object_var<let KeyBytes>(key: BoundedVec<u8, KeyBytes>)` → `Option<JSON>`**: Same as `get_object`, but the key can be variable-length up to `KeyBytes`.

- **`get_object_unchecked_var<let KeyBytes>(key: BoundedVec<u8, KeyBytes>)` → `JSON`**: Same as `get_object_unchecked`, but with a variable-length key.

- **`get_object_from_array(index: Field)` → `Option<JSON>`**: When the current root is an array, returns the object at `index` wrapped in `Option`. Returns `None` if `index` is out of bounds; errors if in-bounds but the element is not an object.

- **`get_object_from_array_unchecked(index: Field)` → `JSON`**: When the current root is an array, returns the object at `index`. Errors if `index` is out of bounds or the element is not an object.

### Array getters API

- **`get_length()` → `u32`**: Returns its length when the current root is an array; errors otherwise.

- **`get_array<let KeyBytes>(key: [u8; KeyBytes])` → `Option<JSON>`**: From an object root, returns Some(JSON) if key exists and is an array, None if key is missing; errors if key exists but is not an array, or if called when the current root is an array.

- **`get_array_unchecked<let KeyBytes>(key: [u8; KeyBytes])` → `JSON`**: From an object root, returns the array at key; errors otherwise.

- **`get_array_var<let KeyBytes>(key: BoundedVec<u8, KeyBytes>)` → `Option<JSON>`**: Same as `get_array`, but the key can be variable-length up to `KeyBytes`.

- **`get_array_unchecked_var<let KeyBytes>(key: BoundedVec<u8, KeyBytes>)` → `JSON`**: Same as `get_array_unchecked`, but with a variable-length key.

- **`get_array_from_array(index: Field)` → `Option<JSON>`**: When the current root is an array, returns the nested array at `index` wrapped in `Option`. Returns `None` if `index` is out of bounds; errors if in-bounds but the element is not an array.

- **`get_array_from_array_unchecked(index: Field)` → `JSON`**: When the current root is an array, returns the nested array at `index`. Errors if `index` is out of bounds or the element is not an array.

### Literal getters API

Literals are the JSON keywords `true`, `false`, and `null`. They are represented by `JSONLiteral`, which supports:
- `is_true()`, `is_false()`, `is_null()`
- `to_bool()` (maps `true` → `true`, `false`/`null` → `false`)

- **`get_literal<let KeyBytes>(key: [u8; KeyBytes])` → `Option<JSONLiteral>`**: From an object root, returns `Some(JSONLiteral)` if `key` exists and is a literal; `None` if `key` is missing; errors if `key` exists but is not a literal, or if called when the current root is an array.

- **`get_literal_unchecked<let KeyBytes>(key: [u8; KeyBytes])` → `JSONLiteral`**: From an object root, returns the literal at `key`; errors if the key is missing, not a literal, or if called when the current root is an array.

- **`get_literal_var<let KeyBytes>(key: BoundedVec<u8, KeyBytes>)` → `Option<JSONLiteral>`**: Same as `get_literal`, but accepts a variable-length key up to `KeyBytes`.

- **`get_literal_unchecked_var<let KeyBytes>(key: BoundedVec<u8, KeyBytes>)` → `JSONLiteral`**: Same as `get_literal_unchecked`, with a variable-length key.

- **`get_literal_from_array(index: Field)` → `Option<JSONLiteral>`**: When the current root is an array, returns the literal at `index` wrapped in `Option`. Returns `None` if `index` is out of bounds; errors if in-bounds but the element at `index` is not a literal.

- **`get_literal_from_array_unchecked(index: Field)` → `JSONLiteral`**: When the current root is an array, returns the literal at `index`; errors if `index` is out of bounds or the element is not a literal.

### Number getters API

Numbers are parsed as unsigned integers and must fit into `u64` (no decimals).

- **`get_number<let KeyBytes>(key: [u8; KeyBytes])` → `Option<u64>`**: From an object root, returns `Some(u64)` if `key` exists and is a number; `None` if `key` is missing; errors if `key` exists but is not a number, or if called when the current root is an array.

- **`get_number_unchecked<let KeyBytes>(key: [u8; KeyBytes])` → `u64`**: From an object root, returns the number at `key`; errors if the key is missing, not a number, or if called when the current root is an array.

- **`get_number_var<let KeyBytes>(key: BoundedVec<u8, KeyBytes>)` → `Option<u64>`**: Same as `get_number`, but accepts a variable-length key up to `KeyBytes`.

- **`get_number_unchecked_var<let KeyBytes>(key: BoundedVec<u8, KeyBytes>)` → `u64`**: Same as `get_number_unchecked`, with a variable-length key.

- **`get_number_from_array(index: Field)` → `Option<u64>`**: When the current root is an array, returns the number at `index` wrapped in `Option`. Returns `None` if `index` is out of bounds; errors if in-bounds but the element at `index` is not a number.

- **`get_number_from_array_unchecked(index: Field)` → `u64`**: When the current root is an array, returns the number at `index`; errors if `index` is out of bounds or the element is not a number.

### String getters API

Strings are returned as `BoundedVec<u8, StringBytes>` where `StringBytes` is the maximum allowed length of the returned string.

- **`get_string<let KeyBytes, let StringBytes>(key: [u8; KeyBytes])` → `Option<BoundedVec<u8, StringBytes>>`**: From an object root, returns `Some(string)` if `key` exists and is a string; `None` if `key` is missing; errors if `key` exists but is not a string, or if called when the current root is an array.

- **`get_string_unchecked<let KeyBytes, let StringBytes>(key: [u8; KeyBytes])` → `BoundedVec<u8, StringBytes>`**: From an object root, returns the string at `key`; errors otherwise.

- **`get_string_var<let KeyBytes, let StringBytes>(key: BoundedVec<u8, KeyBytes>)` → `Option<BoundedVec<u8, StringBytes>>`**: Same as `get_string`, but accepts a variable-length key up to `KeyBytes`.

- **`get_string_unchecked_var<let KeyBytes, let StringBytes>(key: BoundedVec<u8, KeyBytes>)` → `BoundedVec<u8, StringBytes>`**: Same as `get_string_unchecked`, with a variable-length key.

- **`get_string_from_array<let StringBytes>(index: Field)` → `Option<BoundedVec<u8, StringBytes>>`**: When the current root is an array, returns the string at `index` wrapped in `Option`. Returns `None` if `index` is out of bounds; errors if in-bounds but the element at `index` is not a string.

- **`get_string_from_array_unchecked<let StringBytes>(index: Field)` → `BoundedVec<u8, StringBytes>`**: When the current root is an array, returns the string at `index`; errors if `index` is out of bounds or the element is not a string.

- **`get_string_from_path<let KeyBytes, let StringBytes, let PathDepth>(keys: [BoundedVec<u8, KeyBytes>; PathDepth])` → `Option<BoundedVec<u8, StringBytes>>`**: Traverses nested objects by the given keys; returns Some(string) if the final value exists and is a string, otherwise None.


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
