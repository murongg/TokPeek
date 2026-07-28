use serde::{Deserialize, Serialize};
use std::ffi::{c_char, CStr, CString};
use std::panic::{catch_unwind, AssertUnwindSafe};
use tokscale_core::{generate_local_graph_report, GraphResult, ReportOptions};

#[derive(Debug, Default, Deserialize)]
#[serde(rename_all = "camelCase")]
struct BridgeRequest {
    home_directory: Option<String>,
    clients: Option<Vec<String>>,
    since: Option<String>,
    until: Option<String>,
    year: Option<String>,
    #[serde(default)]
    use_environment_roots: bool,
}

#[derive(Serialize)]
struct BridgeEnvelope<T: Serialize> {
    ok: bool,
    #[serde(skip_serializing_if = "Option::is_none")]
    data: Option<T>,
    #[serde(skip_serializing_if = "Option::is_none")]
    error: Option<String>,
}

fn decode_request(json: &str) -> Result<BridgeRequest, String> {
    if json.trim().is_empty() {
        return Ok(BridgeRequest::default());
    }

    serde_json::from_str(json).map_err(|error| format!("Invalid request JSON: {error}"))
}

fn load_graph(request: BridgeRequest) -> Result<GraphResult, String> {
    let runtime = tokio::runtime::Builder::new_current_thread()
        .enable_all()
        .build()
        .map_err(|error| format!("Could not start async runtime: {error}"))?;

    runtime.block_on(generate_local_graph_report(ReportOptions {
        home_dir: request.home_directory,
        use_env_roots: request.use_environment_roots,
        clients: request.clients,
        since: request.since,
        until: request.until,
        year: request.year,
        ..ReportOptions::default()
    }))
}

fn envelope_json(result: Result<GraphResult, String>) -> String {
    let envelope = match result {
        Ok(data) => BridgeEnvelope {
            ok: true,
            data: Some(data),
            error: None,
        },
        Err(error) => BridgeEnvelope::<GraphResult> {
            ok: false,
            data: None,
            error: Some(error),
        },
    };

    serde_json::to_string(&envelope).unwrap_or_else(|error| {
        format!(
            r#"{{"ok":false,"error":"Could not serialize bridge response: {}"}}"#,
            error
        )
    })
}

fn string_into_raw(value: String) -> *mut c_char {
    CString::new(value)
        .expect("JSON serialization escapes embedded null bytes")
        .into_raw()
}

/// Generates a Tokscale graph report and returns an owned JSON C string.
///
/// # Safety
///
/// `request_json` must be null or point to a valid, null-terminated C string
/// that remains alive for the duration of this call. The returned pointer must
/// be released exactly once with [`tokpeek_string_free`].
#[no_mangle]
pub unsafe extern "C" fn tokpeek_graph_report(request_json: *const c_char) -> *mut c_char {
    let result = catch_unwind(AssertUnwindSafe(|| {
        let request = if request_json.is_null() {
            Ok(BridgeRequest::default())
        } else {
            unsafe { CStr::from_ptr(request_json) }
                .to_str()
                .map_err(|error| format!("Invalid request UTF-8: {error}"))
                .and_then(decode_request)
        };

        request.and_then(load_graph)
    }))
    .unwrap_or_else(|_| Err("Tokscale Core panicked while generating the report".to_string()));

    string_into_raw(envelope_json(result))
}

/// Releases a string returned by [`tokpeek_graph_report`].
///
/// # Safety
///
/// `value` must be null or a pointer returned by [`tokpeek_graph_report`] that
/// has not already been released.
#[no_mangle]
pub unsafe extern "C" fn tokpeek_string_free(value: *mut c_char) {
    if !value.is_null() {
        drop(unsafe { CString::from_raw(value) });
    }
}

#[cfg(test)]
mod tests;
