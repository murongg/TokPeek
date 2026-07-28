use std::ffi::{CStr, CString};

#[test]
fn decodes_camel_case_request_options() {
    let request = super::decode_request(
        r#"{
            "homeDirectory": "/tmp/mock-home",
            "clients": ["claude", "codex"],
            "since": "2026-07-01",
            "until": "2026-07-27",
            "year": "2026",
            "useEnvironmentRoots": true
        }"#,
    )
    .expect("request should decode");

    assert_eq!(request.home_directory.as_deref(), Some("/tmp/mock-home"));
    assert_eq!(
        request.clients,
        Some(vec!["claude".to_string(), "codex".to_string()])
    );
    assert_eq!(request.since.as_deref(), Some("2026-07-01"));
    assert_eq!(request.until.as_deref(), Some("2026-07-27"));
    assert_eq!(request.year.as_deref(), Some("2026"));
    assert!(request.use_environment_roots);
}

#[test]
fn invalid_json_returns_an_error_envelope_without_calling_tokscale() {
    let input = CString::new("{not-json").expect("fixture has no null bytes");
    let output = unsafe { super::tokpeek_graph_report(input.as_ptr()) };

    assert!(!output.is_null());

    let json = unsafe { CStr::from_ptr(output) }
        .to_str()
        .expect("bridge output should be UTF-8")
        .to_string();
    unsafe { super::tokpeek_string_free(output) };

    let value: serde_json::Value =
        serde_json::from_str(&json).expect("bridge output should be JSON");
    assert_eq!(value["ok"], false);
    assert!(value["error"]
        .as_str()
        .expect("error should be a string")
        .contains("request"));
}
