use std::ffi::{CStr, CString};
use tokscale_core::{TokenBreakdown, UnifiedMessage};

#[test]
fn decodes_camel_case_request_options() {
    let request = super::decode_request(
        r#"{
            "homeDirectory": "/tmp/mock-home",
            "clients": ["claude", "codex"],
            "since": "2026-07-01",
            "until": "2026-07-27",
            "year": "2026",
            "hourly": true,
            "startTimeMs": 1785283200000,
            "endTimeMs": 1785369600000,
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
    assert!(request.hourly);
    assert_eq!(request.start_time_ms, Some(1_785_283_200_000));
    assert_eq!(request.end_time_ms, Some(1_785_369_600_000));
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

#[test]
fn timestamp_filter_uses_a_half_open_hour_range() {
    let start = 1_785_283_200_000;
    let end = start + 24 * 60 * 60 * 1_000;
    let messages = vec![
        message_at(start, 10),
        message_at(end - 1, 20),
        message_at(end, 30),
    ];

    let filtered = super::filter_messages_by_time(messages, Some(start), Some(end));

    assert_eq!(filtered.len(), 2);
}

#[test]
fn hourly_contributions_fill_24_slots_and_keep_model_details() {
    let start = 1_785_283_200_000;
    let end = start + 24 * 60 * 60 * 1_000;
    let messages = vec![
        message_at(start, 10),
        message_at(start + 60 * 60 * 1_000, 20),
    ];

    let contributions = super::aggregate_hourly_contributions(messages, start, end);

    assert_eq!(contributions.len(), 24);
    assert_eq!(contributions[0].totals.tokens, 10);
    assert_eq!(contributions[1].totals.tokens, 20);
    assert_eq!(contributions[2].totals.tokens, 0);
    assert_eq!(contributions[0].clients.len(), 1);
    assert_eq!(contributions[0].clients[0].model_id, "gpt-5");
}

fn message_at(timestamp: i64, tokens: i64) -> UnifiedMessage {
    UnifiedMessage::new(
        "codex",
        "gpt-5",
        "openai",
        "synthetic-session",
        timestamp,
        TokenBreakdown {
            input: tokens,
            output: 0,
            cache_read: 0,
            cache_write: 0,
            reasoning: 0,
        },
        0.01,
    )
}
