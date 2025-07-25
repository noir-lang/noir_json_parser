use crate::{JSON16kb, JSON512b, json::JSON};

comptime fn make_bench(m: Module, params: Quoted) -> Quoted {
    let module_name = m.name();
    let parse_json_from_string = f"parse_json_from_string_{module_name}".quoted_contents();
    let parse_json = f"parse_json_{module_name}".quoted_contents();
    let get_array = f"get_array_{module_name}".quoted_contents();
    let get_object = f"get_object_{module_name}".quoted_contents();
    let get_literal = f"get_literal_{module_name}".quoted_contents();
    let get_number = f"get_number_{module_name}".quoted_contents();
    let get_string = f"get_string_{module_name}".quoted_contents();
    let get_value = f"get_value_{module_name}".quoted_contents();
    let key_exists = f"key_exists_{module_name}".quoted_contents();
    let get_keys_at_root = f"get_keys_at_root_{module_name}".quoted_contents();
    let JSON = quote { crate::json::JSON };
    let JSONLiteral = quote { crate::get_literal::JSONLiteral };
    let JSONValue = quote { crate::json::JSONValue<1024> };
    let typ = params.as_type();

    quote {
        #[export]
        fn $parse_json_from_string(s: str<1024>) -> $typ{
            $JSON::parse_json_from_string(s)
        }

        #[export]
        fn $parse_json(s: [u8; 1024]) -> $typ{
            $JSON::parse_json(s)
        }

        #[export]
        fn $get_array(s: $typ, key: [u8; 1024]) -> Option<$typ>{
            $JSON::get_array(s,key)
        }

        #[export]
        fn $get_object(s: $typ, key: [u8; 1024]) -> Option<$typ>{
            $JSON::get_object(s,key)
        }

        #[export]
        fn $get_literal(s: $typ, key: [u8; 1024]) -> Option<$JSONLiteral>{
            $JSON::get_literal(s,key)
        }

        #[export]
        fn $get_number(s: $typ, key: [u8; 1024]) -> Option<u64>{
            $JSON::get_number(s,key)
        }

        #[export]
        fn $get_string(s: $typ, key: [u8; 1024]) -> Option<BoundedVec<u8, 1024>>{
            $JSON::get_string(s,key)
        }

        #[export]
        fn $get_value(s: $typ, key: [u8; 1024]) -> Option<$JSONValue>{
            $JSON::get_value(s,key)
        }

        #[export]
        fn $key_exists(s: $typ, key: BoundedVec<u8, 1024>) -> bool{
            $JSON::key_exists(s, key)
        }
        
        #[export]
        fn $get_keys_at_root(s: $typ) -> BoundedVec<BoundedVec<u8, 1024>, 1024>{
            $JSON::get_keys_at_root(s)
        }

        
}
}

#[make_bench(quote { JSON512b })]
mod JSON512b_Bench {}

#[make_bench(quote { JSON16kb })]
mod JSON16kb_Bench {}
