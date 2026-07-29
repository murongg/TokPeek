use chrono::{Local, NaiveDate, TimeZone};
use serde::{Deserialize, Serialize};
use std::collections::BTreeMap;
use std::ffi::{c_char, CStr, CString};
use std::panic::{catch_unwind, AssertUnwindSafe};
use std::time::Instant;
use tokscale_core::{
    aggregate_by_date, compute_daily_active_time, compute_time_metrics, generate_graph_result,
    generate_local_graph_report, parse_local_unified_messages, sessionize, ClientContribution,
    DailyTotals, GraphResult, LocalParseOptions, ReportOptions, TokenBreakdown, UnifiedMessage,
    DEFAULT_IDLE_GAP_MS,
};

#[derive(Debug, Default, Deserialize)]
#[serde(rename_all = "camelCase")]
struct BridgeRequest {
    home_directory: Option<String>,
    clients: Option<Vec<String>>,
    since: Option<String>,
    until: Option<String>,
    year: Option<String>,
    #[serde(default)]
    hourly: bool,
    start_time_ms: Option<i64>,
    end_time_ms: Option<i64>,
    #[serde(default)]
    use_environment_roots: bool,
}

#[derive(Serialize)]
struct BridgeReport {
    #[serde(flatten)]
    graph: GraphResult,
    #[serde(skip_serializing_if = "Option::is_none")]
    hourly_contributions: Option<Vec<HourlyContribution>>,
}

#[derive(Debug, Serialize)]
struct HourlyContribution {
    hour: String,
    totals: DailyTotals,
    token_breakdown: TokenBreakdown,
    clients: Vec<ClientContribution>,
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

fn load_graph(request: BridgeRequest) -> Result<BridgeReport, String> {
    let runtime = tokio::runtime::Builder::new_current_thread()
        .enable_all()
        .build()
        .map_err(|error| format!("Could not start async runtime: {error}"))?;

    if request.hourly {
        runtime.block_on(load_hourly_graph(request))
    } else {
        runtime
            .block_on(generate_local_graph_report(ReportOptions {
                home_dir: request.home_directory,
                use_env_roots: request.use_environment_roots,
                clients: request.clients,
                since: request.since,
                until: request.until,
                year: request.year,
                ..ReportOptions::default()
            }))
            .map(|graph| BridgeReport {
                graph,
                hourly_contributions: None,
            })
    }
}

async fn load_hourly_graph(request: BridgeRequest) -> Result<BridgeReport, String> {
    let started_at = Instant::now();
    let start_time_ms = request
        .start_time_ms
        .ok_or_else(|| "Hourly reports require startTimeMs".to_string())?;
    let end_time_ms = request
        .end_time_ms
        .ok_or_else(|| "Hourly reports require endTimeMs".to_string())?;
    if end_time_ms <= start_time_ms {
        return Err("Hourly report endTimeMs must be after startTimeMs".to_string());
    }

    let messages = parse_local_unified_messages(LocalParseOptions {
        home_dir: request.home_directory,
        use_env_roots: request.use_environment_roots,
        clients: request.clients,
        since: request.since.clone(),
        until: request.until.clone(),
        year: request.year,
        ..LocalParseOptions::default()
    })
    .await?;
    let messages = filter_messages_by_time(messages, Some(start_time_ms), Some(end_time_ms));

    // Build both daily overview data and hourly chart data from the same core
    // parse. This avoids scanning every supported client twice per refresh.
    let intervals = sessionize(&messages, DEFAULT_IDLE_GAP_MS);
    let time_metrics = compute_time_metrics(&intervals, DEFAULT_IDLE_GAP_MS);
    let daily_active_time = compute_daily_active_time(&intervals);
    let contributions = aggregate_by_date(messages.clone());
    let mut graph = generate_graph_result(contributions, started_at.elapsed().as_millis() as u32);
    graph.time_metrics = Some(time_metrics);
    for contribution in &mut graph.contributions {
        if let Some(&milliseconds) = daily_active_time.get(&contribution.date) {
            contribution.active_time_ms = Some(milliseconds);
        }
    }

    if graph.meta.date_range_start.is_empty() {
        graph.meta.date_range_start = request.since.unwrap_or_default();
    }
    if graph.meta.date_range_end.is_empty() {
        graph.meta.date_range_end = request.until.unwrap_or_default();
    }

    let hourly_contributions = aggregate_hourly_contributions(messages, start_time_ms, end_time_ms);
    graph.meta.processing_time_ms = started_at.elapsed().as_millis() as u32;

    Ok(BridgeReport {
        graph,
        hourly_contributions: Some(hourly_contributions),
    })
}

fn filter_messages_by_time(
    messages: Vec<UnifiedMessage>,
    start_time_ms: Option<i64>,
    end_time_ms: Option<i64>,
) -> Vec<UnifiedMessage> {
    messages
        .into_iter()
        .filter(|message| {
            let Some(timestamp) = message_timestamp_ms(message) else {
                return false;
            };
            start_time_ms.is_none_or(|start| timestamp >= start)
                && end_time_ms.is_none_or(|end| timestamp < end)
        })
        .collect()
}

fn aggregate_hourly_contributions(
    messages: Vec<UnifiedMessage>,
    start_time_ms: i64,
    end_time_ms: i64,
) -> Vec<HourlyContribution> {
    let mut hourly_messages = messages;
    for message in &mut hourly_messages {
        message.date = hour_key(message);
    }

    let populated: BTreeMap<String, HourlyContribution> = aggregate_by_date(hourly_messages)
        .into_iter()
        .map(|contribution| {
            (
                contribution.date.clone(),
                HourlyContribution {
                    hour: contribution.date,
                    totals: contribution.totals,
                    token_breakdown: contribution.token_breakdown,
                    clients: contribution.clients,
                },
            )
        })
        .collect();

    let slot_count = ((end_time_ms - start_time_ms) / 3_600_000).max(0) as usize;
    (0..slot_count)
        .map(|offset| {
            let timestamp = start_time_ms + offset as i64 * 3_600_000;
            let key = hour_key_from_timestamp(timestamp);
            populated
                .get(&key)
                .map(|contribution| HourlyContribution {
                    hour: contribution.hour.clone(),
                    totals: contribution.totals.clone(),
                    token_breakdown: contribution.token_breakdown.clone(),
                    clients: contribution.clients.clone(),
                })
                .unwrap_or_else(|| empty_hourly_contribution(key))
        })
        .collect()
}

fn empty_hourly_contribution(hour: String) -> HourlyContribution {
    HourlyContribution {
        hour,
        totals: DailyTotals::default(),
        token_breakdown: TokenBreakdown::default(),
        clients: Vec::new(),
    }
}

fn hour_key(message: &UnifiedMessage) -> String {
    message_timestamp_ms(message)
        .map(hour_key_from_timestamp)
        .unwrap_or_else(|| format!("{} 00:00", message.date))
}

fn hour_key_from_timestamp(timestamp_ms: i64) -> String {
    match Local.timestamp_millis_opt(timestamp_ms) {
        chrono::LocalResult::Single(date) => date.format("%Y-%m-%d %H:00").to_string(),
        _ => String::new(),
    }
}

fn message_timestamp_ms(message: &UnifiedMessage) -> Option<i64> {
    if message.timestamp > 0 {
        return Some(if message.timestamp < 1_000_000_000_000 {
            message.timestamp.saturating_mul(1_000)
        } else {
            message.timestamp
        });
    }

    let date = NaiveDate::parse_from_str(&message.date, "%Y-%m-%d").ok()?;
    let midnight = date.and_hms_opt(0, 0, 0)?;
    Local
        .from_local_datetime(&midnight)
        .single()
        .map(|value| value.timestamp_millis())
}

fn envelope_json(result: Result<BridgeReport, String>) -> String {
    let envelope = match result {
        Ok(data) => BridgeEnvelope {
            ok: true,
            data: Some(data),
            error: None,
        },
        Err(error) => BridgeEnvelope::<BridgeReport> {
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
