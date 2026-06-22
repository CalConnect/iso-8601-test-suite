#!/usr/bin/env python3
"""ISO 8601 Test Suite — Python datetime adapter (JSON protocol)

Implements the newline-delimited JSON protocol for use with:
  ruby run-tests --adapter "exec:python3 adapters/python-datetime.py"

Uses Python's standard library date/datetime for parsing, with strptime
for format-specific parsing (basic format, ordinal, week dates) that
fromisoformat doesn't handle.

See adapters/TEMPLATE.rb for the full adapter interface specification.
"""

import sys
import json
import re
from datetime import date, datetime, timezone, timedelta

_cache = {}
_handle_counter = 0


def _store(obj):
    global _handle_counter
    _handle_counter += 1
    h = f"h{_handle_counter}"
    _cache[h] = obj
    return h


def _lookup(handle):
    return _cache.get(handle)


# ── strptime format registry ──────────────────────────────────────────────────
# Each entry: (regex_pattern, strptime_format)
# Z is normalized to +0000 before matching so %z handles it.

STRPTIME_FORMATS = [
    # Calendar date-time, basic format with fractional seconds
    (re.compile(r'^\d{4}\d{2}\d{2}T\d{2}\d{2}\d{2}[.,]\d+Z$'),          "%Y%m%dT%H%M%S.%f%z"),
    (re.compile(r'^\d{4}\d{2}\d{2}T\d{2}\d{2}\d{2}[.,]\d+[+-]\d{2}:?\d{2}$'), "%Y%m%dT%H%M%S.%f%z"),
    (re.compile(r'^\d{4}\d{2}\d{2}T\d{2}\d{2}\d{2}[.,]\d+$'),           "%Y%m%dT%H%M%S.%f"),

    # Calendar date-time, basic format
    (re.compile(r'^\d{4}\d{2}\d{2}T\d{2}\d{2}\d{2}Z$'),                 "%Y%m%dT%H%M%S%z"),
    (re.compile(r'^\d{4}\d{2}\d{2}T\d{2}\d{2}\d{2}[+-]\d{2}:?\d{2}$'), "%Y%m%dT%H%M%S%z"),
    (re.compile(r'^\d{4}\d{2}\d{2}T\d{2}\d{2}\d{2}$'),                  "%Y%m%dT%H%M%S"),

    # Calendar date-time, basic format reduced precision
    (re.compile(r'^\d{4}\d{2}\d{2}T\d{2}\d{2}Z$'),                      "%Y%m%dT%H%M%z"),
    (re.compile(r'^\d{4}\d{2}\d{2}T\d{2}\d{2}[+-]\d{2}:?\d{2}$'),      "%Y%m%dT%H%M%z"),
    (re.compile(r'^\d{4}\d{2}\d{2}T\d{2}\d{2}$'),                       "%Y%m%dT%H%M"),

    # Calendar date-time, extended format with fractional seconds
    (re.compile(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}[.,]\d+Z$'),     "%Y-%m-%dT%H:%M:%S.%f%z"),
    (re.compile(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}[.,]\d+[+-]\d{2}:?\d{2}$'), "%Y-%m-%dT%H:%M:%S.%f%z"),
    (re.compile(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}[.,]\d+$'),      "%Y-%m-%dT%H:%M:%S.%f"),

    # Calendar date-time, extended format
    (re.compile(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$'),            "%Y-%m-%dT%H:%M:%S%z"),
    (re.compile(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}[+-]\d{2}:?\d{2}$'), "%Y-%m-%dT%H:%M:%S%z"),
    (re.compile(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}$'),             "%Y-%m-%dT%H:%M:%S"),

    # Calendar date-time, extended format reduced precision
    (re.compile(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}Z$'),                   "%Y-%m-%dT%H:%M%z"),
    (re.compile(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}[+-]\d{2}:?\d{2}$'),   "%Y-%m-%dT%H:%M%z"),
    (re.compile(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}$'),                    "%Y-%m-%dT%H:%M"),

    # Ordinal date-time, basic format
    (re.compile(r'^\d{4}\d{3}T\d{2}\d{2}\d{2}Z$'),                      "%Y%jT%H%M%S%z"),
    (re.compile(r'^\d{4}\d{3}T\d{2}\d{2}\d{2}[+-]\d{2}:?\d{2}$'),      "%Y%jT%H%M%S%z"),
    (re.compile(r'^\d{4}\d{3}T\d{2}\d{2}\d{2}$'),                       "%Y%jT%H%M%S"),

    # Ordinal date-time, extended format
    (re.compile(r'^\d{4}-\d{3}T\d{2}:\d{2}:\d{2}Z$'),                   "%Y-%jT%H:%M:%S%z"),
    (re.compile(r'^\d{4}-\d{3}T\d{2}:\d{2}:\d{2}[+-]\d{2}:?\d{2}$'),   "%Y-%jT%H:%M:%S%z"),
    (re.compile(r'^\d{4}-\d{3}T\d{2}:\d{2}:\d{2}$'),                    "%Y-%jT%H:%M:%S"),

    # Ordinal date-time, reduced precision
    (re.compile(r'^\d{4}\d{3}T\d{2}\d{2}Z$'),                           "%Y%jT%H%M%z"),
    (re.compile(r'^\d{4}\d{3}T\d{2}\d{2}[+-]\d{2}:?\d{2}$'),           "%Y%jT%H%M%z"),
    (re.compile(r'^\d{4}\d{3}T\d{2}\d{2}$'),                            "%Y%jT%H%M"),
    (re.compile(r'^\d{4}-\d{3}T\d{2}:\d{2}Z$'),                         "%Y-%jT%H:%M%z"),
    (re.compile(r'^\d{4}-\d{3}T\d{2}:\d{2}[+-]\d{2}:?\d{2}$'),         "%Y-%jT%H:%M%z"),
    (re.compile(r'^\d{4}-\d{3}T\d{2}:\d{2}$'),                          "%Y-%jT%H:%M"),

    # Week date-time, basic format
    (re.compile(r'^\d{4}W\d{2}\d{T\d{2}\d{2}\d{2}Z$'),                  "%GW%V%uT%H%M%S%z"),
    (re.compile(r'^\d{4}W\d{2}\d{T\d{2}\d{2}\d{2}[+-]\d{2}:?\d{2}$'),  "%GW%V%uT%H%M%S%z"),
    (re.compile(r'^\d{4}W\d{2}\d{T\d{2}\d{2}\d{2}$'),                   "%GW%V%uT%H%M%S"),

    # Week date-time, extended format
    (re.compile(r'^\d{4}-W\d{2}-\d{T\d{2}:\d{2}:\d{2}Z$'),              "%G-W%V-%uT%H:%M:%S%z"),
    (re.compile(r'^\d{4}-W\d{2}-\d{T\d{2}:\d{2}:\d{2}[+-]\d{2}:?\d{2}$'), "%G-W%V-%uT%H:%M:%S%z"),
    (re.compile(r'^\d{4}-W\d{2}-\d{T\d{2}:\d{2}:\d{2}$'),               "%G-W%V-%uT%H:%M:%S"),

    # Week date-time, reduced precision
    (re.compile(r'^\d{4}W\d{2}\d{T\d{2}\d{2}Z$'),                       "%GW%V%uT%H%M%z"),
    (re.compile(r'^\d{4}W\d{2}\d{T\d{2}\d{2}[+-]\d{2}:?\d{2}$'),       "%GW%V%uT%H%M%z"),
    (re.compile(r'^\d{4}W\d{2}\d{T\d{2}\d{2}$'),                        "%GW%V%uT%H%M"),
    (re.compile(r'^\d{4}-W\d{2}-\d{T\d{2}:\d{2}Z$'),                    "%G-W%V-%uT%H:%M%z"),
    (re.compile(r'^\d{4}-W\d{2}-\d{T\d{2}:\d{2}[+-]\d{2}:?\d{2}$'),    "%G-W%V-%uT%H:%M%z"),
    (re.compile(r'^\d{4}-W\d{2}-\d{T\d{2}:\d{2}$'),                     "%G-W%V-%uT%H:%M"),

    # Date-only formats
    (re.compile(r'^\d{4}\d{2}\d{2}$'),                                   "%Y%m%d"),
    (re.compile(r'^\d{4}-\d{2}-\d{2}$'),                                 "%Y-%m-%d"),
    (re.compile(r'^\d{4}-\d{2}$'),                                        "%Y-%m"),
    (re.compile(r'^\d{4}$'),                                              "%Y"),
    (re.compile(r'^\d{4}\d{3}$'),                                        "%Y%j"),
    (re.compile(r'^\d{4}-\d{3}$'),                                       "%Y-%j"),
    (re.compile(r'^\d{4}W\d{2}\d$'),                                     "%GW%V%u"),
    (re.compile(r'^\d{4}-W\d{2}-\d$'),                                   "%G-W%V-%u"),
    # Note: Python strptime requires weekday with %G/%V, so week-only formats
    # (e.g. "1985W15") cannot be parsed with strptime.

    # Time-only, basic format with T prefix
    (re.compile(r'^T\d{2}\d{2}\d{2}[.,]\d+Z$'),                          "T%H%M%S.%f%z"),
    (re.compile(r'^T\d{2}\d{2}\d{2}[.,]\d+[+-]\d{2}:?\d{2}$'),           "T%H%M%S.%f%z"),
    (re.compile(r'^T\d{2}\d{2}\d{2}[.,]\d+$'),                            "T%H%M%S.%f"),
    (re.compile(r'^T\d{2}\d{2}\d{2}Z$'),                                 "T%H%M%S%z"),
    (re.compile(r'^T\d{2}\d{2}\d{2}[+-]\d{2}:?\d{2}$'),                 "T%H%M%S%z"),
    (re.compile(r'^T\d{2}\d{2}\d{2}$'),                                  "T%H%M%S"),
    (re.compile(r'^T\d{2}\d{2}[.,]\d+Z$'),                               "T%H%M.%f%z"),
    (re.compile(r'^T\d{2}\d{2}[.,]\d+$'),                                 "T%H%M.%f"),
    (re.compile(r'^T\d{2}\d{2}Z$'),                                      "T%H%M%z"),
    (re.compile(r'^T\d{2}\d{2}$'),                                       "T%H%M"),
    (re.compile(r'^T\d{2}$'),                                            "T%H"),

    # Time-only, extended format
    (re.compile(r'^\d{2}:\d{2}:\d{2}[.,]\d+Z$'),                        "%H:%M:%S.%f%z"),
    (re.compile(r'^\d{2}:\d{2}:\d{2}[.,]\d+[+-]\d{2}:?\d{2}$'),         "%H:%M:%S.%f%z"),
    (re.compile(r'^\d{2}:\d{2}:\d{2}[.,]\d+$'),                         "%H:%M:%S.%f"),
    (re.compile(r'^\d{2}:\d{2}:\d{2}Z$'),                                "%H:%M:%S%z"),
    (re.compile(r'^\d{2}:\d{2}:\d{2}[+-]\d{2}:?\d{2}$'),                "%H:%M:%S%z"),
    (re.compile(r'^\d{2}:\d{2}:\d{2}$'),                                 "%H:%M:%S"),
    (re.compile(r'^\d{2}:\d{2}Z$'),                                      "%H:%M%z"),
    (re.compile(r'^\d{2}:\d{2}[+-]\d{2}:?\d{2}$'),                      "%H:%M%z"),
    (re.compile(r'^\d{2}:\d{2}$'),                                       "%H:%M"),
]


def _try_strptime(expr):
    """Try format-specific parsing with strptime."""
    for pattern, fmt in STRPTIME_FORMATS:
        if pattern.match(expr):
            # Normalize: Z → +0000, comma → dot (for fractional seconds)
            normalized = expr[:-1] + "+0000" if expr.endswith("Z") else expr
            normalized = normalized.replace(",", ".")
            try:
                parsed = datetime.strptime(normalized, fmt.replace("Z", "+0000"))
                # Date-only formats produce datetime with time 00:00:00.
                # Convert to plain date so extract_components omits time.
                if "%H" not in fmt and "%M" not in fmt and "%S" not in fmt:
                    parsed = parsed.date()
                return {"valid": True, "parsed": _store(parsed), "api": "datetime.strptime"}
            except (ValueError, TypeError):
                continue
    return None


# ── Protocol methods ─────────────────────────────────────────────────────────

DECLARED_CONFORMANCE_CLASSES = [
    "conf-class:fundamentals",
    "conf-class:calendar-date",
    "conf-class:ordinal-date",
    "conf-class:week-date",
    "conf-class:time-of-day",
    "conf-class:date-and-time",
]


def info(params):
    vi = sys.version_info
    return {
        "name": f"Python {vi.major}.{vi.minor} datetime",
        "language": "python",
        "version": f"{vi.major}.{vi.minor}.{vi.micro}",
    }


def declared_conformance_classes(params):
    return DECLARED_CONFORMANCE_CLASSES


def try_parse(params):
    expr = params["expression"]
    options = params.get("options") or {}
    parse_mode = options.get("parse_mode", "dedicated")

    # 1. Format-specific parsing (strptime) — dedicated mode only
    if parse_mode == "dedicated":
        result = _try_strptime(expr)
        if result is not None:
            return result

    # 2. General parser (fromisoformat) — always tried in undifferentiated mode,
    #    or as fallback in dedicated mode
    normalized = expr
    if normalized.endswith("Z"):
        normalized = normalized[:-1] + "+00:00"

    for parser, api in [
        (datetime.fromisoformat, "datetime.fromisoformat"),
        (date.fromisoformat, "date.fromisoformat"),
    ]:
        try:
            parsed = parser(normalized)
            return {"valid": True, "parsed": _store(parsed), "api": api}
        except (ValueError, TypeError):
            continue

    return {"valid": False, "error": "parse error", "api": "datetime.fromisoformat"}


def extract_components(params):
    obj = _lookup(params.get("parsed"))
    if obj is None:
        return {}

    result = {}

    if isinstance(obj, (date, datetime)):
        result["calendar"] = {"year": obj.year, "month": obj.month, "day": obj.day}

        iso_year, iso_week, iso_weekday = obj.isocalendar()
        result["week"] = {
            "week_year": iso_year,
            "week": iso_week,
            "day_of_week": iso_weekday,
        }

        result["ordinal"] = {"year": obj.year, "day_of_year": obj.timetuple().tm_yday}

    if isinstance(obj, datetime):
        result["time"] = {"hour": obj.hour, "minute": obj.minute, "second": obj.second}

        off = obj.utcoffset()
        if off is not None:
            total_sec = int(off.total_seconds())
            result["time"]["utc_offset"] = {
                "sign": "+" if total_sec >= 0 else "-",
                "hours": abs(total_sec) // 3600,
                "minutes": (abs(total_sec) % 3600) // 60,
            }

    return result


def generate(params):
    components = params.get("components", {})
    fmt = components.get("format")
    cal = components.get("calendar")
    ordinal = components.get("ordinal")
    week = components.get("week")
    time_comp = components.get("time")

    if cal and isinstance(cal, dict):
        return _generate_calendar(cal, time_comp, fmt)
    elif ordinal and isinstance(ordinal, dict):
        return _generate_ordinal(ordinal, time_comp, fmt)
    elif week and isinstance(week, dict):
        return _generate_week(week, time_comp, fmt)
    elif time_comp and isinstance(time_comp, dict):
        return _generate_time_only(time_comp, fmt)
    return None


def _generate_calendar(cal, time_comp, fmt):
    year = cal.get("year")
    month = cal.get("month")
    day = cal.get("day")

    if not (year and month and day):
        return None

    if time_comp:
        return _generate_datetime(year, month, day, time_comp, fmt)

    d = date(year, month, day)
    if fmt == "basic":
        return {"expression": d.strftime("%Y%m%d")}
    return {"expression": d.isoformat()}


def _generate_ordinal(ordinal, time_comp, fmt):
    year = ordinal.get("year")
    yday = ordinal.get("day_of_year")
    if not (year and yday):
        return None

    d = date(year, 1, 1) + timedelta(days=yday - 1)
    if time_comp:
        return _generate_datetime(year, d.month, d.day, time_comp, fmt)

    if fmt == "basic":
        return {"expression": d.strftime("%Y%j")}
    return {"expression": d.strftime("%Y-%j")}


def _generate_week(week, time_comp, fmt):
    week_year = week.get("week_year")
    week_num = week.get("week")
    dow = week.get("day_of_week")
    if not (week_year and week_num):
        return None

    # Convert week date to calendar date using isocalendar inverse
    jan4 = date(week_year, 1, 4)
    week1_monday = jan4 - timedelta(days=jan4.isoweekday() - 1)
    d = week1_monday + timedelta(weeks=week_num - 1, days=(dow or 1) - 1)

    if time_comp:
        return _generate_datetime(d.year, d.month, d.day, time_comp, fmt)

    if fmt == "basic":
        return {"expression": d.strftime("%GW%V%u")}
    return {"expression": d.strftime("%G-W%V-%u")}


def _generate_datetime(year, month, day, time_comp, fmt):
    hour = time_comp.get("hour", 0)
    minute = time_comp.get("minute", 0)
    second = time_comp.get("second", 0)
    offset = time_comp.get("utc_offset")

    if offset:
        sign = offset.get("sign", "+")
        off_h = offset.get("hours", 0)
        off_m = offset.get("minutes", 0)
        td = timedelta(hours=off_h, minutes=off_m)
        if sign == "-":
            td = -td
        tz = timezone(td)
    else:
        tz = None

    if tz:
        dt = datetime(year, month, day, hour, minute, second, tzinfo=tz)
    else:
        dt = datetime(year, month, day, hour, minute, second)

    expr = dt.isoformat()
    # Replace +00:00 with Z for UTC
    if offset and offset.get("hours") == 0 and offset.get("minutes") == 0:
        expr = expr.replace("+00:00", "Z")

    if fmt == "basic":
        expr = dt.strftime("%Y%m%dT%H%M%S")
        if offset and offset.get("hours") == 0 and offset.get("minutes") == 0:
            expr += "Z"
        elif offset:
            sign = offset.get("sign", "+")
            expr += f"{sign}{offset['hours']:02d}{offset.get('minutes', 0):02d}"

    return {"expression": expr}


def _generate_time_only(time_comp, fmt):
    hour = time_comp.get("hour")
    minute = time_comp.get("minute")
    second = time_comp.get("second")
    if hour is None:
        return None

    if fmt == "basic":
        expr = f"{hour:02d}"
        if minute is not None:
            expr += f"{minute:02d}"
        if second is not None:
            expr += f"{second:02d}"
    else:
        if second is not None:
            expr = f"{hour:02d}:{minute or 0:02d}:{second:02d}"
        elif minute is not None:
            expr = f"{hour:02d}:{minute:02d}"
        else:
            expr = f"{hour:02d}"

    offset = time_comp.get("utc_offset")
    if offset:
        if offset.get("hours") == 0 and offset.get("minutes") == 0:
            expr += "Z"
        else:
            sign = offset.get("sign", "+")
            if fmt == "basic":
                expr += f"{sign}{offset['hours']:02d}{offset.get('minutes', 0):02d}"
            else:
                expr += f"{sign}{offset['hours']:02d}:{offset.get('minutes', 0):02d}"

    return {"expression": expr}


def equivalent(params):
    a = _lookup(params.get("parsed_a"))
    b = _lookup(params.get("parsed_b"))
    if a is None or b is None:
        return None

    if isinstance(a, (date, datetime)) and isinstance(b, (date, datetime)):
        return a == b

    return None


def run_arithmetic(params):
    return {
        "result": "not-supported",
        "notes": "Python datetime does not support ISO 8601 arithmetic",
    }


# ── Dispatch ─────────────────────────────────────────────────────────────────

METHODS = {
    "info": info,
    "declared_conformance_classes": declared_conformance_classes,
    "try_parse": try_parse,
    "extract_components": extract_components,
    "generate": generate,
    "equivalent": equivalent,
    "run_arithmetic": run_arithmetic,
}


def main():
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        try:
            request = json.loads(line)
            method = request.get("method", "")
            params = request.get("params", {})
            handler = METHODS.get(method)
            if handler is None:
                response = {"error": f"Unknown method: {method}"}
            else:
                response = {"result": handler(params)}
        except Exception as e:
            response = {"error": str(e)}
        sys.stdout.write(json.dumps(response) + "\n")
        sys.stdout.flush()


if __name__ == "__main__":
    main()
