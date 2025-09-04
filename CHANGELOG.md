# Changelog

## [0.5.0](https://github.com/noir-lang/noir_json_parser/compare/v0.4.0...v0.5.0) (2025-09-04)


### ⚠ BREAKING CHANGES

* fix a bunch of visibility issues ([#38](https://github.com/noir-lang/noir_json_parser/issues/38))

### Features

* Make get functions public ([#91](https://github.com/noir-lang/noir_json_parser/issues/91)) ([601ec49](https://github.com/noir-lang/noir_json_parser/commit/601ec4999c5f3c7a7d175edacdcf37233d36a8a8))
* Removes redundant `_var` and `_unchecked_var` function variants ([#90](https://github.com/noir-lang/noir_json_parser/issues/90)) ([37908a7](https://github.com/noir-lang/noir_json_parser/commit/37908a71789464caff9b6a4333ef8232fd93f830))


### Bug Fixes

* Add missing generic ([#44](https://github.com/noir-lang/noir_json_parser/issues/44)) ([b6b35ef](https://github.com/noir-lang/noir_json_parser/commit/b6b35efa1e26dcb071acd0b9bd33f1c8247b9bf1))
* Add validation for literals ([#64](https://github.com/noir-lang/noir_json_parser/issues/64)) ([8adc6a8](https://github.com/noir-lang/noir_json_parser/commit/8adc6a84e51e59fb1c224ac3206604186f869083))
* Do not cast numbers to bool ([#45](https://github.com/noir-lang/noir_json_parser/issues/45)) ([eb041f7](https://github.com/noir-lang/noir_json_parser/commit/eb041f7f72c2370a0063c8b2e1ed0ee64b5b21ff))


### Miscellaneous Chores

* Fix a bunch of visibility issues ([#38](https://github.com/noir-lang/noir_json_parser/issues/38)) ([e45c9b9](https://github.com/noir-lang/noir_json_parser/commit/e45c9b9ba2419ac5310408939baed36def342db1))

## [0.4.0](https://github.com/noir-lang/noir_json_parser/compare/v0.3.0...v0.4.0) (2025-02-13)


### ⚠ BREAKING CHANGES

* fixed invalid json passing as valid json ([#32](https://github.com/noir-lang/noir_json_parser/issues/32))
* replace fixed size JSON modules with type aliases ([#19](https://github.com/noir-lang/noir_json_parser/issues/19))

### Bug Fixes

* Add safety blocks and safety comments ([#31](https://github.com/noir-lang/noir_json_parser/issues/31)) ([b6bbbd1](https://github.com/noir-lang/noir_json_parser/commit/b6bbbd1ec549c67842790d3396059265b324efdb))
* Export types mistakenly left private ([#27](https://github.com/noir-lang/noir_json_parser/issues/27)) ([682df8b](https://github.com/noir-lang/noir_json_parser/commit/682df8b6b734a7058c57d8ac58766b3ca7592df2))
* Fixed invalid json passing as valid json ([#32](https://github.com/noir-lang/noir_json_parser/issues/32)) ([cfb29f8](https://github.com/noir-lang/noir_json_parser/commit/cfb29f854d12ca351ed0143f68440695975efc59))


### Miscellaneous Chores

* Replace fixed size JSON modules with type aliases ([#19](https://github.com/noir-lang/noir_json_parser/issues/19)) ([e5669b6](https://github.com/noir-lang/noir_json_parser/commit/e5669b6ed89a4b047bb7dcaf33c6f4b99c7e42f2))

## [0.3.0](https://github.com/noir-lang/noir_json_parser/compare/v0.2.0...v0.3.0) (2024-11-25)


### ⚠ BREAKING CHANGES

* update to support Noir 0.37.0 ([#16](https://github.com/noir-lang/noir_json_parser/issues/16))

### Features

* Update to support Noir 0.37.0 ([#16](https://github.com/noir-lang/noir_json_parser/issues/16)) ([b31c3a7](https://github.com/noir-lang/noir_json_parser/commit/b31c3a7ad950634031ae692941e23a2f6f0b035e))


### Bug Fixes

* Add type declarations to globals ([#21](https://github.com/noir-lang/noir_json_parser/issues/21)) ([c32dcd5](https://github.com/noir-lang/noir_json_parser/commit/c32dcd5bc6c924b613500122bb84ca8cc94c6cb9))

## 0.2.0 (2024-09-27)


### ⚠ BREAKING CHANGES

* replace usage of u16s in generics with u32s ([#12](https://github.com/noir-lang/noir_json_parser/issues/12))
* update to 0.34.0 ([#6](https://github.com/noir-lang/noir_json_parser/issues/6))

### Features

* Update to 0.34.0 ([#6](https://github.com/noir-lang/noir_json_parser/issues/6)) ([ec163ab](https://github.com/noir-lang/noir_json_parser/commit/ec163ab7d1564db54a2db1f64ee479cc14dbdd68))


### Bug Fixes

* Replace usage of u16s in generics with u32s ([#12](https://github.com/noir-lang/noir_json_parser/issues/12)) ([09a5bde](https://github.com/noir-lang/noir_json_parser/commit/09a5bde90e7c5f1eb221a0da986b7e88113c187d))
