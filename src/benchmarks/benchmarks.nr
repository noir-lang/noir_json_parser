
use crate::{json::JSON, JSON512b};

#[export]
fn test_capture_missing_tokens(j: &mut JSON512b){
    JSON::capture_missing_tokens(j)
}
