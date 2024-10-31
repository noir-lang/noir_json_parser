mod _table_generation;
mod enums;
mod json;
mod json_tables;
mod keymap;
mod json_entry;
mod transcript_entry;
mod _string_tools;
mod _comparison_tools;
mod token_flags;
mod getters;
mod keyhash;
mod get_string;
mod get_number;
mod get_literal;
mod get_object;
mod get_array;

use crate::_string_tools::slice_packed_field::slice_fields;
use crate::get_literal::JSONLiteral;
use crate::json::JSON;
use crate::json::JSONValue;
use crate::json_entry::JSONEntry;
use crate::json_entry::JSONEntryPacked;

trait JSONParserTrait {
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

mod JSON512b {
    struct JSON {
        inner: crate::json::JSON<512, 20, 64, 33, 2>,
    }

    impl JSON {
        fn convert(inner: Option<crate::json::JSON<512, 20, 64, 33, 2>>) -> Option<Self> {
            Option { _is_some: inner._is_some, _value: JSON { inner: inner._value } }
        }
    }
    impl crate::JSONParserTrait for JSON {
        fn parse_json_from_string<let StringBytes: u32>(s: str<StringBytes>) -> Self {
            JSON { inner: crate::json::JSON::parse_json_from_string(s) }
        }

        fn parse_json<let StringBytes: u32>(s: [u8; StringBytes]) -> Self {
            JSON { inner: crate::json::JSON::parse_json(s) }
        }
        fn get_length(self) -> u32 {
            self.inner.get_length()
        }
        fn get_array<let KeyBytes: u32>(self, key: [u8; KeyBytes]) -> Option<Self> {
            JSON::convert(self.inner.get_array(key))
        }
        fn get_array_unchecked<let KeyBytes: u32>(self, key: [u8; KeyBytes]) -> Self {
            JSON { inner: self.inner.get_array_unchecked(key) }
        }
        fn get_array_var<let KeyBytes: u32>(self, key: BoundedVec<u8, KeyBytes>) -> Option<Self> {
            {
                JSON::convert(self.inner.get_array_var(key))
            }
        }
        fn get_array_unchecked_var<let KeyBytes: u32>(self, key: BoundedVec<u8, KeyBytes>) -> Self {
            JSON { inner: self.inner.get_array_unchecked_var(key) }
        }
        fn get_array_from_array(self, array_index: Field) -> Option<Self> {
            JSON::convert(self.inner.get_array_from_array(array_index))
        }
        fn get_array_from_array_unchecked(self, array_index: Field) -> Self {
            JSON { inner: self.inner.get_array_from_array_unchecked(array_index) }
        }
        fn map<U, let MaxElements: u32, let MaxElementBytes: u32>(
            self,
            f: fn(crate::JSONValue<MaxElementBytes>) -> U,
        ) -> [U; MaxElements]
        where
            U: std::default::Default,
        {
            self.inner.map(f)
        }
        fn get_object<let KeyBytes: u32>(self, key: [u8; KeyBytes]) -> Option<Self> {
            {
                JSON::convert(self.inner.get_object(key))
            }
        }
        fn get_object_unchecked<let KeyBytes: u32>(self, key: [u8; KeyBytes]) -> Self {
            JSON { inner: self.inner.get_object_unchecked(key) }
        }
        fn get_object_var<let KeyBytes: u32>(self, key: BoundedVec<u8, KeyBytes>) -> Option<Self> {
            {
                JSON::convert(self.inner.get_object_var(key))
            }
        }
        fn get_object_unchecked_var<let KeyBytes: u32>(
            self,
            key: BoundedVec<u8, KeyBytes>,
        ) -> Self {
            JSON { inner: self.inner.get_object_unchecked_var(key) }
        }
        fn get_object_from_array(self, array_index: Field) -> Option<Self> {
            JSON::convert(self.inner.get_object_from_array(array_index))
        }
        fn get_object_from_array_unchecked(self, array_index: Field) -> Self {
            JSON { inner: self.inner.get_object_from_array_unchecked(array_index) }
        }
        fn get_literal<let KeyBytes: u32>(self, key: [u8; KeyBytes]) -> Option<crate::JSONLiteral> {
            self.inner.get_literal(key)
        }
        fn get_literal_unchecked<let KeyBytes: u32>(
            self,
            key: [u8; KeyBytes],
        ) -> crate::JSONLiteral {
            self.inner.get_literal_unchecked(key)
        }
        fn get_literal_var<let KeyBytes: u32>(
            self,
            key: BoundedVec<u8, KeyBytes>,
        ) -> Option<crate::JSONLiteral> {
            self.inner.get_literal_var(key)
        }
        fn get_literal_unchecked_var<let KeyBytes: u32>(
            self,
            key: BoundedVec<u8, KeyBytes>,
        ) -> crate::JSONLiteral {
            self.inner.get_literal_unchecked_var(key)
        }
        fn get_literal_from_array(self, array_index: Field) -> Option<crate::JSONLiteral> {
            self.inner.get_literal_from_array(array_index)
        }
        fn get_literal_from_array_unchecked(self, array_index: Field) -> crate::JSONLiteral {
            self.inner.get_literal_from_array_unchecked(array_index)
        }
        fn get_number<let KeyBytes: u32>(self, key: [u8; KeyBytes]) -> Option<u64> {
            self.inner.get_number(key)
        }
        fn get_number_unchecked<let KeyBytes: u32>(self, key: [u8; KeyBytes]) -> u64 {
            self.inner.get_number_unchecked(key)
        }
        fn get_number_var<let KeyBytes: u32>(self, key: BoundedVec<u8, KeyBytes>) -> Option<u64> {
            self.inner.get_number_var(key)
        }
        fn get_number_unchecked_var<let KeyBytes: u32>(self, key: BoundedVec<u8, KeyBytes>) -> u64 {
            self.inner.get_number_unchecked_var(key)
        }
        fn get_number_from_array(self, array_index: Field) -> Option<u64> {
            self.inner.get_number_from_array(array_index)
        }
        fn get_number_from_array_unchecked(self, array_index: Field) -> u64 {
            self.inner.get_number_from_array_unchecked(array_index)
        }

        fn get_string<let KeyBytes: u32, let StringBytes: u32>(
            self,
            key: [u8; KeyBytes],
        ) -> Option<BoundedVec<u8, StringBytes>> {
            self.inner.get_string(key)
        }
        fn get_string_unchecked<let KeyBytes: u32, let StringBytes: u32>(
            self,
            key: [u8; KeyBytes],
        ) -> BoundedVec<u8, StringBytes> {
            self.inner.get_string_unchecked(key)
        }
        fn get_string_var<let KeyBytes: u32, let StringBytes: u32>(
            self,
            key: BoundedVec<u8, KeyBytes>,
        ) -> Option<BoundedVec<u8, StringBytes>> {
            self.inner.get_string_var(key)
        }
        fn get_string_unchecked_var<let KeyBytes: u32, let StringBytes: u32>(
            self,
            key: BoundedVec<u8, KeyBytes>,
        ) -> BoundedVec<u8, StringBytes> {
            self.inner.get_string_unchecked_var(key)
        }
        fn get_string_from_array<let StringBytes: u32>(
            self,
            array_index: Field,
        ) -> Option<BoundedVec<u8, StringBytes>> {
            self.inner.get_string_from_array(array_index)
        }
        fn get_string_from_array_unchecked<let StringBytes: u32>(
            self,
            array_index: Field,
        ) -> BoundedVec<u8, StringBytes> {
            self.inner.get_string_from_array_unchecked(array_index)
        }
        fn get_string_from_path<let KeyBytes: u32, let StringBytes: u32, let PathDepth: u32>(
            self,
            keys: [BoundedVec<u8, KeyBytes>; PathDepth],
        ) -> Option<BoundedVec<u8, StringBytes>> {
            self.inner.get_string_from_path(keys)
        }
        fn get_value<let KeyBytes: u32, let StringBytes: u32>(
            self,
            key: [u8; KeyBytes],
        ) -> Option<crate::JSONValue<StringBytes>> {
            self.inner.get_value(key)
        }
        fn get_value_unchecked<let KeyBytes: u32, let StringBytes: u32>(
            self,
            key: [u8; KeyBytes],
        ) -> crate::JSONValue<StringBytes> {
            self.inner.get_value_unchecked(key)
        }
        fn get_value_var<let KeyBytes: u32, let StringBytes: u32>(
            self,
            key: BoundedVec<u8, KeyBytes>,
        ) -> Option<crate::JSONValue<StringBytes>> {
            self.inner.get_value_var(key)
        }
        fn get_value_unchecked_var<let KeyBytes: u32, let StringBytes: u32>(
            self,
            key: BoundedVec<u8, KeyBytes>,
        ) -> crate::JSONValue<StringBytes> {
            self.inner.get_value_unchecked_var(key)
        }
        fn get_value_from_array<let StringBytes: u32>(
            self,
            array_index: Field,
        ) -> Option<crate::JSONValue<StringBytes>> {
            self.inner.get_value_from_array(array_index)
        }
        fn get_value_from_array_unchecked<let StringBytes: u32>(
            self,
            array_index: Field,
        ) -> crate::JSONValue<StringBytes> {
            self.inner.get_value_from_array_unchecked(array_index)
        }
        fn get_value_from_path<let KeyBytes: u32, let StringBytes: u32, let PathDepth: u32>(
            self,
            keys: [BoundedVec<u8, KeyBytes>; PathDepth],
        ) -> Option<crate::JSONValue<StringBytes>> {
            self.inner.get_value_from_path(keys)
        }

        fn key_exists<let KeyBytes: u32>(self, key: BoundedVec<u8, KeyBytes>) -> bool {
            self.inner.key_exists(key)
        }
        fn get_keys_at_root<let MaxNumKeys: u32, let MaxKeyBytes: u32>(
            self,
        ) -> BoundedVec<BoundedVec<u8, MaxKeyBytes>, MaxNumKeys> {
            self.inner.get_keys_at_root()
        }
    }
}

mod JSON1kb {
    struct JSON {
        inner: crate::json::JSON<1024, 37, 128, 65, 2>,
    }
    impl JSON {
        fn convert(inner: Option<crate::json::JSON<1024, 37, 128, 65, 2>>) -> Option<Self> {
            Option { _is_some: inner._is_some, _value: JSON { inner: inner._value } }
        }
    }
    impl crate::JSONParserTrait for JSON {
        fn parse_json_from_string<let StringBytes: u32>(s: str<StringBytes>) -> Self {
            JSON { inner: crate::json::JSON::parse_json_from_string(s) }
        }

        fn parse_json<let StringBytes: u32>(s: [u8; StringBytes]) -> Self {
            JSON { inner: crate::json::JSON::parse_json(s) }
        }
        fn get_length(self) -> u32 {
            self.inner.get_length()
        }
        fn get_array<let KeyBytes: u32>(self, key: [u8; KeyBytes]) -> Option<Self> {
            JSON::convert(self.inner.get_array(key))
        }
        fn get_array_unchecked<let KeyBytes: u32>(self, key: [u8; KeyBytes]) -> Self {
            JSON { inner: self.inner.get_array_unchecked(key) }
        }
        fn get_array_var<let KeyBytes: u32>(self, key: BoundedVec<u8, KeyBytes>) -> Option<Self> {
            {
                JSON::convert(self.inner.get_array_var(key))
            }
        }
        fn get_array_unchecked_var<let KeyBytes: u32>(self, key: BoundedVec<u8, KeyBytes>) -> Self {
            JSON { inner: self.inner.get_array_unchecked_var(key) }
        }
        fn get_array_from_array(self, array_index: Field) -> Option<Self> {
            JSON::convert(self.inner.get_array_from_array(array_index))
        }
        fn get_array_from_array_unchecked(self, array_index: Field) -> Self {
            JSON { inner: self.inner.get_array_from_array_unchecked(array_index) }
        }
        fn map<U, let MaxElements: u32, let MaxElementBytes: u32>(
            self,
            f: fn(crate::JSONValue<MaxElementBytes>) -> U,
        ) -> [U; MaxElements]
        where
            U: std::default::Default,
        {
            self.inner.map(f)
        }
        fn get_object<let KeyBytes: u32>(self, key: [u8; KeyBytes]) -> Option<Self> {
            {
                JSON::convert(self.inner.get_object(key))
            }
        }
        fn get_object_unchecked<let KeyBytes: u32>(self, key: [u8; KeyBytes]) -> Self {
            JSON { inner: self.inner.get_object_unchecked(key) }
        }
        fn get_object_var<let KeyBytes: u32>(self, key: BoundedVec<u8, KeyBytes>) -> Option<Self> {
            {
                JSON::convert(self.inner.get_object_var(key))
            }
        }
        fn get_object_unchecked_var<let KeyBytes: u32>(
            self,
            key: BoundedVec<u8, KeyBytes>,
        ) -> Self {
            JSON { inner: self.inner.get_object_unchecked_var(key) }
        }
        fn get_object_from_array(self, array_index: Field) -> Option<Self> {
            JSON::convert(self.inner.get_object_from_array(array_index))
        }
        fn get_object_from_array_unchecked(self, array_index: Field) -> Self {
            JSON { inner: self.inner.get_object_from_array_unchecked(array_index) }
        }
        fn get_literal<let KeyBytes: u32>(self, key: [u8; KeyBytes]) -> Option<crate::JSONLiteral> {
            self.inner.get_literal(key)
        }
        fn get_literal_unchecked<let KeyBytes: u32>(
            self,
            key: [u8; KeyBytes],
        ) -> crate::JSONLiteral {
            self.inner.get_literal_unchecked(key)
        }
        fn get_literal_var<let KeyBytes: u32>(
            self,
            key: BoundedVec<u8, KeyBytes>,
        ) -> Option<crate::JSONLiteral> {
            self.inner.get_literal_var(key)
        }
        fn get_literal_unchecked_var<let KeyBytes: u32>(
            self,
            key: BoundedVec<u8, KeyBytes>,
        ) -> crate::JSONLiteral {
            self.inner.get_literal_unchecked_var(key)
        }
        fn get_literal_from_array(self, array_index: Field) -> Option<crate::JSONLiteral> {
            self.inner.get_literal_from_array(array_index)
        }
        fn get_literal_from_array_unchecked(self, array_index: Field) -> crate::JSONLiteral {
            self.inner.get_literal_from_array_unchecked(array_index)
        }
        fn get_number<let KeyBytes: u32>(self, key: [u8; KeyBytes]) -> Option<u64> {
            self.inner.get_number(key)
        }
        fn get_number_unchecked<let KeyBytes: u32>(self, key: [u8; KeyBytes]) -> u64 {
            self.inner.get_number_unchecked(key)
        }
        fn get_number_var<let KeyBytes: u32>(self, key: BoundedVec<u8, KeyBytes>) -> Option<u64> {
            self.inner.get_number_var(key)
        }
        fn get_number_unchecked_var<let KeyBytes: u32>(self, key: BoundedVec<u8, KeyBytes>) -> u64 {
            self.inner.get_number_unchecked_var(key)
        }
        fn get_number_from_array(self, array_index: Field) -> Option<u64> {
            self.inner.get_number_from_array(array_index)
        }
        fn get_number_from_array_unchecked(self, array_index: Field) -> u64 {
            self.inner.get_number_from_array_unchecked(array_index)
        }
        fn get_string<let KeyBytes: u32, let StringBytes: u32>(
            self,
            key: [u8; KeyBytes],
        ) -> Option<BoundedVec<u8, StringBytes>> {
            self.inner.get_string(key)
        }
        fn get_string_unchecked<let KeyBytes: u32, let StringBytes: u32>(
            self,
            key: [u8; KeyBytes],
        ) -> BoundedVec<u8, StringBytes> {
            self.inner.get_string_unchecked(key)
        }
        fn get_string_var<let KeyBytes: u32, let StringBytes: u32>(
            self,
            key: BoundedVec<u8, KeyBytes>,
        ) -> Option<BoundedVec<u8, StringBytes>> {
            self.inner.get_string_var(key)
        }
        fn get_string_unchecked_var<let KeyBytes: u32, let StringBytes: u32>(
            self,
            key: BoundedVec<u8, KeyBytes>,
        ) -> BoundedVec<u8, StringBytes> {
            self.inner.get_string_unchecked_var(key)
        }
        fn get_string_from_array<let StringBytes: u32>(
            self,
            array_index: Field,
        ) -> Option<BoundedVec<u8, StringBytes>> {
            self.inner.get_string_from_array(array_index)
        }
        fn get_string_from_array_unchecked<let StringBytes: u32>(
            self,
            array_index: Field,
        ) -> BoundedVec<u8, StringBytes> {
            self.inner.get_string_from_array_unchecked(array_index)
        }
        fn get_string_from_path<let KeyBytes: u32, let StringBytes: u32, let PathDepth: u32>(
            self,
            keys: [BoundedVec<u8, KeyBytes>; PathDepth],
        ) -> Option<BoundedVec<u8, StringBytes>> {
            self.inner.get_string_from_path(keys)
        }
        fn get_value<let KeyBytes: u32, let StringBytes: u32>(
            self,
            key: [u8; KeyBytes],
        ) -> Option<crate::JSONValue<StringBytes>> {
            self.inner.get_value(key)
        }
        fn get_value_unchecked<let KeyBytes: u32, let StringBytes: u32>(
            self,
            key: [u8; KeyBytes],
        ) -> crate::JSONValue<StringBytes> {
            self.inner.get_value_unchecked(key)
        }
        fn get_value_var<let KeyBytes: u32, let StringBytes: u32>(
            self,
            key: BoundedVec<u8, KeyBytes>,
        ) -> Option<crate::JSONValue<StringBytes>> {
            self.inner.get_value_var(key)
        }
        fn get_value_unchecked_var<let KeyBytes: u32, let StringBytes: u32>(
            self,
            key: BoundedVec<u8, KeyBytes>,
        ) -> crate::JSONValue<StringBytes> {
            self.inner.get_value_unchecked_var(key)
        }
        fn get_value_from_array<let StringBytes: u32>(
            self,
            array_index: Field,
        ) -> Option<crate::JSONValue<StringBytes>> {
            self.inner.get_value_from_array(array_index)
        }
        fn get_value_from_array_unchecked<let StringBytes: u32>(
            self,
            array_index: Field,
        ) -> crate::JSONValue<StringBytes> {
            self.inner.get_value_from_array_unchecked(array_index)
        }
        fn get_value_from_path<let KeyBytes: u32, let StringBytes: u32, let PathDepth: u32>(
            self,
            keys: [BoundedVec<u8, KeyBytes>; PathDepth],
        ) -> Option<crate::JSONValue<StringBytes>> {
            self.inner.get_value_from_path(keys)
        }
        fn key_exists<let KeyBytes: u32>(self, key: BoundedVec<u8, KeyBytes>) -> bool {
            self.inner.key_exists(key)
        }
        fn get_keys_at_root<let MaxNumKeys: u32, let MaxKeyBytes: u32>(
            self,
        ) -> BoundedVec<BoundedVec<u8, MaxKeyBytes>, MaxNumKeys> {
            self.inner.get_keys_at_root()
        }
    }
}

mod JSON2kb {
    struct JSON {
        inner: crate::json::JSON<2048, 70, 256, 129, 2>,
    }
    impl JSON {
        fn convert(inner: Option<crate::json::JSON<2048, 70, 256, 129, 2>>) -> Option<Self> {
            Option { _is_some: inner._is_some, _value: JSON { inner: inner._value } }
        }
    }
    impl crate::JSONParserTrait for JSON {
        fn parse_json_from_string<let StringBytes: u32>(s: str<StringBytes>) -> Self {
            JSON { inner: crate::json::JSON::parse_json_from_string(s) }
        }

        fn parse_json<let StringBytes: u32>(s: [u8; StringBytes]) -> Self {
            JSON { inner: crate::json::JSON::parse_json(s) }
        }
        fn get_length(self) -> u32 {
            self.inner.get_length()
        }
        fn get_array<let KeyBytes: u32>(self, key: [u8; KeyBytes]) -> Option<Self> {
            JSON::convert(self.inner.get_array(key))
        }
        fn get_array_unchecked<let KeyBytes: u32>(self, key: [u8; KeyBytes]) -> Self {
            JSON { inner: self.inner.get_array_unchecked(key) }
        }
        fn get_array_var<let KeyBytes: u32>(self, key: BoundedVec<u8, KeyBytes>) -> Option<Self> {
            {
                JSON::convert(self.inner.get_array_var(key))
            }
        }
        fn get_array_unchecked_var<let KeyBytes: u32>(self, key: BoundedVec<u8, KeyBytes>) -> Self {
            JSON { inner: self.inner.get_array_unchecked_var(key) }
        }
        fn get_array_from_array(self, array_index: Field) -> Option<Self> {
            JSON::convert(self.inner.get_array_from_array(array_index))
        }
        fn get_array_from_array_unchecked(self, array_index: Field) -> Self {
            JSON { inner: self.inner.get_array_from_array_unchecked(array_index) }
        }
        fn map<U, let MaxElements: u32, let MaxElementBytes: u32>(
            self,
            f: fn(crate::JSONValue<MaxElementBytes>) -> U,
        ) -> [U; MaxElements]
        where
            U: std::default::Default,
        {
            self.inner.map(f)
        }
        fn get_object<let KeyBytes: u32>(self, key: [u8; KeyBytes]) -> Option<Self> {
            {
                JSON::convert(self.inner.get_object(key))
            }
        }
        fn get_object_unchecked<let KeyBytes: u32>(self, key: [u8; KeyBytes]) -> Self {
            JSON { inner: self.inner.get_object_unchecked(key) }
        }
        fn get_object_var<let KeyBytes: u32>(self, key: BoundedVec<u8, KeyBytes>) -> Option<Self> {
            {
                JSON::convert(self.inner.get_object_var(key))
            }
        }
        fn get_object_unchecked_var<let KeyBytes: u32>(
            self,
            key: BoundedVec<u8, KeyBytes>,
        ) -> Self {
            JSON { inner: self.inner.get_object_unchecked_var(key) }
        }
        fn get_object_from_array(self, array_index: Field) -> Option<Self> {
            JSON::convert(self.inner.get_object_from_array(array_index))
        }
        fn get_object_from_array_unchecked(self, array_index: Field) -> Self {
            JSON { inner: self.inner.get_object_from_array_unchecked(array_index) }
        }
        fn get_literal<let KeyBytes: u32>(self, key: [u8; KeyBytes]) -> Option<crate::JSONLiteral> {
            self.inner.get_literal(key)
        }
        fn get_literal_unchecked<let KeyBytes: u32>(
            self,
            key: [u8; KeyBytes],
        ) -> crate::JSONLiteral {
            self.inner.get_literal_unchecked(key)
        }
        fn get_literal_var<let KeyBytes: u32>(
            self,
            key: BoundedVec<u8, KeyBytes>,
        ) -> Option<crate::JSONLiteral> {
            self.inner.get_literal_var(key)
        }
        fn get_literal_unchecked_var<let KeyBytes: u32>(
            self,
            key: BoundedVec<u8, KeyBytes>,
        ) -> crate::JSONLiteral {
            self.inner.get_literal_unchecked_var(key)
        }
        fn get_literal_from_array(self, array_index: Field) -> Option<crate::JSONLiteral> {
            self.inner.get_literal_from_array(array_index)
        }
        fn get_literal_from_array_unchecked(self, array_index: Field) -> crate::JSONLiteral {
            self.inner.get_literal_from_array_unchecked(array_index)
        }
        fn get_number<let KeyBytes: u32>(self, key: [u8; KeyBytes]) -> Option<u64> {
            self.inner.get_number(key)
        }
        fn get_number_unchecked<let KeyBytes: u32>(self, key: [u8; KeyBytes]) -> u64 {
            self.inner.get_number_unchecked(key)
        }
        fn get_number_var<let KeyBytes: u32>(self, key: BoundedVec<u8, KeyBytes>) -> Option<u64> {
            self.inner.get_number_var(key)
        }
        fn get_number_unchecked_var<let KeyBytes: u32>(self, key: BoundedVec<u8, KeyBytes>) -> u64 {
            self.inner.get_number_unchecked_var(key)
        }
        fn get_number_from_array(self, array_index: Field) -> Option<u64> {
            self.inner.get_number_from_array(array_index)
        }
        fn get_number_from_array_unchecked(self, array_index: Field) -> u64 {
            self.inner.get_number_from_array_unchecked(array_index)
        }
        fn get_string<let KeyBytes: u32, let StringBytes: u32>(
            self,
            key: [u8; KeyBytes],
        ) -> Option<BoundedVec<u8, StringBytes>> {
            self.inner.get_string(key)
        }
        fn get_string_unchecked<let KeyBytes: u32, let StringBytes: u32>(
            self,
            key: [u8; KeyBytes],
        ) -> BoundedVec<u8, StringBytes> {
            self.inner.get_string_unchecked(key)
        }
        fn get_string_var<let KeyBytes: u32, let StringBytes: u32>(
            self,
            key: BoundedVec<u8, KeyBytes>,
        ) -> Option<BoundedVec<u8, StringBytes>> {
            self.inner.get_string_var(key)
        }
        fn get_string_unchecked_var<let KeyBytes: u32, let StringBytes: u32>(
            self,
            key: BoundedVec<u8, KeyBytes>,
        ) -> BoundedVec<u8, StringBytes> {
            self.inner.get_string_unchecked_var(key)
        }
        fn get_string_from_array<let StringBytes: u32>(
            self,
            array_index: Field,
        ) -> Option<BoundedVec<u8, StringBytes>> {
            self.inner.get_string_from_array(array_index)
        }
        fn get_string_from_array_unchecked<let StringBytes: u32>(
            self,
            array_index: Field,
        ) -> BoundedVec<u8, StringBytes> {
            self.inner.get_string_from_array_unchecked(array_index)
        }
        fn get_string_from_path<let KeyBytes: u32, let StringBytes: u32, let PathDepth: u32>(
            self,
            keys: [BoundedVec<u8, KeyBytes>; PathDepth],
        ) -> Option<BoundedVec<u8, StringBytes>> {
            self.inner.get_string_from_path(keys)
        }
        fn get_value<let KeyBytes: u32, let StringBytes: u32>(
            self,
            key: [u8; KeyBytes],
        ) -> Option<crate::JSONValue<StringBytes>> {
            self.inner.get_value(key)
        }
        fn get_value_unchecked<let KeyBytes: u32, let StringBytes: u32>(
            self,
            key: [u8; KeyBytes],
        ) -> crate::JSONValue<StringBytes> {
            self.inner.get_value_unchecked(key)
        }
        fn get_value_var<let KeyBytes: u32, let StringBytes: u32>(
            self,
            key: BoundedVec<u8, KeyBytes>,
        ) -> Option<crate::JSONValue<StringBytes>> {
            self.inner.get_value_var(key)
        }
        fn get_value_unchecked_var<let KeyBytes: u32, let StringBytes: u32>(
            self,
            key: BoundedVec<u8, KeyBytes>,
        ) -> crate::JSONValue<StringBytes> {
            self.inner.get_value_unchecked_var(key)
        }
        fn get_value_from_array<let StringBytes: u32>(
            self,
            array_index: Field,
        ) -> Option<crate::JSONValue<StringBytes>> {
            self.inner.get_value_from_array(array_index)
        }
        fn get_value_from_array_unchecked<let StringBytes: u32>(
            self,
            array_index: Field,
        ) -> crate::JSONValue<StringBytes> {
            self.inner.get_value_from_array_unchecked(array_index)
        }
        fn get_value_from_path<let KeyBytes: u32, let StringBytes: u32, let PathDepth: u32>(
            self,
            keys: [BoundedVec<u8, KeyBytes>; PathDepth],
        ) -> Option<crate::JSONValue<StringBytes>> {
            self.inner.get_value_from_path(keys)
        }
        fn key_exists<let KeyBytes: u32>(self, key: BoundedVec<u8, KeyBytes>) -> bool {
            self.inner.key_exists(key)
        }
        fn get_keys_at_root<let MaxNumKeys: u32, let MaxKeyBytes: u32>(
            self,
        ) -> BoundedVec<BoundedVec<u8, MaxKeyBytes>, MaxNumKeys> {
            self.inner.get_keys_at_root()
        }
    }
}

mod JSON4kb {
    struct JSON {
        inner: crate::json::JSON<4096, 136, 512, 257, 2>,
    }
    impl JSON {
        fn convert(inner: Option<crate::json::JSON<4096, 136, 512, 257, 2>>) -> Option<Self> {
            Option { _is_some: inner._is_some, _value: JSON { inner: inner._value } }
        }
    }
    impl crate::JSONParserTrait for JSON {
        fn parse_json_from_string<let StringBytes: u32>(s: str<StringBytes>) -> Self {
            JSON { inner: crate::json::JSON::parse_json_from_string(s) }
        }

        fn parse_json<let StringBytes: u32>(s: [u8; StringBytes]) -> Self {
            JSON { inner: crate::json::JSON::parse_json(s) }
        }
        fn get_length(self) -> u32 {
            self.inner.get_length()
        }
        fn get_array<let KeyBytes: u32>(self, key: [u8; KeyBytes]) -> Option<Self> {
            JSON::convert(self.inner.get_array(key))
        }
        fn get_array_unchecked<let KeyBytes: u32>(self, key: [u8; KeyBytes]) -> Self {
            JSON { inner: self.inner.get_array_unchecked(key) }
        }
        fn get_array_var<let KeyBytes: u32>(self, key: BoundedVec<u8, KeyBytes>) -> Option<Self> {
            {
                JSON::convert(self.inner.get_array_var(key))
            }
        }
        fn get_array_unchecked_var<let KeyBytes: u32>(self, key: BoundedVec<u8, KeyBytes>) -> Self {
            JSON { inner: self.inner.get_array_unchecked_var(key) }
        }
        fn get_array_from_array(self, array_index: Field) -> Option<Self> {
            JSON::convert(self.inner.get_array_from_array(array_index))
        }
        fn get_array_from_array_unchecked(self, array_index: Field) -> Self {
            JSON { inner: self.inner.get_array_from_array_unchecked(array_index) }
        }
        fn map<U, let MaxElements: u32, let MaxElementBytes: u32>(
            self,
            f: fn(crate::JSONValue<MaxElementBytes>) -> U,
        ) -> [U; MaxElements]
        where
            U: std::default::Default,
        {
            self.inner.map(f)
        }
        fn get_object<let KeyBytes: u32>(self, key: [u8; KeyBytes]) -> Option<Self> {
            {
                JSON::convert(self.inner.get_object(key))
            }
        }
        fn get_object_unchecked<let KeyBytes: u32>(self, key: [u8; KeyBytes]) -> Self {
            JSON { inner: self.inner.get_object_unchecked(key) }
        }
        fn get_object_var<let KeyBytes: u32>(self, key: BoundedVec<u8, KeyBytes>) -> Option<Self> {
            {
                JSON::convert(self.inner.get_object_var(key))
            }
        }
        fn get_object_unchecked_var<let KeyBytes: u32>(
            self,
            key: BoundedVec<u8, KeyBytes>,
        ) -> Self {
            JSON { inner: self.inner.get_object_unchecked_var(key) }
        }
        fn get_object_from_array(self, array_index: Field) -> Option<Self> {
            JSON::convert(self.inner.get_object_from_array(array_index))
        }
        fn get_object_from_array_unchecked(self, array_index: Field) -> Self {
            JSON { inner: self.inner.get_object_from_array_unchecked(array_index) }
        }
        fn get_literal<let KeyBytes: u32>(self, key: [u8; KeyBytes]) -> Option<crate::JSONLiteral> {
            self.inner.get_literal(key)
        }
        fn get_literal_unchecked<let KeyBytes: u32>(
            self,
            key: [u8; KeyBytes],
        ) -> crate::JSONLiteral {
            self.inner.get_literal_unchecked(key)
        }
        fn get_literal_var<let KeyBytes: u32>(
            self,
            key: BoundedVec<u8, KeyBytes>,
        ) -> Option<crate::JSONLiteral> {
            self.inner.get_literal_var(key)
        }
        fn get_literal_unchecked_var<let KeyBytes: u32>(
            self,
            key: BoundedVec<u8, KeyBytes>,
        ) -> crate::JSONLiteral {
            self.inner.get_literal_unchecked_var(key)
        }
        fn get_literal_from_array(self, array_index: Field) -> Option<crate::JSONLiteral> {
            self.inner.get_literal_from_array(array_index)
        }
        fn get_literal_from_array_unchecked(self, array_index: Field) -> crate::JSONLiteral {
            self.inner.get_literal_from_array_unchecked(array_index)
        }
        fn get_number<let KeyBytes: u32>(self, key: [u8; KeyBytes]) -> Option<u64> {
            self.inner.get_number(key)
        }
        fn get_number_unchecked<let KeyBytes: u32>(self, key: [u8; KeyBytes]) -> u64 {
            self.inner.get_number_unchecked(key)
        }
        fn get_number_var<let KeyBytes: u32>(self, key: BoundedVec<u8, KeyBytes>) -> Option<u64> {
            self.inner.get_number_var(key)
        }
        fn get_number_unchecked_var<let KeyBytes: u32>(self, key: BoundedVec<u8, KeyBytes>) -> u64 {
            self.inner.get_number_unchecked_var(key)
        }
        fn get_number_from_array(self, array_index: Field) -> Option<u64> {
            self.inner.get_number_from_array(array_index)
        }
        fn get_number_from_array_unchecked(self, array_index: Field) -> u64 {
            self.inner.get_number_from_array_unchecked(array_index)
        }
        fn get_string<let KeyBytes: u32, let StringBytes: u32>(
            self,
            key: [u8; KeyBytes],
        ) -> Option<BoundedVec<u8, StringBytes>> {
            self.inner.get_string(key)
        }
        fn get_string_unchecked<let KeyBytes: u32, let StringBytes: u32>(
            self,
            key: [u8; KeyBytes],
        ) -> BoundedVec<u8, StringBytes> {
            self.inner.get_string_unchecked(key)
        }
        fn get_string_var<let KeyBytes: u32, let StringBytes: u32>(
            self,
            key: BoundedVec<u8, KeyBytes>,
        ) -> Option<BoundedVec<u8, StringBytes>> {
            self.inner.get_string_var(key)
        }
        fn get_string_unchecked_var<let KeyBytes: u32, let StringBytes: u32>(
            self,
            key: BoundedVec<u8, KeyBytes>,
        ) -> BoundedVec<u8, StringBytes> {
            self.inner.get_string_unchecked_var(key)
        }
        fn get_string_from_array<let StringBytes: u32>(
            self,
            array_index: Field,
        ) -> Option<BoundedVec<u8, StringBytes>> {
            self.inner.get_string_from_array(array_index)
        }
        fn get_string_from_array_unchecked<let StringBytes: u32>(
            self,
            array_index: Field,
        ) -> BoundedVec<u8, StringBytes> {
            self.inner.get_string_from_array_unchecked(array_index)
        }
        fn get_string_from_path<let KeyBytes: u32, let StringBytes: u32, let PathDepth: u32>(
            self,
            keys: [BoundedVec<u8, KeyBytes>; PathDepth],
        ) -> Option<BoundedVec<u8, StringBytes>> {
            self.inner.get_string_from_path(keys)
        }
        fn get_value<let KeyBytes: u32, let StringBytes: u32>(
            self,
            key: [u8; KeyBytes],
        ) -> Option<crate::JSONValue<StringBytes>> {
            self.inner.get_value(key)
        }
        fn get_value_unchecked<let KeyBytes: u32, let StringBytes: u32>(
            self,
            key: [u8; KeyBytes],
        ) -> crate::JSONValue<StringBytes> {
            self.inner.get_value_unchecked(key)
        }
        fn get_value_var<let KeyBytes: u32, let StringBytes: u32>(
            self,
            key: BoundedVec<u8, KeyBytes>,
        ) -> Option<crate::JSONValue<StringBytes>> {
            self.inner.get_value_var(key)
        }
        fn get_value_unchecked_var<let KeyBytes: u32, let StringBytes: u32>(
            self,
            key: BoundedVec<u8, KeyBytes>,
        ) -> crate::JSONValue<StringBytes> {
            self.inner.get_value_unchecked_var(key)
        }
        fn get_value_from_array<let StringBytes: u32>(
            self,
            array_index: Field,
        ) -> Option<crate::JSONValue<StringBytes>> {
            self.inner.get_value_from_array(array_index)
        }
        fn get_value_from_array_unchecked<let StringBytes: u32>(
            self,
            array_index: Field,
        ) -> crate::JSONValue<StringBytes> {
            self.inner.get_value_from_array_unchecked(array_index)
        }
        fn get_value_from_path<let KeyBytes: u32, let StringBytes: u32, let PathDepth: u32>(
            self,
            keys: [BoundedVec<u8, KeyBytes>; PathDepth],
        ) -> Option<crate::JSONValue<StringBytes>> {
            self.inner.get_value_from_path(keys)
        }
        fn key_exists<let KeyBytes: u32>(self, key: BoundedVec<u8, KeyBytes>) -> bool {
            self.inner.key_exists(key)
        }
        fn get_keys_at_root<let MaxNumKeys: u32, let MaxKeyBytes: u32>(
            self,
        ) -> BoundedVec<BoundedVec<u8, MaxKeyBytes>, MaxNumKeys> {
            self.inner.get_keys_at_root()
        }
    }
}

mod JSON8kb {
    struct JSON {
        inner: crate::json::JSON<8192, 268, 1024, 513, 2>,
    }
    impl JSON {
        fn convert(inner: Option<crate::json::JSON<8192, 268, 1024, 513, 2>>) -> Option<Self> {
            Option { _is_some: inner._is_some, _value: JSON { inner: inner._value } }
        }
    }
    impl crate::JSONParserTrait for JSON {
        fn parse_json_from_string<let StringBytes: u32>(s: str<StringBytes>) -> Self {
            JSON { inner: crate::json::JSON::parse_json_from_string(s) }
        }

        fn parse_json<let StringBytes: u32>(s: [u8; StringBytes]) -> Self {
            JSON { inner: crate::json::JSON::parse_json(s) }
        }
        fn get_length(self) -> u32 {
            self.inner.get_length()
        }
        fn get_array<let KeyBytes: u32>(self, key: [u8; KeyBytes]) -> Option<Self> {
            JSON::convert(self.inner.get_array(key))
        }
        fn get_array_unchecked<let KeyBytes: u32>(self, key: [u8; KeyBytes]) -> Self {
            JSON { inner: self.inner.get_array_unchecked(key) }
        }
        fn get_array_var<let KeyBytes: u32>(self, key: BoundedVec<u8, KeyBytes>) -> Option<Self> {
            {
                JSON::convert(self.inner.get_array_var(key))
            }
        }
        fn get_array_unchecked_var<let KeyBytes: u32>(self, key: BoundedVec<u8, KeyBytes>) -> Self {
            JSON { inner: self.inner.get_array_unchecked_var(key) }
        }
        fn get_array_from_array(self, array_index: Field) -> Option<Self> {
            JSON::convert(self.inner.get_array_from_array(array_index))
        }
        fn get_array_from_array_unchecked(self, array_index: Field) -> Self {
            JSON { inner: self.inner.get_array_from_array_unchecked(array_index) }
        }
        fn map<U, let MaxElements: u32, let MaxElementBytes: u32>(
            self,
            f: fn(crate::JSONValue<MaxElementBytes>) -> U,
        ) -> [U; MaxElements]
        where
            U: std::default::Default,
        {
            self.inner.map(f)
        }
        fn get_object<let KeyBytes: u32>(self, key: [u8; KeyBytes]) -> Option<Self> {
            {
                JSON::convert(self.inner.get_object(key))
            }
        }
        fn get_object_unchecked<let KeyBytes: u32>(self, key: [u8; KeyBytes]) -> Self {
            JSON { inner: self.inner.get_object_unchecked(key) }
        }
        fn get_object_var<let KeyBytes: u32>(self, key: BoundedVec<u8, KeyBytes>) -> Option<Self> {
            {
                JSON::convert(self.inner.get_object_var(key))
            }
        }
        fn get_object_unchecked_var<let KeyBytes: u32>(
            self,
            key: BoundedVec<u8, KeyBytes>,
        ) -> Self {
            JSON { inner: self.inner.get_object_unchecked_var(key) }
        }
        fn get_object_from_array(self, array_index: Field) -> Option<Self> {
            JSON::convert(self.inner.get_object_from_array(array_index))
        }
        fn get_object_from_array_unchecked(self, array_index: Field) -> Self {
            JSON { inner: self.inner.get_object_from_array_unchecked(array_index) }
        }
        fn get_literal<let KeyBytes: u32>(self, key: [u8; KeyBytes]) -> Option<crate::JSONLiteral> {
            self.inner.get_literal(key)
        }
        fn get_literal_unchecked<let KeyBytes: u32>(
            self,
            key: [u8; KeyBytes],
        ) -> crate::JSONLiteral {
            self.inner.get_literal_unchecked(key)
        }
        fn get_literal_var<let KeyBytes: u32>(
            self,
            key: BoundedVec<u8, KeyBytes>,
        ) -> Option<crate::JSONLiteral> {
            self.inner.get_literal_var(key)
        }
        fn get_literal_unchecked_var<let KeyBytes: u32>(
            self,
            key: BoundedVec<u8, KeyBytes>,
        ) -> crate::JSONLiteral {
            self.inner.get_literal_unchecked_var(key)
        }
        fn get_literal_from_array(self, array_index: Field) -> Option<crate::JSONLiteral> {
            self.inner.get_literal_from_array(array_index)
        }
        fn get_literal_from_array_unchecked(self, array_index: Field) -> crate::JSONLiteral {
            self.inner.get_literal_from_array_unchecked(array_index)
        }
        fn get_number<let KeyBytes: u32>(self, key: [u8; KeyBytes]) -> Option<u64> {
            self.inner.get_number(key)
        }
        fn get_number_unchecked<let KeyBytes: u32>(self, key: [u8; KeyBytes]) -> u64 {
            self.inner.get_number_unchecked(key)
        }
        fn get_number_var<let KeyBytes: u32>(self, key: BoundedVec<u8, KeyBytes>) -> Option<u64> {
            self.inner.get_number_var(key)
        }
        fn get_number_unchecked_var<let KeyBytes: u32>(self, key: BoundedVec<u8, KeyBytes>) -> u64 {
            self.inner.get_number_unchecked_var(key)
        }
        fn get_number_from_array(self, array_index: Field) -> Option<u64> {
            self.inner.get_number_from_array(array_index)
        }
        fn get_number_from_array_unchecked(self, array_index: Field) -> u64 {
            self.inner.get_number_from_array_unchecked(array_index)
        }
        fn get_string<let KeyBytes: u32, let StringBytes: u32>(
            self,
            key: [u8; KeyBytes],
        ) -> Option<BoundedVec<u8, StringBytes>> {
            self.inner.get_string(key)
        }
        fn get_string_unchecked<let KeyBytes: u32, let StringBytes: u32>(
            self,
            key: [u8; KeyBytes],
        ) -> BoundedVec<u8, StringBytes> {
            self.inner.get_string_unchecked(key)
        }
        fn get_string_var<let KeyBytes: u32, let StringBytes: u32>(
            self,
            key: BoundedVec<u8, KeyBytes>,
        ) -> Option<BoundedVec<u8, StringBytes>> {
            self.inner.get_string_var(key)
        }
        fn get_string_unchecked_var<let KeyBytes: u32, let StringBytes: u32>(
            self,
            key: BoundedVec<u8, KeyBytes>,
        ) -> BoundedVec<u8, StringBytes> {
            self.inner.get_string_unchecked_var(key)
        }
        fn get_string_from_array<let StringBytes: u32>(
            self,
            array_index: Field,
        ) -> Option<BoundedVec<u8, StringBytes>> {
            self.inner.get_string_from_array(array_index)
        }
        fn get_string_from_array_unchecked<let StringBytes: u32>(
            self,
            array_index: Field,
        ) -> BoundedVec<u8, StringBytes> {
            self.inner.get_string_from_array_unchecked(array_index)
        }
        fn get_string_from_path<let KeyBytes: u32, let StringBytes: u32, let PathDepth: u32>(
            self,
            keys: [BoundedVec<u8, KeyBytes>; PathDepth],
        ) -> Option<BoundedVec<u8, StringBytes>> {
            self.inner.get_string_from_path(keys)
        }
        fn get_value<let KeyBytes: u32, let StringBytes: u32>(
            self,
            key: [u8; KeyBytes],
        ) -> Option<crate::JSONValue<StringBytes>> {
            self.inner.get_value(key)
        }
        fn get_value_unchecked<let KeyBytes: u32, let StringBytes: u32>(
            self,
            key: [u8; KeyBytes],
        ) -> crate::JSONValue<StringBytes> {
            self.inner.get_value_unchecked(key)
        }
        fn get_value_var<let KeyBytes: u32, let StringBytes: u32>(
            self,
            key: BoundedVec<u8, KeyBytes>,
        ) -> Option<crate::JSONValue<StringBytes>> {
            self.inner.get_value_var(key)
        }
        fn get_value_unchecked_var<let KeyBytes: u32, let StringBytes: u32>(
            self,
            key: BoundedVec<u8, KeyBytes>,
        ) -> crate::JSONValue<StringBytes> {
            self.inner.get_value_unchecked_var(key)
        }
        fn get_value_from_array<let StringBytes: u32>(
            self,
            array_index: Field,
        ) -> Option<crate::JSONValue<StringBytes>> {
            self.inner.get_value_from_array(array_index)
        }
        fn get_value_from_array_unchecked<let StringBytes: u32>(
            self,
            array_index: Field,
        ) -> crate::JSONValue<StringBytes> {
            self.inner.get_value_from_array_unchecked(array_index)
        }
        fn get_value_from_path<let KeyBytes: u32, let StringBytes: u32, let PathDepth: u32>(
            self,
            keys: [BoundedVec<u8, KeyBytes>; PathDepth],
        ) -> Option<crate::JSONValue<StringBytes>> {
            self.inner.get_value_from_path(keys)
        }
        fn key_exists<let KeyBytes: u32>(self, key: BoundedVec<u8, KeyBytes>) -> bool {
            self.inner.key_exists(key)
        }
        fn get_keys_at_root<let MaxNumKeys: u32, let MaxKeyBytes: u32>(
            self,
        ) -> BoundedVec<BoundedVec<u8, MaxKeyBytes>, MaxNumKeys> {
            self.inner.get_keys_at_root()
        }
    }
}

mod JSON16kb {
    struct JSON {
        inner: crate::json::JSON<16384, 532, 2048, 1025, 2>,
    }
    impl JSON {
        fn convert(inner: Option<crate::json::JSON<16384, 532, 2048, 1025, 2>>) -> Option<Self> {
            Option { _is_some: inner._is_some, _value: JSON { inner: inner._value } }
        }
    }
    impl crate::JSONParserTrait for JSON {
        fn parse_json_from_string<let StringBytes: u32>(s: str<StringBytes>) -> Self {
            JSON { inner: crate::json::JSON::parse_json_from_string(s) }
        }

        fn parse_json<let StringBytes: u32>(s: [u8; StringBytes]) -> Self {
            JSON { inner: crate::json::JSON::parse_json(s) }
        }
        fn get_length(self) -> u32 {
            self.inner.get_length()
        }
        fn get_array<let KeyBytes: u32>(self, key: [u8; KeyBytes]) -> Option<Self> {
            JSON::convert(self.inner.get_array(key))
        }
        fn get_array_unchecked<let KeyBytes: u32>(self, key: [u8; KeyBytes]) -> Self {
            JSON { inner: self.inner.get_array_unchecked(key) }
        }
        fn get_array_var<let KeyBytes: u32>(self, key: BoundedVec<u8, KeyBytes>) -> Option<Self> {
            {
                JSON::convert(self.inner.get_array_var(key))
            }
        }
        fn get_array_unchecked_var<let KeyBytes: u32>(self, key: BoundedVec<u8, KeyBytes>) -> Self {
            JSON { inner: self.inner.get_array_unchecked_var(key) }
        }
        fn get_array_from_array(self, array_index: Field) -> Option<Self> {
            JSON::convert(self.inner.get_array_from_array(array_index))
        }
        fn get_array_from_array_unchecked(self, array_index: Field) -> Self {
            JSON { inner: self.inner.get_array_from_array_unchecked(array_index) }
        }
        fn map<U, let MaxElements: u32, let MaxElementBytes: u32>(
            self,
            f: fn(crate::JSONValue<MaxElementBytes>) -> U,
        ) -> [U; MaxElements]
        where
            U: std::default::Default,
        {
            self.inner.map(f)
        }
        fn get_object<let KeyBytes: u32>(self, key: [u8; KeyBytes]) -> Option<Self> {
            {
                JSON::convert(self.inner.get_object(key))
            }
        }
        fn get_object_unchecked<let KeyBytes: u32>(self, key: [u8; KeyBytes]) -> Self {
            JSON { inner: self.inner.get_object_unchecked(key) }
        }
        fn get_object_var<let KeyBytes: u32>(self, key: BoundedVec<u8, KeyBytes>) -> Option<Self> {
            {
                JSON::convert(self.inner.get_object_var(key))
            }
        }
        fn get_object_unchecked_var<let KeyBytes: u32>(
            self,
            key: BoundedVec<u8, KeyBytes>,
        ) -> Self {
            JSON { inner: self.inner.get_object_unchecked_var(key) }
        }
        fn get_object_from_array(self, array_index: Field) -> Option<Self> {
            JSON::convert(self.inner.get_object_from_array(array_index))
        }
        fn get_object_from_array_unchecked(self, array_index: Field) -> Self {
            JSON { inner: self.inner.get_object_from_array_unchecked(array_index) }
        }
        fn get_literal<let KeyBytes: u32>(self, key: [u8; KeyBytes]) -> Option<crate::JSONLiteral> {
            self.inner.get_literal(key)
        }
        fn get_literal_unchecked<let KeyBytes: u32>(
            self,
            key: [u8; KeyBytes],
        ) -> crate::JSONLiteral {
            self.inner.get_literal_unchecked(key)
        }
        fn get_literal_var<let KeyBytes: u32>(
            self,
            key: BoundedVec<u8, KeyBytes>,
        ) -> Option<crate::JSONLiteral> {
            self.inner.get_literal_var(key)
        }
        fn get_literal_unchecked_var<let KeyBytes: u32>(
            self,
            key: BoundedVec<u8, KeyBytes>,
        ) -> crate::JSONLiteral {
            self.inner.get_literal_unchecked_var(key)
        }
        fn get_literal_from_array(self, array_index: Field) -> Option<crate::JSONLiteral> {
            self.inner.get_literal_from_array(array_index)
        }
        fn get_literal_from_array_unchecked(self, array_index: Field) -> crate::JSONLiteral {
            self.inner.get_literal_from_array_unchecked(array_index)
        }
        fn get_number<let KeyBytes: u32>(self, key: [u8; KeyBytes]) -> Option<u64> {
            self.inner.get_number(key)
        }
        fn get_number_unchecked<let KeyBytes: u32>(self, key: [u8; KeyBytes]) -> u64 {
            self.inner.get_number_unchecked(key)
        }
        fn get_number_var<let KeyBytes: u32>(self, key: BoundedVec<u8, KeyBytes>) -> Option<u64> {
            self.inner.get_number_var(key)
        }
        fn get_number_unchecked_var<let KeyBytes: u32>(self, key: BoundedVec<u8, KeyBytes>) -> u64 {
            self.inner.get_number_unchecked_var(key)
        }
        fn get_number_from_array(self, array_index: Field) -> Option<u64> {
            self.inner.get_number_from_array(array_index)
        }
        fn get_number_from_array_unchecked(self, array_index: Field) -> u64 {
            self.inner.get_number_from_array_unchecked(array_index)
        }
        fn get_string<let KeyBytes: u32, let StringBytes: u32>(
            self,
            key: [u8; KeyBytes],
        ) -> Option<BoundedVec<u8, StringBytes>> {
            self.inner.get_string(key)
        }
        fn get_string_unchecked<let KeyBytes: u32, let StringBytes: u32>(
            self,
            key: [u8; KeyBytes],
        ) -> BoundedVec<u8, StringBytes> {
            self.inner.get_string_unchecked(key)
        }
        fn get_string_var<let KeyBytes: u32, let StringBytes: u32>(
            self,
            key: BoundedVec<u8, KeyBytes>,
        ) -> Option<BoundedVec<u8, StringBytes>> {
            self.inner.get_string_var(key)
        }
        fn get_string_unchecked_var<let KeyBytes: u32, let StringBytes: u32>(
            self,
            key: BoundedVec<u8, KeyBytes>,
        ) -> BoundedVec<u8, StringBytes> {
            self.inner.get_string_unchecked_var(key)
        }
        fn get_string_from_array<let StringBytes: u32>(
            self,
            array_index: Field,
        ) -> Option<BoundedVec<u8, StringBytes>> {
            self.inner.get_string_from_array(array_index)
        }
        fn get_string_from_array_unchecked<let StringBytes: u32>(
            self,
            array_index: Field,
        ) -> BoundedVec<u8, StringBytes> {
            self.inner.get_string_from_array_unchecked(array_index)
        }
        fn get_string_from_path<let KeyBytes: u32, let StringBytes: u32, let PathDepth: u32>(
            self,
            keys: [BoundedVec<u8, KeyBytes>; PathDepth],
        ) -> Option<BoundedVec<u8, StringBytes>> {
            self.inner.get_string_from_path(keys)
        }
        fn get_value<let KeyBytes: u32, let StringBytes: u32>(
            self,
            key: [u8; KeyBytes],
        ) -> Option<crate::JSONValue<StringBytes>> {
            self.inner.get_value(key)
        }
        fn get_value_unchecked<let KeyBytes: u32, let StringBytes: u32>(
            self,
            key: [u8; KeyBytes],
        ) -> crate::JSONValue<StringBytes> {
            self.inner.get_value_unchecked(key)
        }
        fn get_value_var<let KeyBytes: u32, let StringBytes: u32>(
            self,
            key: BoundedVec<u8, KeyBytes>,
        ) -> Option<crate::JSONValue<StringBytes>> {
            self.inner.get_value_var(key)
        }
        fn get_value_unchecked_var<let KeyBytes: u32, let StringBytes: u32>(
            self,
            key: BoundedVec<u8, KeyBytes>,
        ) -> crate::JSONValue<StringBytes> {
            self.inner.get_value_unchecked_var(key)
        }
        fn get_value_from_array<let StringBytes: u32>(
            self,
            array_index: Field,
        ) -> Option<crate::JSONValue<StringBytes>> {
            self.inner.get_value_from_array(array_index)
        }
        fn get_value_from_array_unchecked<let StringBytes: u32>(
            self,
            array_index: Field,
        ) -> crate::JSONValue<StringBytes> {
            self.inner.get_value_from_array_unchecked(array_index)
        }
        fn get_value_from_path<let KeyBytes: u32, let StringBytes: u32, let PathDepth: u32>(
            self,
            keys: [BoundedVec<u8, KeyBytes>; PathDepth],
        ) -> Option<crate::JSONValue<StringBytes>> {
            self.inner.get_value_from_path(keys)
        }
        fn key_exists<let KeyBytes: u32>(self, key: BoundedVec<u8, KeyBytes>) -> bool {
            self.inner.key_exists(key)
        }
        fn get_keys_at_root<let MaxNumKeys: u32, let MaxKeyBytes: u32>(
            self,
        ) -> BoundedVec<BoundedVec<u8, MaxKeyBytes>, MaxNumKeys> {
            self.inner.get_keys_at_root()
        }
    }
}
