pub(crate) mod _table_generation;
mod enums;
mod json;
mod json_tables;
mod keymap;
mod json_entry;
mod transcript_entry;
pub(crate) mod _string_tools;
pub(crate) mod _comparison_tools;
mod token_flags;
mod getters;
mod keyhash;
mod get_string;
mod get_number;
mod get_literal;
mod get_object;
mod get_array;
mod benchmarks;

use get_literal::JSONLiteral;
use json::{JSON, JSONValue};

pub trait JSONParserTrait {
    fn parse_json_from_string<let StringBytes: u32>(s: str<StringBytes>) -> Self;
    fn parse_json<let StringBytes: u32>(s: [u8; StringBytes]) -> Self;
    fn get_length(self) -> u32;
    fn get_array<let KeyBytes: u32>(self, key: [u8; KeyBytes]) -> Option<Self>;
    fn get_array_unchecked<let KeyBytes: u32>(self, key: [u8; KeyBytes]) -> Self;
    fn get_array_var<let KeyBytes: u32>(self, key: BoundedVec<u8, KeyBytes>) -> Option<Self>;
    fn get_array_unchecked_var<let KeyBytes: u32>(self, key: BoundedVec<u8, KeyBytes>) -> Self;
    fn get_array_from_array(self, array_index: Field) -> Option<Self>;
    fn get_array_from_array_unchecked(self, array_index: Field) -> Self;
    fn map<U, let MaxElements: u32, let MaxElementBytes: u32>(
        self,
        f: fn(JSONValue<MaxElementBytes>) -> U,
    ) -> [U; MaxElements]
    where
        U: std::default::Default;
    fn get_object<let KeyBytes: u32>(self, key: [u8; KeyBytes]) -> Option<Self>;
    fn get_object_unchecked<let KeyBytes: u32>(self, key: [u8; KeyBytes]) -> Self;
    fn get_object_var<let KeyBytes: u32>(self, key: BoundedVec<u8, KeyBytes>) -> Option<Self>;
    fn get_object_unchecked_var<let KeyBytes: u32>(self, key: BoundedVec<u8, KeyBytes>) -> Self;
    fn get_object_from_array(self, array_index: Field) -> Option<Self>;
    fn get_object_from_array_unchecked(self, array_index: Field) -> Self;
    fn get_literal<let KeyBytes: u32>(self, key: [u8; KeyBytes]) -> Option<JSONLiteral>;
    fn get_literal_unchecked<let KeyBytes: u32>(self, key: [u8; KeyBytes]) -> JSONLiteral;
    fn get_literal_var<let KeyBytes: u32>(
        self,
        key: BoundedVec<u8, KeyBytes>,
    ) -> Option<JSONLiteral>;
    fn get_literal_unchecked_var<let KeyBytes: u32>(
        self,
        key: BoundedVec<u8, KeyBytes>,
    ) -> JSONLiteral;
    fn get_literal_from_array(self, array_index: Field) -> Option<JSONLiteral>;
    fn get_literal_from_array_unchecked(self, array_index: Field) -> JSONLiteral;
    fn get_number<let KeyBytes: u32>(self, key: [u8; KeyBytes]) -> Option<u64>;
    fn get_number_unchecked<let KeyBytes: u32>(self, key: [u8; KeyBytes]) -> u64;
    fn get_number_var<let KeyBytes: u32>(self, key: BoundedVec<u8, KeyBytes>) -> Option<u64>;
    fn get_number_unchecked_var<let KeyBytes: u32>(self, key: BoundedVec<u8, KeyBytes>) -> u64;
    fn get_number_from_array(self, array_index: Field) -> Option<u64>;
    fn get_number_from_array_unchecked(self, array_index: Field) -> u64;
    fn get_string<let KeyBytes: u32, let StringBytes: u32>(
        self,
        key: [u8; KeyBytes],
    ) -> Option<BoundedVec<u8, StringBytes>>;
    fn get_string_unchecked<let KeyBytes: u32, let StringBytes: u32>(
        self,
        key: [u8; KeyBytes],
    ) -> BoundedVec<u8, StringBytes>;
    fn get_string_var<let KeyBytes: u32, let StringBytes: u32>(
        self,
        key: BoundedVec<u8, KeyBytes>,
    ) -> Option<BoundedVec<u8, StringBytes>>;
    fn get_string_unchecked_var<let KeyBytes: u32, let StringBytes: u32>(
        self,
        key: BoundedVec<u8, KeyBytes>,
    ) -> BoundedVec<u8, StringBytes>;
    fn get_string_from_array<let StringBytes: u32>(
        self,
        array_index: Field,
    ) -> Option<BoundedVec<u8, StringBytes>>;
    fn get_string_from_array_unchecked<let StringBytes: u32>(
        self,
        array_index: Field,
    ) -> BoundedVec<u8, StringBytes>;
    fn get_string_from_path<let KeyBytes: u32, let StringBytes: u32, let PathDepth: u32>(
        self,
        keys: [BoundedVec<u8, KeyBytes>; PathDepth],
    ) -> Option<BoundedVec<u8, StringBytes>>;
    fn get_value<let KeyBytes: u32, let StringBytes: u32>(
        self,
        key: [u8; KeyBytes],
    ) -> Option<JSONValue<StringBytes>>;
    fn get_value_unchecked<let KeyBytes: u32, let StringBytes: u32>(
        self,
        key: [u8; KeyBytes],
    ) -> JSONValue<StringBytes>;
    fn get_value_var<let KeyBytes: u32, let StringBytes: u32>(
        self,
        key: BoundedVec<u8, KeyBytes>,
    ) -> Option<JSONValue<StringBytes>>;
    fn get_value_unchecked_var<let KeyBytes: u32, let StringBytes: u32>(
        self,
        key: BoundedVec<u8, KeyBytes>,
    ) -> JSONValue<StringBytes>;
    fn get_value_from_array<let StringBytes: u32>(
        self,
        array_index: Field,
    ) -> Option<JSONValue<StringBytes>>;
    fn get_value_from_array_unchecked<let StringBytes: u32>(
        self,
        array_index: Field,
    ) -> JSONValue<StringBytes>;
    fn get_value_from_path<let KeyBytes: u32, let StringBytes: u32, let PathDepth: u32>(
        self,
        keys: [BoundedVec<u8, KeyBytes>; PathDepth],
    ) -> Option<JSONValue<StringBytes>>;
    fn key_exists<let KeyBytes: u32>(self, key: BoundedVec<u8, KeyBytes>) -> bool;
    fn get_keys_at_root<let MaxNumKeys: u32, let MaxKeyBytes: u32>(
        self,
    ) -> BoundedVec<BoundedVec<u8, MaxKeyBytes>, MaxNumKeys>;
}

pub type JSON512b = JSON<512, 20, 64, 33, 2>;
pub type JSON1kb = JSON<1024, 37, 128, 65, 2>;
pub type JSON2kb = JSON<2048, 70, 256, 129, 2>;
pub type JSON4kb = JSON<4096, 136, 512, 257, 2>;
pub type JSON8kb = JSON<8192, 268, 1024, 513, 2>;
pub type JSON16kb = JSON<16384, 532, 2048, 1025, 2>;
