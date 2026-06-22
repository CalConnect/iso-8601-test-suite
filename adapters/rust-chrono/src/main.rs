// ISO 8601 Test Suite — Rust chrono adapter (JSON protocol)
//
// Implements the newline-delimited JSON protocol for use with:
//   ruby run-tests --adapter "exec:cargo run --release --quiet --manifest-path adapters/rust-chrono/Cargo.toml --"
//
// Uses the chrono crate for date/time operations. chrono is the de facto
// standard datetime library in the Rust ecosystem (not stdlib, but universal).

use std::io::{self, BufRead, Write};
use std::collections::HashMap;
use std::sync::atomic::{AtomicUsize, Ordering};

use chrono::{NaiveDate, NaiveDateTime, NaiveTime, DateTime, FixedOffset, Datelike, Timelike, TimeZone};
use serde_json::{Value, json};

// ── Handle cache ─────────────────────────────────────────────────────────────

static HANDLE_COUNTER: AtomicUsize = AtomicUsize::new(0);
thread_local! {
    static CACHE: RefCell<HashMap<usize, StoredValue>> = RefCell::new(HashMap::new());
}

use std::cell::RefCell;

#[derive(Clone, Debug)]
enum StoredValue {
    Date(NaiveDate),
    DateTime(NaiveDateTime),
    OffsetDateTime(DateTime<FixedOffset>),
}

fn store(v: StoredValue) -> usize {
    let h = HANDLE_COUNTER.fetch_add(1, Ordering::SeqCst) + 1;
    CACHE.with(|c| c.borrow_mut().insert(h, v));
    h
}

fn lookup(h: &str) -> Option<StoredValue> {
    let id: usize = h.trim_start_matches('h').parse().ok()?;
    CACHE.with(|c| c.borrow().get(&id).cloned())
}

// ── Protocol methods ─────────────────────────────────────────────────────────

fn info() -> Value {
    let label = std::env::var("ADAPTER_LABEL").unwrap_or_else(|_| "Rust chrono".to_string());
    let version = std::env::var("ADAPTER_VERSION").unwrap_or_else(|_| "chrono 0.4".to_string());
    json!({
        "name": label,
        "language": "rust",
        "version": version
    })
}

// Format registry: (regex pattern, parse function name)
// We use chrono's built-in parsers plus strptime-style format strings.

struct ParseResult {
    valid: bool,
    parsed: Option<usize>,
    error: Option<String>,
    api: String,
}

fn try_parse(expr: &str) -> ParseResult {
    // 1. Try DateTime::parse_from_rfc3339 (handles extended date-time with offset/Z)
    if let Ok(dt) = DateTime::parse_from_rfc3339(expr) {
        let h = store(StoredValue::OffsetDateTime(dt));
        return ParseResult { valid: true, parsed: Some(h), error: None, api: "DateTime::parse_from_rfc3339".into() };
    }

    // 2. Strip trailing timezone offset for basic-format datetime parsing
    //    (chrono's parse_from_str with %z requires offset, but we want to handle
    //    basic format datetime with/without offset uniformly)
    let (core, tz_info) = strip_tz(expr);

    // 3. Try NaiveDateTime::parse_from_str with all datetime formats
    let datetime_formats = [
        ("%Y-%m-%dT%H:%M:%S", "NaiveDateTime::parse_from_str"),
        ("%Y-%m-%dT%H:%M", "NaiveDateTime::parse_from_str"),
        ("%Y%m%dT%H%M%S", "NaiveDateTime::parse_from_str"),
        ("%Y%m%dT%H%M", "NaiveDateTime::parse_from_str"),
        ("%Y-%jT%H:%M:%S", "NaiveDateTime::parse_from_str"),
        ("%Y-%jT%H:%M", "NaiveDateTime::parse_from_str"),
        ("%Y%jT%H%M%S", "NaiveDateTime::parse_from_str"),
        ("%Y%jT%H%M", "NaiveDateTime::parse_from_str"),
    ];
    for (fmt, api) in &datetime_formats {
        if let Ok(dt) = NaiveDateTime::parse_from_str(core, fmt) {
            if let Some(ref tz) = tz_info {
                let off_secs = tz_offset_secs(tz);
                if let Some(tz_obj) = FixedOffset::east_opt(off_secs) {
                    let odt = tz_obj.from_local_datetime(&dt).single();
                    if let Some(odt) = odt {
                        let h = store(StoredValue::OffsetDateTime(odt));
                        return ParseResult { valid: true, parsed: Some(h), error: None, api: api.to_string() };
                    }
                }
            }
            let h = store(StoredValue::DateTime(dt));
            return ParseResult { valid: true, parsed: Some(h), error: None, api: api.to_string() };
        }
    }

    // 4. Try NaiveDate::parse_from_str
    let date_formats = [
        ("%Y-%m-%d", "NaiveDate::parse_from_str"),
        ("%Y%m%d", "NaiveDate::parse_from_str"),
        ("%Y-%j", "NaiveDate::parse_from_str"),
        ("%Y%j", "NaiveDate::parse_from_str"),
        ("%G-W%V-%u", "NaiveDate::parse_from_str"),
        ("%GW%V%u", "NaiveDate::parse_from_str"),
        ("%Y-%m", "NaiveDate::parse_from_str"),
        ("%Y", "NaiveDate::parse_from_str"),
    ];
    for (fmt, api) in &date_formats {
        if let Ok(d) = NaiveDate::parse_from_str(core, fmt) {
            let h = store(StoredValue::Date(d));
            return ParseResult { valid: true, parsed: Some(h), error: None, api: api.to_string() };
        }
    }

    // 5. Try NaiveTime::parse_from_str (extended and basic with T prefix)
    let time_str = core.strip_prefix('T').unwrap_or(core);
    let time_formats = [
        ("%H:%M:%S", "NaiveTime::parse_from_str"),
        ("%H:%M", "NaiveTime::parse_from_str"),
        ("%H%M%S", "NaiveTime::parse_from_str"),
        ("%H%M", "NaiveTime::parse_from_str"),
        ("%H", "NaiveTime::parse_from_str"),
    ];
    for (fmt, api) in &time_formats {
        if let Ok(t) = NaiveTime::parse_from_str(time_str, fmt) {
            let dt = NaiveDate::from_ymd_opt(1970, 1, 1).unwrap().and_time(t);
            let h = store(StoredValue::DateTime(dt));
            return ParseResult { valid: true, parsed: Some(h), error: None, api: api.to_string() };
        }
    }

    ParseResult { valid: false, parsed: None, error: Some("parse error".into()), api: "chrono".into() }
}

/// Strip trailing timezone suffix (Z, ±HH:MM, ±HHMM) from expr.
/// Returns (core_expr, Some(tz_string) | None).
fn strip_tz(expr: &str) -> (&str, Option<String>) {
    if expr.ends_with('Z') {
        return (&expr[..expr.len()-1], Some("Z".into()));
    }
    let bytes = expr.as_bytes();
    let n = bytes.len();
    // ±HH:MM (6 chars from end): sign, 2 digits, colon, 2 digits
    if n >= 6
        && (bytes[n-6] == b'+' || bytes[n-6] == b'-')
        && bytes[n-5].is_ascii_digit()
        && bytes[n-4].is_ascii_digit()
        && bytes[n-3] == b':'
        && bytes[n-2].is_ascii_digit()
        && bytes[n-1].is_ascii_digit() {
        return (&expr[..n-6], Some(expr[n-6..].into()));
    }
    // ±HHMM (5 chars from end): sign + 4 digits
    if n >= 5
        && (bytes[n-5] == b'+' || bytes[n-5] == b'-')
        && bytes[n-4].is_ascii_digit()
        && bytes[n-3].is_ascii_digit()
        && bytes[n-2].is_ascii_digit()
        && bytes[n-1].is_ascii_digit() {
        return (&expr[..n-5], Some(expr[n-5..].into()));
    }
    // ±HH (3 chars from end): sign + 2 digits (reduced-precision offset)
    if n >= 3
        && (bytes[n-3] == b'+' || bytes[n-3] == b'-')
        && bytes[n-2].is_ascii_digit()
        && bytes[n-1].is_ascii_digit() {
        return (&expr[..n-3], Some(expr[n-3..].into()));
    }
    (expr, None)
}

fn tz_offset_secs(tz: &str) -> i32 {
    if tz == "Z" { return 0; }
    let sign: i32 = if tz.starts_with('-') { -1 } else { 1 };
    let nums: String = tz[1..].chars().filter(|c| c.is_ascii_digit()).collect();
    if nums.len() == 4 {
        let h: i32 = nums[..2].parse().unwrap_or(0);
        let m: i32 = nums[2..].parse().unwrap_or(0);
        sign * (h * 3600 + m * 60)
    } else if nums.len() == 2 {
        let h: i32 = nums[..2].parse().unwrap_or(0);
        sign * (h * 3600)
    } else {
        0
    }
}

fn week_json(d: &NaiveDate) -> Value {
    let iso = d.iso_week();
    let dow = d.weekday().num_days_from_monday() + 1;
    json!({
        "week_year": iso.year(),
        "week": iso.week(),
        "day_of_week": dow,
    })
}

fn extract_components(parsed: &str) -> Value {
    let entry = match lookup(parsed) {
        Some(e) => e,
        None => return json!({}),
    };

    match entry {
        StoredValue::Date(d) => {
            json!({
                "calendar": {
                    "year": d.year(),
                    "month": d.month(),
                    "day": d.day(),
                },
                "week": week_json(&d),
                "ordinal": {
                    "year": d.year(),
                    "day_of_year": d.ordinal(),
                }
            })
        }
        StoredValue::DateTime(dt) => {
            let d = NaiveDate::from_ymd_opt(dt.year(), dt.month(), dt.day()).unwrap();
            json!({
                "calendar": {
                    "year": dt.year(),
                    "month": dt.month(),
                    "day": dt.day(),
                },
                "week": week_json(&d),
                "ordinal": {
                    "year": dt.year(),
                    "day_of_year": dt.ordinal(),
                },
                "time": {
                    "hour": dt.hour(),
                    "minute": dt.minute(),
                    "second": dt.second(),
                }
            })
        }
        StoredValue::OffsetDateTime(dt) => {
            let off = dt.offset().local_minus_utc();
            let off_h = off / 3600;
            let off_m = (off % 3600) / 60;
            let sign = if off >= 0 { "+" } else { "-" };
            let d = NaiveDate::from_ymd_opt(dt.year(), dt.month(), dt.day()).unwrap();
            json!({
                "calendar": {
                    "year": dt.year(),
                    "month": dt.month(),
                    "day": dt.day(),
                },
                "week": week_json(&d),
                "ordinal": {
                    "year": dt.year(),
                    "day_of_year": dt.ordinal(),
                },
                "time": {
                    "hour": dt.hour(),
                    "minute": dt.minute(),
                    "second": dt.second(),
                    "utc_offset": {
                        "sign": sign,
                        "hours": off_h.unsigned_abs() as i64,
                        "minutes": off_m.unsigned_abs() as i64,
                    }
                }
            })
        }
    }
}

fn generate(components: &Value) -> Option<Value> {
    let cal = components.get("calendar")?;
    let year = cal.get("year")?.as_i64()?;
    let month = cal.get("month")?.as_i64()?;
    let day = cal.get("day")?.as_i64()?;

    let time_comp = components.get("time");
    let is_basic = components.get("format").and_then(|v| v.as_str()) == Some("basic");

    let date = NaiveDate::from_ymd_opt(year as i32, month as u32, day as u32)?;

    if let Some(tc) = time_comp {
        let hour = tc.get("hour").and_then(|v| v.as_i64()).unwrap_or(0) as u32;
        let minute = tc.get("minute").and_then(|v| v.as_i64()).unwrap_or(0) as u32;
        let second = tc.get("second").and_then(|v| v.as_i64()).unwrap_or(0) as u32;

        let offset = tc.get("utc_offset");
        let expr = if let Some(off) = offset {
            let sign = off.get("sign").and_then(|v| v.as_str()).unwrap_or("+");
            let off_h = off.get("hours").and_then(|v| v.as_i64()).unwrap_or(0) as i32;
            let off_m = off.get("minutes").and_then(|v| v.as_i64()).unwrap_or(0) as i32;
            let total_secs = sign_meter(sign, off_h, off_m);
            let tz = FixedOffset::east_opt(total_secs)?;
            let dt = tz.from_local_datetime(&date.and_hms_opt(hour, minute, second)?).single()?;
            if off_h == 0 && off_m == 0 && sign == "+" {
                dt.format("%Y-%m-%dT%H:%M:%SZ").to_string()
            } else if is_basic {
                format!("{}", dt.format("%Y%m%dT%H%M%S"))
                    + &format_offset(sign, off_h, off_m, true)
            } else {
                format!("{}", dt.format("%Y-%m-%dT%H:%M:%S"))
                    + &format_offset(sign, off_h, off_m, false)
            }
        } else {
            let dt = date.and_hms_opt(hour, minute, second)?;
            if is_basic {
                dt.format("%Y%m%dT%H%M%S").to_string()
            } else {
                dt.format("%Y-%m-%dT%H:%M:%S").to_string()
            }
        };
        Some(json!({ "expression": expr }))
    } else {
        let expr = if is_basic {
            date.format("%Y%m%d").to_string()
        } else {
            date.format("%Y-%m-%d").to_string()
        };
        Some(json!({ "expression": expr }))
    }
}

fn sign_meter(sign: &str, h: i32, m: i32) -> i32 {
    let total = h * 3600 + m * 60;
    if sign == "-" { -total } else { total }
}

fn format_offset(sign: &str, h: i32, m: i32, basic: bool) -> String {
    if h == 0 && m == 0 && sign == "+" {
        return "Z".to_string();
    }
    if basic {
        format!("{}{:02}{:02}", sign, h.abs(), m.abs())
    } else {
        format!("{}{:02}:{:02}", sign, h.abs(), m.abs())
    }
}

fn equivalent(parsed_a: &str, parsed_b: &str) -> Option<bool> {
    let a = lookup(parsed_a)?;
    let b = lookup(parsed_b)?;
    Some(match (&a, &b) {
        (StoredValue::Date(x), StoredValue::Date(y)) => x == y,
        (StoredValue::DateTime(x), StoredValue::DateTime(y)) => x == y,
        (StoredValue::OffsetDateTime(x), StoredValue::OffsetDateTime(y)) => x == y,
        _ => return None,
    })
}

// ── Main dispatch ────────────────────────────────────────────────────────────

fn handle_request(request: &Value) -> Value {
    let method = request.get("method").and_then(|v| v.as_str()).unwrap_or("");
    let params = request.get("params").cloned().unwrap_or(json!({}));

    match method {
        "info" => info(),
        "try_parse" => {
            let expr = params.get("expression").and_then(|v| v.as_str()).unwrap_or("");
            let result = try_parse(expr);
            if result.valid {
                json!({
                    "valid": true,
                    "parsed": format!("h{}", result.parsed.unwrap()),
                    "api": result.api
                })
            } else {
                json!({
                    "valid": false,
                    "error": result.error.unwrap_or_else(|| "parse error".into()),
                    "api": result.api
                })
            }
        }
        "extract_components" => {
            let parsed = params.get("parsed").and_then(|v| v.as_str()).unwrap_or("");
            extract_components(parsed)
        }
        "generate" => {
            let empty = json!({});
            let components = params.get("components").unwrap_or(&empty);
            generate(components).unwrap_or(Value::Null)
        }
        "equivalent" => {
            let a = params.get("parsed_a").and_then(|v| v.as_str()).unwrap_or("");
            let b = params.get("parsed_b").and_then(|v| v.as_str()).unwrap_or("");
            match equivalent(a, b) {
                Some(b) => json!(b),
                None => Value::Null,
            }
        }
        "run_arithmetic" => json!({
            "result": "not-supported",
            "notes": "chrono does not support ISO 8601 arithmetic"
        }),
        "declared_conformance_classes" => json!([
            "conf-class:fundamentals",
            "conf-class:calendar-date",
            "conf-class:ordinal-date",
            "conf-class:week-date",
            "conf-class:time-of-day",
            "conf-class:date-and-time"
        ]),
        _ => json!({ "error": format!("Unknown method: {}", method) }),
    }
}

fn main() {
    let stdin = io::stdin();
    let stdout = io::stdout();
    let mut out = stdout.lock();

    for line in stdin.lock().lines() {
        let line = match line {
            Ok(l) => l,
            Err(_) => break,
        };
        let trimmed = line.trim();
        if trimmed.is_empty() { continue; }

        let response = match serde_json::from_str::<Value>(trimmed) {
            Ok(request) => json!({ "result": handle_request(&request) }),
            Err(e) => json!({ "error": e.to_string() }),
        };

        writeln!(out, "{}", response).ok();
        out.flush().ok();
    }
}
