
use crate::{json::JSON, JSON512b, JSON1kb, JSON2kb, JSON4kb, JSON8kb, JSON16kb};

//#[export]
//fn test_capture_missing_tokens(j: &mut JSON512b){
    //JSON::capture_missing_tokens(j)
//}

/**
#[export]
fn test_parse_json_from_string(s: str<1024>) -> JSON512b{
    let json = JSON::parse_json_from_string(s);
    json
}
**/
comptime fn make_bench(m: Module, params: Quoted) -> Quoted {
    let module_name = m.name();
    let parse_json_from_string = f"parse_json_from_string_{module_name}".quoted_contents();
    let validate_on_curve_bench_name = f"validate_on_curve_{module_name}".quoted_contents();
   
    let JSON = quote { crate::json::JSON };
    // let ScalarField = quote { crate::ScalarField };

    let typ = params.as_type();

    quote {
        /**
        #[export]
        fn $eq_bench_name(a: $typ, b: $typ) -> bool {
            a==b
        }
        #[export]
        fn $validate_on_curve_bench_name(a: $typ) {
            $BigCurve::validate_on_curve(a);
        }

        #[export]
        fn $mul_bench_name(a: $typ, b: $ScalarField<64>) -> $typ {
            $BigCurve::mul(a, b)
        }

        #[export]
        fn $hash_to_curve_bench_name(a: [u8; 10]) -> $typ {
            $BigCurve::hash_to_curve(a)
        }

        #[export]
        fn $evaluate_linear_expression_bench_name(a: [$typ; 3], b: [$ScalarField<64>; 3], c: [$typ; 2]) -> $typ {
            $BigCurve::evaluate_linear_expression(a, b, c)
        }**/

        #[export]
        fn $parse_json_from_string(s: str<1024>) -> $typ{
            let json = $JSON::parse_json_from_string(s);
            json
}

    }
}


#[make_bench(quote { JSON512b })]
mod JSON512b_Bench {}

#[make_bench(quote { JSON1kb })]
mod JSON1kb_Bench {}

#[make_bench(quote { JSON2kb })]
mod JSON2kb_Bench {}

#[make_bench(quote { JSON4kb })]
mod JSON4kb_Bench {}

#[make_bench(quote { JSON8kb })]
mod JSON8kb_Bench {}

#[make_bench(quote { JSON16kb })]
mod JSON16kb_Bench {}
