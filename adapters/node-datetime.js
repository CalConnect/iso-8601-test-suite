#!/usr/bin/env node
// ISO 8601 Test Suite — Node.js Date adapter (JSON protocol)
//
// Implements the newline-delimited JSON protocol for use with:
//   ruby run-tests --adapter "exec:node adapters/node-datetime.js"
//
// Tests JavaScript's built-in Date/Date.parse behavior — this is effectively
// what browsers provide. Very limited ISO 8601 support:
//   - Only extended format calendar dates with time
//   - No basic format, ordinal dates, week dates, durations, intervals
//   - Date.parse() handles a subset of ISO 8601 extended format
//   - toISOString() outputs UTC extended format only
//
// See adapters/TEMPLATE.rb for the full adapter interface specification.

const readline = require("readline");

const cache = new Map();
let handleCounter = 0;

function store(obj) {
  handleCounter++;
  const h = `h${handleCounter}`;
  cache.set(h, obj);
  return h;
}

function lookup(handle) {
  return cache.get(handle);
}

// ── Protocol methods ─────────────────────────────────────────────────────────

function info() {
  return {
    name: "JavaScript Date",
    language: "javascript",
    version: process.version,
  };
}

function tryParse(params) {
  const expr = params.expression;
  // options.parse_mode is accepted but JS Date.parse is inherently
  // undifferentiated (no format-specific parser in stdlib)

  // JS Date.parse only handles a narrow subset of ISO 8601.
  // We test what it ACTUALLY supports — no manual parsing hacks.

  // Try Date.parse (returns ms timestamp or NaN)
  const ms = Date.parse(expr);
  if (!Number.isNaN(ms)) {
    const d = new Date(ms);
    return { valid: true, parsed: store(d), api: "Date.parse" };
  }

  // Try new Date(string)
  try {
    const d = new Date(expr);
    if (!Number.isNaN(d.getTime())) {
      return { valid: true, parsed: store(d), api: "new Date(string)" };
    }
  } catch {}

  return { valid: false, error: "parse error", api: "Date.parse" };
}

function extractComponents(params) {
  const obj = lookup(params.parsed);
  if (!obj || !(obj instanceof Date) || Number.isNaN(obj.getTime())) {
    return {};
  }

  const result = {};

  // Date objects always represent a moment in time (UTC-based internally)
  // Local timezone methods give us calendar/date/time components
  result.calendar = {
    year: obj.getFullYear(),
    month: obj.getMonth() + 1, // JS months are 0-indexed
    day: obj.getDate(),
  };

  // Day of year (ordinal)
  const startOfYear = new Date(obj.getFullYear(), 0, 0);
  const diff = obj - startOfYear;
  const oneDay = 1000 * 60 * 60 * 24;
  const dayOfYear = Math.floor(diff / oneDay);
  result.ordinal = { year: obj.getFullYear(), day_of_year: dayOfYear };

  // Week date — JS doesn't natively provide ISO week number,
  // but we can compute it
  const d = new Date(Date.UTC(obj.getFullYear(), obj.getMonth(), obj.getDate()));
  const dayNum = d.getUTCDay() || 7;
  d.setUTCDate(d.getUTCDate() + 4 - dayNum);
  const yearStart = new Date(Date.UTC(d.getUTCFullYear(), 0, 1));
  const weekNum = Math.ceil(((d - yearStart) / 86400000 + 1) / 7);
  result.week = {
    week_year: d.getUTCFullYear(),
    week: weekNum,
    day_of_week: dayNum,
  };

  // Time components
  const time = {
    hour: obj.getHours(),
    minute: obj.getMinutes(),
    second: obj.getSeconds(),
  };

  // UTC offset — getTimezoneOffset returns minutes WEST of UTC (negative for east)
  const offsetMin = obj.getTimezoneOffset();
  if (offsetMin !== 0) {
    const absOffset = Math.abs(offsetMin);
    time.utc_offset = {
      sign: offsetMin > 0 ? "-" : "+",
      hours: Math.floor(absOffset / 60),
      minutes: absOffset % 60,
    };
  }

  result.time = time;

  return result;
}

function generate(params) {
  const components = params.components || {};
  const cal = components.calendar;
  const timeComp = components.time;
  const fmt = components.format;

  // JS Date only supports full calendar date generation
  if (!cal) return null;
  const year = cal.year;
  const month = cal.month;
  const day = cal.day;
  if (!year || !month || !day) return null;

  // Cannot generate basic format, ordinal, or week dates
  if (fmt === "basic") return null;

  if (timeComp) {
    return generateDatetime(year, month, day, timeComp, fmt);
  }

  // Date-only: JS can't produce an ISO date-only string without time,
  // but toISOString on a UTC midnight date gives us the date part
  try {
    const d = new Date(Date.UTC(year, month - 1, day));
    if (d.getUTCFullYear() !== year || d.getUTCMonth() !== month - 1 || d.getUTCDate() !== day) {
      return null;
    }
    return { expression: d.toISOString().split("T")[0] };
  } catch {
    return null;
  }
}

function generateDatetime(year, month, day, timeComp, fmt) {
  const hour = timeComp.hour || 0;
  const minute = timeComp.minute || 0;
  const second = timeComp.second || 0;
  const offset = timeComp.utc_offset;

  try {
    if (offset) {
      // Build a date with explicit offset
      const offH = offset.hours || 0;
      const offM = offset.minutes || 0;
      const sign = offset.sign || "+";

      // Create in UTC then adjust
      const d = new Date(Date.UTC(year, month - 1, day, hour, minute, second));
      // Adjust for timezone offset
      const offsetMs = (sign === "-" ? -1 : 1) * (offH * 60 + offM) * 60000;
      d.setTime(d.getTime() - offsetMs);

      if (offH === 0 && offM === 0 && sign === "+") {
        // UTC — toISOString gives us what we want
        const iso = d.toISOString();
        return { expression: iso.replace(".000Z", "Z") };
      } else {
        // Non-UTC offset — JS can't produce offset notation natively
        // Build it manually from the date parts
        const dateStr = `${String(year).padStart(4, "0")}-${String(month).padStart(2, "0")}-${String(day).padStart(2, "0")}`;
        const timeStr = `${String(hour).padStart(2, "0")}:${String(minute).padStart(2, "0")}:${String(second).padStart(2, "0")}`;
        const offStr = `${sign}${String(offH).padStart(2, "0")}:${String(offM).padStart(2, "0")}`;
        return { expression: `${dateStr}T${timeStr}${offStr}` };
      }
    } else {
      // No offset — local time
      const d = new Date(year, month - 1, day, hour, minute, second);
      // toISOString converts to UTC, so build manually
      const dateStr = `${String(year).padStart(4, "0")}-${String(month).padStart(2, "0")}-${String(day).padStart(2, "0")}`;
      const timeStr = `${String(hour).padStart(2, "0")}:${String(minute).padStart(2, "0")}:${String(second).padStart(2, "0")}`;
      return { expression: `${dateStr}T${timeStr}` };
    }
  } catch {
    return null;
  }
}

function equivalent(params) {
  const a = lookup(params.parsed_a);
  const b = lookup(params.parsed_b);
  if (!a || !b) return null;
  if (a instanceof Date && b instanceof Date) {
    return a.getTime() === b.getTime();
  }
  return null;
}

function runArithmetic() {
  return {
    result: "not-supported",
    notes: "JavaScript Date does not support ISO 8601 arithmetic",
  };
}

// ── Dispatch ─────────────────────────────────────────────────────────────────

const METHODS = {
  info,
  try_parse: tryParse,
  extract_components: extractComponents,
  generate,
  equivalent,
  run_arithmetic: runArithmetic,
};

const rl = readline.createInterface({ input: process.stdin });

rl.on("line", (line) => {
  line = line.trim();
  if (!line) return;
  let response;
  try {
    const request = JSON.parse(line);
    const method = request.method || "";
    const handler = METHODS[method];
    if (!handler) {
      response = { error: `Unknown method: ${method}` };
    } else {
      response = { result: handler(request.params || {}) };
    }
  } catch (e) {
    response = { error: e.message };
  }
  process.stdout.write(JSON.stringify(response) + "\n");
});
