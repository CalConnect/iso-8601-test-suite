#!/usr/bin/env python3
"""ISO 8601 Test Suite — Python datetime adapter (JSON protocol)

Implements the newline-delimited JSON protocol for use with:
  ruby run-tests --adapter "exec:python3 adapters/python-datetime.py"

Uses Python's standard library date/datetime for parsing. Limited ISO 8601
coverage — serves as a working example of the adapter protocol.

See adapters/TEMPLATE.rb for the full adapter interface specification.
"""

import sys
import json
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


# ── Protocol methods ─────────────────────────────────────────────────────────

def info(params):
    vi = sys.version_info
    return {
        "name": "Python datetime",
        "language": "python",
        "version": f"{vi.major}.{vi.minor}.{vi.micro}",
    }


def try_parse(params):
    expr = params["expression"]

    # Try datetime first (handles date+time, date-only, and time-only in 3.11+)
    for parser, api in [
        (datetime.fromisoformat, "datetime.fromisoformat"),
        (date.fromisoformat, "date.fromisoformat"),
    ]:
        try:
            parsed = parser(expr)
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

    if isinstance(obj, datetime):
        result["time"] = {"hour": obj.hour, "minute": obj.minute, "second": obj.second}

        # Handle ordinals (datetime always has date, so yday is available)
        result["ordinal"] = {"year": obj.year, "day_of_year": obj.timetuple().tm_yday}

        off = obj.utcoffset()
        if off is not None and off.total_seconds() != 0:
            total_sec = int(off.total_seconds())
            result["time"]["utc_offset"] = {
                "sign": "+" if total_sec >= 0 else "-",
                "hours": abs(total_sec) // 3600,
                "minutes": (abs(total_sec) % 3600) // 60,
            }

    if isinstance(obj, date) and not isinstance(obj, datetime):
        result["ordinal"] = {"year": obj.year, "day_of_year": obj.timetuple().tm_yday}

    return result


def generate(params):
    components = params.get("components", {})
    cal = components.get("calendar")
    if cal and cal.get("year") and cal.get("month") and cal.get("day"):
        d = date(cal["year"], cal["month"], cal["day"])
        return {"expression": d.isoformat()}
    return None


def equivalent(params):
    a = _lookup(params.get("parsed_a"))
    b = _lookup(params.get("parsed_b"))
    if a is None or b is None:
        return None
    return a == b


def run_arithmetic(params):
    return {
        "result": "not-supported",
        "notes": "Python datetime does not support ISO 8601 arithmetic",
    }


# ── Dispatch ─────────────────────────────────────────────────────────────────

METHODS = {
    "info": info,
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
