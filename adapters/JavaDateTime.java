// ISO 8601 Test Suite — Java java.time adapter (JSON protocol)
//
// Implements the newline-delimited JSON protocol for use with:
//   ruby run-tests --adapter "exec:java -cp adapters JavaDateTime"
//
// Uses Java's standard library java.time (introduced in Java 8):
//   Parsing:  LocalDate/LocalDateTime/OffsetDateTime.parse with DateTimeFormatter
//   Generation: DateTimeFormatter.format
//
// java.time has comprehensive ISO 8601 support including:
//   - Extended and basic format dates
//   - Ordinal dates (yyyy-DDD)
//   - Week dates (yyyy-'W'ww-e, IsoFields)
//   - Time with UTC/offset (Z, ±HH:MM)
//   - Reduced precision dates

import java.io.*;
import java.time.*;
import java.time.format.*;
import java.time.temporal.*;
import java.util.*;

public class JavaDateTime {

    static int handleCounter = 0;
    static Map<String, Object> cache = new HashMap<>();

    static String store(Object obj) {
        handleCounter++;
        String h = "h" + handleCounter;
        cache.put(h, obj);
        return h;
    }

    static Object lookup(String handle) {
        return cache.get(handle);
    }

    // Reduced-precision representation: e.g. decade "198" or century "19"
    static class ReducedPrecisionDate {
        final String type;   // "decade" or "century"
        final int value;
        ReducedPrecisionDate(String type, int value) {
            this.type = type;
            this.value = value;
        }
    }

    // ── DateTimeFormatter registry ──────────────────────────────────────────────

    static final DateTimeFormatter WEEK_DATE_EXT = new DateTimeFormatterBuilder()
            .appendValue(IsoFields.WEEK_BASED_YEAR, 4)
            .appendLiteral("-W")
            .appendValue(IsoFields.WEEK_OF_WEEK_BASED_YEAR, 2)
            .appendLiteral("-")
            .appendValue(ChronoField.DAY_OF_WEEK, 1)
            .toFormatter();

    static final DateTimeFormatter WEEK_DATE_BASIC = new DateTimeFormatterBuilder()
            .appendValue(IsoFields.WEEK_BASED_YEAR, 4)
            .appendLiteral("W")
            .appendValue(IsoFields.WEEK_OF_WEEK_BASED_YEAR, 2)
            .appendValue(ChronoField.DAY_OF_WEEK, 1)
            .toFormatter();

    static final DateTimeFormatter ORDINAL_DATE_EXT = new DateTimeFormatterBuilder()
            .appendValue(ChronoField.YEAR, 4)
            .appendLiteral("-")
            .appendValue(ChronoField.DAY_OF_YEAR, 3)
            .toFormatter();

    static final DateTimeFormatter ORDINAL_DATE_BASIC = new DateTimeFormatterBuilder()
            .appendValue(ChronoField.YEAR, 4)
            .appendValue(ChronoField.DAY_OF_YEAR, 3)
            .toFormatter();

    static final DateTimeFormatter YEAR_MONTH = new DateTimeFormatterBuilder()
            .appendValue(ChronoField.YEAR, 4)
            .appendLiteral("-")
            .appendValue(ChronoField.MONTH_OF_YEAR, 2)
            .parseDefaulting(ChronoField.DAY_OF_MONTH, 1)
            .toFormatter();

    static final DateTimeFormatter YEAR_ONLY = new DateTimeFormatterBuilder()
            .appendValue(ChronoField.YEAR, 4)
            .parseDefaulting(ChronoField.MONTH_OF_YEAR, 1)
            .parseDefaulting(ChronoField.DAY_OF_MONTH, 1)
            .toFormatter();

    static final DateTimeFormatter[] DATETIME_FORMATTERS = {
        // Extended datetime with optional offset (ISO_OFFSET_DATE_TIME handles Z, ±HH:MM)
        DateTimeFormatter.ISO_OFFSET_DATE_TIME,
        DateTimeFormatter.ISO_LOCAL_DATE_TIME,
        // Basic datetime
        new DateTimeFormatterBuilder()
                .appendValue(ChronoField.YEAR, 4).appendValue(ChronoField.MONTH_OF_YEAR, 2)
                .appendValue(ChronoField.DAY_OF_MONTH, 2).appendLiteral("T")
                .appendValue(ChronoField.HOUR_OF_DAY, 2).appendValue(ChronoField.MINUTE_OF_HOUR, 2)
                .appendValue(ChronoField.SECOND_OF_MINUTE, 2).toFormatter().withResolverStyle(ResolverStyle.STRICT),
        new DateTimeFormatterBuilder()
                .appendValue(ChronoField.YEAR, 4).appendValue(ChronoField.MONTH_OF_YEAR, 2)
                .appendValue(ChronoField.DAY_OF_MONTH, 2).appendLiteral("T")
                .appendValue(ChronoField.HOUR_OF_DAY, 2).appendValue(ChronoField.MINUTE_OF_HOUR, 2)
                .toFormatter().withResolverStyle(ResolverStyle.STRICT),
        // Ordinal datetime
        DateTimeFormatter.ofPattern("yyyy-DDD'T'HH:mm:ss"),
        DateTimeFormatter.ofPattern("yyyyDDD'T'HHmmss"),
    };

    static final DateTimeFormatter BASIC_DATE = new DateTimeFormatterBuilder()
            .appendValue(ChronoField.YEAR, 4).appendValue(ChronoField.MONTH_OF_YEAR, 2)
            .appendValue(ChronoField.DAY_OF_MONTH, 2).toFormatter().withResolverStyle(ResolverStyle.STRICT);

    static final DateTimeFormatter[] DATE_FORMATTERS = {
        DateTimeFormatter.ISO_LOCAL_DATE,             // yyyy-MM-dd
        BASIC_DATE,                                   // basic date
        ORDINAL_DATE_EXT,                             // ordinal extended
        ORDINAL_DATE_BASIC,                           // ordinal basic
        WEEK_DATE_EXT,                                // week date extended
        WEEK_DATE_BASIC,                              // week date basic
        YEAR_MONTH,                                   // year-month
        YEAR_ONLY,                                    // year only
    };

    static final DateTimeFormatter[] TIME_FORMATTERS = {
        DateTimeFormatter.ISO_LOCAL_TIME,              // HH:mm:ss
        new DateTimeFormatterBuilder()
                .appendValue(ChronoField.HOUR_OF_DAY, 2).appendValue(ChronoField.MINUTE_OF_HOUR, 2)
                .toFormatter().withResolverStyle(ResolverStyle.STRICT),
        new DateTimeFormatterBuilder()
                .appendValue(ChronoField.HOUR_OF_DAY, 2).appendValue(ChronoField.MINUTE_OF_HOUR, 2)
                .appendValue(ChronoField.SECOND_OF_MINUTE, 2)
                .toFormatter().withResolverStyle(ResolverStyle.STRICT),
        new DateTimeFormatterBuilder()
                .appendValue(ChronoField.HOUR_OF_DAY, 2).appendValue(ChronoField.MINUTE_OF_HOUR, 2)
                .toFormatter().withResolverStyle(ResolverStyle.STRICT),
    };

    // ── Parse logic ─────────────────────────────────────────────────────────────

    static class ParseResult {
        boolean valid;
        String handle;
        String error;
        String api;

        static ParseResult ok(String handle, String api) {
            ParseResult r = new ParseResult();
            r.valid = true;
            r.handle = handle;
            r.api = api;
            return r;
        }

        static ParseResult fail(String api) {
            ParseResult r = new ParseResult();
            r.valid = false;
            r.error = "parse error";
            r.api = api;
            return r;
        }
    }

    static ParseResult tryParse(String expr) {
        String core = expr;
        ZoneOffset offset = null;
        boolean hasOffset = false;

        // Strip timezone suffix
        if (expr.endsWith("Z")) {
            core = expr.substring(0, expr.length() - 1);
            offset = ZoneOffset.UTC;
            hasOffset = true;
        } else if (expr.contains("T")) {
            // Only treat +/- as offset if there's a T (time portion)
            int lastPlusMinus = Math.max(expr.lastIndexOf('+'), expr.lastIndexOf('-'));
            if (lastPlusMinus > expr.indexOf('T')) {
                String offStr = expr.substring(lastPlusMinus);
                // offStr is one of: +HH:MM (6), +HHMM (5), +HH (3)
                if (offStr.length() == 6 && offStr.charAt(3) == ':'
                        || offStr.length() == 5
                        || offStr.length() == 3) {
                    try {
                        offset = ZoneOffset.of(offStr);
                        core = expr.substring(0, lastPlusMinus);
                        hasOffset = true;
                    } catch (DateTimeException ignored) {}
                }
            }
        }

        // Try ISO_OFFSET_DATE_TIME first (handles extended datetime with offset natively)
        if (hasOffset) {
            try {
                OffsetDateTime odt = OffsetDateTime.parse(expr, DateTimeFormatter.ISO_OFFSET_DATE_TIME);
                return ParseResult.ok(store(odt), "OffsetDateTime.parse");
            } catch (DateTimeParseException ignored) {}
        }

        // Try datetime formatters on the core (timezone-stripped) expression
        for (DateTimeFormatter fmt : DATETIME_FORMATTERS) {
            try {
                TemporalAccessor ta = fmt.parse(core);
                if (ta.isSupported(ChronoField.EPOCH_DAY) && ta.isSupported(ChronoField.SECOND_OF_DAY)) {
                    LocalDateTime ldt = LocalDateTime.from(ta);
                    if (hasOffset && offset != null) {
                        OffsetDateTime odt = ldt.atOffset(offset);
                        return ParseResult.ok(store(odt), "OffsetDateTime.atOffset");
                    }
                    return ParseResult.ok(store(ldt), "LocalDateTime.parse");
                }
            } catch (DateTimeParseException ignored) {}
        }

        // Try date formatters
        for (DateTimeFormatter fmt : DATE_FORMATTERS) {
            try {
                LocalDate ld = LocalDate.parse(core, fmt);
                return ParseResult.ok(store(ld, hasOffset ? offset : null), "LocalDate.parse");
            } catch (DateTimeParseException ignored) {}
        }

        // Reduced-precision dates (decade, century) — java.time has no native support
        // Century: exactly 2 digits. Decade: exactly 3 digits.
        if (core.matches("^[0-9]{2}$")) {
            return ParseResult.ok(store(new ReducedPrecisionDate("century", Integer.parseInt(core))), "reduced-precision");
        }
        if (core.matches("^[0-9]{3}$")) {
            return ParseResult.ok(store(new ReducedPrecisionDate("decade", Integer.parseInt(core))), "reduced-precision");
        }

        // Try time-only formatters (strip T prefix if present)
        String timeStr = core.startsWith("T") ? core.substring(1) : core;
        for (DateTimeFormatter fmt : TIME_FORMATTERS) {
            try {
                LocalTime lt = LocalTime.parse(timeStr, fmt);
                return ParseResult.ok(store(lt), "LocalTime.parse");
            } catch (DateTimeParseException ignored) {}
        }

        return ParseResult.fail("java.time");
    }

    // ── Extract components ──────────────────────────────────────────────────────

    static String extractComponents(String handle) {
        Object obj = lookup(handle);
        if (obj == null) return "{}";

        StringBuilder sb = new StringBuilder("{");

        LocalDate date = null;
        LocalTime time = null;
        ZoneOffset offset = null;

        if (obj instanceof OffsetDateTime) {
            OffsetDateTime odt = (OffsetDateTime) obj;
            date = odt.toLocalDate();
            time = odt.toLocalTime();
            offset = odt.getOffset();
        } else if (obj instanceof LocalDateTime) {
            LocalDateTime ldt = (LocalDateTime) obj;
            date = ldt.toLocalDate();
            time = ldt.toLocalTime();
        } else if (obj instanceof LocalDate) {
            date = (LocalDate) obj;
        } else if (obj instanceof LocalTime) {
            time = (LocalTime) obj;
        } else if (obj instanceof DateEntry) {
            DateEntry de = (DateEntry) obj;
            date = de.date;
            offset = de.offset;
        } else if (obj instanceof ReducedPrecisionDate) {
            ReducedPrecisionDate rp = (ReducedPrecisionDate) obj;
            sb.append("\"calendar\":{\"").append(rp.type).append("\":").append(rp.value).append("}");
            sb.append("}");
            return sb.toString();
        }

        if (date != null) {
            sb.append("\"calendar\":{")
              .append("\"year\":").append(date.getYear()).append(",")
              .append("\"month\":").append(date.getMonthValue()).append(",")
              .append("\"day\":").append(date.getDayOfMonth())
              .append("}");

            // Week date via IsoFields
            int weekYear = date.get(IsoFields.WEEK_BASED_YEAR);
            int weekNum = date.get(IsoFields.WEEK_OF_WEEK_BASED_YEAR);
            int dayOfWeek = date.get(ChronoField.DAY_OF_WEEK); // 1=Monday, 7=Sunday
            sb.append(",\"week\":{")
              .append("\"week_year\":").append(weekYear).append(",")
              .append("\"week\":").append(weekNum).append(",")
              .append("\"day_of_week\":").append(dayOfWeek)
              .append("}");

            // Ordinal date
            int dayOfYear = date.getDayOfYear();
            sb.append(",\"ordinal\":{")
              .append("\"year\":").append(date.getYear()).append(",")
              .append("\"day_of_year\":").append(dayOfYear)
              .append("}");
        }

        if (time != null) {
            if (sb.length() > 1) sb.append(",");
            sb.append("\"time\":{")
              .append("\"hour\":").append(time.getHour()).append(",")
              .append("\"minute\":").append(time.getMinute()).append(",")
              .append("\"second\":").append(time.getSecond());
            if (offset != null) {
                int totalSec = offset.getTotalSeconds();
                String sign = totalSec >= 0 ? "+" : "-";
                int absSec = Math.abs(totalSec);
                sb.append(",\"utc_offset\":{\"sign\":\"").append(sign)
                  .append("\",\"hours\":").append(absSec / 3600)
                  .append(",\"minutes\":").append((absSec % 3600) / 60)
                  .append("}");
            }
            sb.append("}");
        }

        sb.append("}");
        return sb.toString();
    }

    // ── Generate ────────────────────────────────────────────────────────────────

    static String generate(String components) {
        // Parse components (minimal JSON)
        Map<String, String> cal = parseObject(components, "calendar");
        Map<String, String> time = parseObject(components, "time");
        String fmt = parseString(components, "format");
        boolean basic = "basic".equals(fmt);

        if (cal != null) {
            int year = parseInt(cal.get("year"));
            int month = parseInt(cal.get("month"));
            int day = parseInt(cal.get("day"));
            if (year == 0) return null;

            if (time != null) {
                return generateDateTime(year, month, day, time, basic);
            }

            // Date only
            LocalDate date = LocalDate.of(year, month, day);
            if (basic) {
                return date.format(DateTimeFormatter.ofPattern("yyyyMMdd"));
            }
            return date.format(DateTimeFormatter.ISO_LOCAL_DATE);
        }

        // Time only
        if (time != null) {
            int hour = parseInt(time.get("hour"));
            int minute = parseInt(time.get("minute"));
            int second = parseInt(time.get("second"));
            if (hour == -1) return null;

            LocalTime lt = LocalTime.of(hour, minute == -1 ? 0 : minute, second == -1 ? 0 : second);
            String pattern = basic
                ? (minute >= 0 ? (second >= 0 ? "HHmmss" : "HHmm") : "HH")
                : (minute >= 0 ? (second >= 0 ? "HH:mm:ss" : "HH:mm") : "HH");
            String result = lt.format(DateTimeFormatter.ofPattern(pattern));

            String offStr = formatOffset(time, basic);
            return offStr != null ? result + offStr : result;
        }

        return null;
    }

    static String generateDateTime(int year, int month, int day, Map<String, String> time, boolean basic) {
        int hour = parseInt(time.get("hour"));
        int minute = parseInt(time.get("minute"));
        int second = parseInt(time.get("second"));
        hour = hour == -1 ? 0 : hour;
        minute = minute == -1 ? 0 : minute;
        second = second == -1 ? 0 : second;

        String offStr = formatOffset(time, basic);

        if (basic) {
            String dt = String.format("%04d%02d%02dT%02d%02d%02d", year, month, day, hour, minute, second);
            return offStr != null ? dt + offStr : dt;
        }

        String dt = String.format("%04d-%02d-%02dT%02d:%02d:%02d", year, month, day, hour, minute, second);
        return offStr != null ? dt + offStr : dt;
    }

    static String formatOffset(Map<String, String> time, boolean basic) {
        // extractPairs stores nested objects as raw JSON, so time.get("utc_offset")
        // returns e.g. {"sign":"+","hours":2,"minutes":0}
        String offRaw = time.get("utc_offset");
        if (offRaw == null) return null;
        String sign = parseString(offRaw, "sign");
        if (sign == null) return null;
        int hours = parseIntInJson(offRaw, "hours");
        int minutes = parseIntInJson(offRaw, "minutes");
        if (hours < 0 || minutes < 0) return null;
        if (hours == 0 && minutes == 0) return "Z";
        if (basic) return String.format("%s%02d%02d", sign, hours, minutes);
        return String.format("%s%02d:%02d", sign, hours, minutes);
    }

    // ── Minimal JSON helpers ────────────────────────────────────────────────────

    static String jsonString(String s) {
        StringBuilder sb = new StringBuilder("\"");
        for (char c : s.toCharArray()) {
            switch (c) {
                case '"': sb.append("\\\""); break;
                case '\\': sb.append("\\\\"); break;
                case '\n': sb.append("\\n"); break;
                case '\t': sb.append("\\t"); break;
                default: sb.append(c);
            }
        }
        sb.append("\"");
        return sb.toString();
    }

    static String parseString(String json, String key) {
        String pattern = "\"" + key + "\"";
        int idx = json.indexOf(pattern);
        if (idx < 0) return null;
        idx += pattern.length();
        idx = json.indexOf(':', idx);
        if (idx < 0) return null;
        idx++;
        while (idx < json.length() && (json.charAt(idx) == ' ' || json.charAt(idx) == '\t')) idx++;
        if (idx >= json.length() || json.charAt(idx) != '"') return null;
        idx++;
        int end = idx;
        while (end < json.length() && json.charAt(end) != '"') {
            if (json.charAt(end) == '\\' && end + 1 < json.length()) end++;
            end++;
        }
        return json.substring(idx, end);
    }

    static int parseInt(String s) {
        if (s == null) return -1;
        try { return Integer.parseInt(s.trim()); } catch (NumberFormatException e) { return -1; }
    }

    static int parseIntInJson(String json, String key) {
        String pattern = "\"" + key + "\"";
        int idx = json.indexOf(pattern);
        if (idx < 0) return -1;
        idx += pattern.length();
        idx = json.indexOf(':', idx);
        if (idx < 0) return -1;
        idx++;
        while (idx < json.length() && (json.charAt(idx) == ' ' || json.charAt(idx) == '\t')) idx++;
        int start = idx;
        if (idx < json.length() && json.charAt(idx) == '-') idx++;
        while (idx < json.length() && Character.isDigit(json.charAt(idx))) idx++;
        if (start == idx) return -1;
        try { return Integer.parseInt(json.substring(start, idx)); } catch (NumberFormatException e) { return -1; }
    }

    static Map<String, String> parseObject(String json, String key) {
        String pattern = "\"" + key + "\"";
        int idx = json.indexOf(pattern);
        if (idx < 0) return null;
        idx = json.indexOf('{', idx);
        if (idx < 0) return null;
        int depth = 1;
        int start = idx + 1;
        int end = start;
        while (end < json.length() && depth > 0) {
            char c = json.charAt(end);
            if (c == '{') depth++;
            else if (c == '}') depth--;
            if (depth == 0) break;
            end++;
        }
        String objStr = json.substring(start, end);
        Map<String, String> result = new HashMap<>();
        // Extract key-value pairs
        extractPairs(objStr, result);
        return result;
    }

    static void extractPairs(String json, Map<String, String> result) {
        int i = 0;
        while (i < json.length()) {
            // Find key
            while (i < json.length() && json.charAt(i) != '"') i++;
            if (i >= json.length()) break;
            int keyStart = i + 1;
            int keyEnd = keyStart;
            while (keyEnd < json.length() && json.charAt(keyEnd) != '"') keyEnd++;
            String key = json.substring(keyStart, keyEnd);
            i = keyEnd + 1;
            // Find value
            while (i < json.length() && json.charAt(i) != ':') i++;
            i++; // skip colon
            while (i < json.length() && (json.charAt(i) == ' ' || json.charAt(i) == '\t')) i++;
            if (i >= json.length()) break;
            String value;
            if (json.charAt(i) == '"') {
                int valStart = i + 1;
                int valEnd = valStart;
                while (valEnd < json.length() && json.charAt(valEnd) != '"') {
                    if (json.charAt(valEnd) == '\\') valEnd++;
                    valEnd++;
                }
                value = json.substring(valStart, valEnd);
                i = valEnd + 1;
            } else if (json.charAt(i) == '{') {
                // Nested object — store raw
                int depth = 1;
                int valStart = i;
                i++;
                while (i < json.length() && depth > 0) {
                    if (json.charAt(i) == '{') depth++;
                    else if (json.charAt(i) == '}') depth--;
                    i++;
                }
                value = json.substring(valStart, i);
            } else {
                int valStart = i;
                while (i < json.length() && json.charAt(i) != ',' && json.charAt(i) != '}') i++;
                value = json.substring(valStart, i).trim();
            }
            result.put(key, value);
            // Skip to next comma
            while (i < json.length() && json.charAt(i) != ',') i++;
            i++;
        }
    }

    // ── DateEntry helper for dates with offset ──────────────────────────────────

    static class DateEntry {
        LocalDate date;
        ZoneOffset offset;
        DateEntry(LocalDate date, ZoneOffset offset) {
            this.date = date;
            this.offset = offset;
        }
    }

    static String store(LocalDate date, ZoneOffset offset) {
        return store(new DateEntry(date, offset));
    }

    // ── Equivalence ─────────────────────────────────────────────────────────────

    static String equivalent(String h1, String h2) {
        Object a = lookup(h1);
        Object b = lookup(h2);
        if (a == null || b == null) return "null";
        return String.valueOf(a.equals(b));
    }

    // ── Declared conformance classes ────────────────────────────────────────────

    static final String[] DECLARED_CLASSES = {
        "conf-class:fundamentals",
        "conf-class:calendar-date",
        "conf-class:time-of-day",
        "conf-class:date-and-time",
    };

    // ── Main dispatch ───────────────────────────────────────────────────────────

    public static void main(String[] args) throws IOException {
        String javaVersion = System.getProperty("java.version");
        // Simplify version (e.g., "21.0.2" → "21")
        String major = javaVersion.split("\\.")[0];
        if (major.startsWith("1.")) major = javaVersion.split("\\.")[1]; // Java 8 style

        BufferedReader reader = new BufferedReader(new InputStreamReader(System.in));
        PrintWriter writer = new PrintWriter(new BufferedWriter(new OutputStreamWriter(System.out)));

        String line;
        while ((line = reader.readLine()) != null) {
            line = line.trim();
            if (line.isEmpty()) continue;

            String response;
            try {
                String method = parseString(line, "method");
                if (method == null) {
                    response = "{\"error\":\"no method\"}";
                } else switch (method) {
                    case "info":
                        response = "{\"result\":{\"name\":\"Java " + major + " java.time\","
                                 + "\"language\":\"java\","
                                 + "\"version\":" + jsonString(javaVersion) + "}}";
                        break;
                    case "declared_conformance_classes":
                        StringBuilder ccs = new StringBuilder("[");
                        for (int i = 0; i < DECLARED_CLASSES.length; i++) {
                            if (i > 0) ccs.append(",");
                            ccs.append("\"").append(DECLARED_CLASSES[i]).append("\"");
                        }
                        ccs.append("]");
                        response = "{\"result\":" + ccs + "}";
                        break;
                    case "declared_profiles":
                        response = "{\"result\":[\"profile:iso-8601-1-core\"]}";
                        break;
                    case "try_parse": {
                        String expr = parseString(line, "expression");
                        if (expr == null) {
                            response = "{\"error\":\"no expression\"}";
                        } else {
                            ParseResult pr = tryParse(expr);
                            if (pr.valid) {
                                response = "{\"result\":{\"valid\":true,\"parsed\":\"" + pr.handle
                                         + "\",\"api\":\"" + pr.api + "\"}}";
                            } else {
                                response = "{\"result\":{\"valid\":false,\"error\":\"" + pr.error
                                         + "\",\"api\":\"" + pr.api + "\"}}";
                            }
                        }
                        break;
                    }
                    case "extract_components": {
                        String handle = parseString(line, "parsed");
                        if (handle == null) {
                            response = "{\"result\":{}}";
                        } else {
                            response = "{\"result\":" + extractComponents(handle) + "}";
                        }
                        break;
                    }
                    case "generate": {
                        int compIdx = line.indexOf("\"components\"");
                        if (compIdx < 0) {
                            response = "{\"result\":null}";
                        } else {
                            compIdx = line.indexOf('{', compIdx);
                            String components = compIdx >= 0 ? extractJsonObject(line, compIdx) : "{}";
                            String expr = generate(components);
                            if (expr != null) {
                                response = "{\"result\":{\"expression\":" + jsonString(expr) + "}}";
                            } else {
                                response = "{\"result\":null}";
                            }
                        }
                        break;
                    }
                    case "equivalent": {
                        String ha = parseString(line, "parsed_a");
                        String hb = parseString(line, "parsed_b");
                        response = "{\"result\":" + equivalent(ha, hb) + "}";
                        break;
                    }
                    case "run_arithmetic":
                        response = "{\"result\":{\"result\":\"not-supported\","
                                 + "\"notes\":\"java.time does not support ISO 8601 arithmetic\"}}";
                        break;
                    default:
                        response = "{\"error\":\"Unknown method: " + method + "\"}";
                }
            } catch (Exception e) {
                response = "{\"error\":\"" + jsonString(e.getMessage()) + "\"}";
            }

            writer.println(response);
            writer.flush();
        }
    }

    static String extractJsonObject(String json, int start) {
        int depth = 0;
        int i = start;
        while (i < json.length()) {
            char c = json.charAt(i);
            if (c == '{') depth++;
            else if (c == '}') {
                depth--;
                if (depth == 0) return json.substring(start, i + 1);
            }
            i++;
        }
        return json.substring(start);
    }
}
