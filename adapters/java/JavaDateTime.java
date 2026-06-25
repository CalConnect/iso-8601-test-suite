// ISO 8601 Test Suite — Java java.time adapter (JSON protocol)
//
// Implements the newline-delimited JSON protocol for use with:
//   ruby run-tests --adapter "exec:java -cp adapters JavaDateTime"
//
// Uses Java's standard library java.time (introduced in Java 8):
//   Parsing:  LocalDate/LocalDateTime/OffsetDateTime.parse with DateTimeFormatter
//   Generation: DateTimeFormatter.format
//
// java.time supports most of ISO 8601-1 core, including:
//   - Extended and basic format dates
//   - Ordinal dates (yyyy-DDD)
//   - Week dates (yyyy-'W'ww-e, IsoFields)
//   - Time with UTC/offset (Z, ±HH:MM)
//
// Not supported (returned as not-supported — java.time has no native type):
//   - Reduced precision dates (century, decade)
//   - Fractional minute/hour (java.time normalizes to nanos, loses precision)

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

    // ── Wrapper types ───────────────────────────────────────────────────────────

    static class DateEntry {
        final LocalDate date;
        final ZoneOffset offset;
        DateEntry(LocalDate date, ZoneOffset offset) {
            this.date = date;
            this.offset = offset;
        }
    }

    static String store(LocalDate date, ZoneOffset offset) {
        return store(new DateEntry(date, offset));
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

    static final DateTimeFormatter BASIC_DATETIME_FULL = new DateTimeFormatterBuilder()
            .appendValue(ChronoField.YEAR, 4).appendValue(ChronoField.MONTH_OF_YEAR, 2)
            .appendValue(ChronoField.DAY_OF_MONTH, 2).appendLiteral("T")
            .appendValue(ChronoField.HOUR_OF_DAY, 2).appendValue(ChronoField.MINUTE_OF_HOUR, 2)
            .appendValue(ChronoField.SECOND_OF_MINUTE, 2)
            .toFormatter().withResolverStyle(ResolverStyle.STRICT);

    static final DateTimeFormatter BASIC_DATETIME_HM = new DateTimeFormatterBuilder()
            .appendValue(ChronoField.YEAR, 4).appendValue(ChronoField.MONTH_OF_YEAR, 2)
            .appendValue(ChronoField.DAY_OF_MONTH, 2).appendLiteral("T")
            .appendValue(ChronoField.HOUR_OF_DAY, 2).appendValue(ChronoField.MINUTE_OF_HOUR, 2)
            .toFormatter().withResolverStyle(ResolverStyle.STRICT);

    static final DateTimeFormatter BASIC_HHMMSS = new DateTimeFormatterBuilder()
            .appendValue(ChronoField.HOUR_OF_DAY, 2).appendValue(ChronoField.MINUTE_OF_HOUR, 2)
            .appendValue(ChronoField.SECOND_OF_MINUTE, 2)
            .toFormatter().withResolverStyle(ResolverStyle.STRICT);

    static final DateTimeFormatter BASIC_HHMM = new DateTimeFormatterBuilder()
            .appendValue(ChronoField.HOUR_OF_DAY, 2).appendValue(ChronoField.MINUTE_OF_HOUR, 2)
            .toFormatter().withResolverStyle(ResolverStyle.STRICT);

    static final DateTimeFormatter BASIC_HH = new DateTimeFormatterBuilder()
            .appendValue(ChronoField.HOUR_OF_DAY, 2)
            .toFormatter().withResolverStyle(ResolverStyle.STRICT);

    static final DateTimeFormatter BASIC_DATE = new DateTimeFormatterBuilder()
            .appendValue(ChronoField.YEAR, 4).appendValue(ChronoField.MONTH_OF_YEAR, 2)
            .appendValue(ChronoField.DAY_OF_MONTH, 2).toFormatter().withResolverStyle(ResolverStyle.STRICT);

    static final DateTimeFormatter[] DATETIME_FORMATTERS = {
        DateTimeFormatter.ISO_OFFSET_DATE_TIME,
        DateTimeFormatter.ISO_LOCAL_DATE_TIME,
        BASIC_DATETIME_FULL,
        BASIC_DATETIME_HM,
        DateTimeFormatter.ofPattern("yyyy-DDD'T'HH:mm:ss"),
        DateTimeFormatter.ofPattern("yyyyDDD'T'HHmmss"),
    };

    static final DateTimeFormatter[] DATE_FORMATTERS = {
        DateTimeFormatter.ISO_LOCAL_DATE,
        BASIC_DATE,
        ORDINAL_DATE_EXT,
        ORDINAL_DATE_BASIC,
        WEEK_DATE_EXT,
        WEEK_DATE_BASIC,
        YEAR_MONTH,
        YEAR_ONLY,
    };

    static final DateTimeFormatter[] TIME_FORMATTERS = {
        DateTimeFormatter.ISO_LOCAL_TIME,
        BASIC_HHMMSS,
        BASIC_HHMM,
        BASIC_HH,
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

        // Try time-only formatters. Strip a leading 'T' if present.
        String parseTimeStr = core.startsWith("T") ? core.substring(1) : core;
        for (DateTimeFormatter fmt : TIME_FORMATTERS) {
            try {
                LocalTime lt = LocalTime.parse(parseTimeStr, fmt);
                return ParseResult.ok(store(lt), "LocalTime.parse");
            } catch (DateTimeParseException ignored) {}
        }

        return ParseResult.fail("java.time");
    }

    // ── Extract components ──────────────────────────────────────────────────────

    static Map<String, Object> extractComponents(String handle) {
        Object obj = lookup(handle);
        if (obj == null) return new LinkedHashMap<>();

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
        }

        Map<String, Object> result = new LinkedHashMap<>();

        if (date != null) {
            Map<String, Object> cal = new LinkedHashMap<>();
            cal.put("year", date.getYear());
            cal.put("month", date.getMonthValue());
            cal.put("day", date.getDayOfMonth());
            result.put("calendar", cal);

            Map<String, Object> week = new LinkedHashMap<>();
            week.put("week_year", date.get(IsoFields.WEEK_BASED_YEAR));
            week.put("week", date.get(IsoFields.WEEK_OF_WEEK_BASED_YEAR));
            week.put("day_of_week", date.get(ChronoField.DAY_OF_WEEK));
            result.put("week", week);

            Map<String, Object> ord = new LinkedHashMap<>();
            ord.put("year", date.getYear());
            ord.put("day_of_year", date.getDayOfYear());
            result.put("ordinal", ord);
        }

        if (time != null) {
            Map<String, Object> t = new LinkedHashMap<>();
            t.put("hour", time.getHour());
            t.put("minute", time.getMinute());
            t.put("second", time.getSecond());
            if (offset != null) {
                int totalSec = offset.getTotalSeconds();
                String sign = totalSec >= 0 ? "+" : "-";
                int absSec = Math.abs(totalSec);
                Map<String, Object> off = new LinkedHashMap<>();
                off.put("sign", sign);
                off.put("hours", absSec / 3600);
                off.put("minutes", (absSec % 3600) / 60);
                t.put("utc_offset", off);
            }
            result.put("time", t);
        }

        return result;
    }

    // ── Generate ────────────────────────────────────────────────────────────────

    @SuppressWarnings("unchecked")
    static Map<String, Object> generate(Object componentsObj) {
        if (!(componentsObj instanceof Map)) return null;
        Map<String, Object> components = (Map<String, Object>) componentsObj;

        Map<String, Object> cal = (Map<String, Object>) components.get("calendar");
        Map<String, Object> time = (Map<String, Object>) components.get("time");
        String fmt = (String) components.get("format");
        boolean basic = "basic".equals(fmt);

        if (cal != null) {
            int year = toInt(cal.get("year"));
            int month = toInt(cal.get("month"));
            int day = toInt(cal.get("day"));
            if (year <= 0) return null;

            if (time != null) {
                return generateDateTime(year, month, day, time, basic);
            }

            if (month <= 0 || day <= 0) return null;

            LocalDate date = LocalDate.of(year, month, day);
            String expr = basic
                ? date.format(DateTimeFormatter.ofPattern("yyyyMMdd"))
                : date.format(DateTimeFormatter.ISO_LOCAL_DATE);
            return expressionMap(expr);
        }

        if (time != null) {
            int hour = toInt(time.get("hour"));
            if (hour < 0) return null;
            int minute = toInt(time.get("minute"));
            int second = toInt(time.get("second"));
            LocalTime lt = LocalTime.of(hour, minute < 0 ? 0 : minute, second < 0 ? 0 : second);
            String pattern = basic
                ? (minute >= 0 ? (second >= 0 ? "HHmmss" : "HHmm") : "HH")
                : (minute >= 0 ? (second >= 0 ? "HH:mm:ss" : "HH:mm") : "HH");
            String body = lt.format(DateTimeFormatter.ofPattern(pattern));
            String offStr = formatOffset(time, basic);
            return expressionMap(offStr != null ? body + offStr : body);
        }

        return null;
    }

    static Map<String, Object> generateDateTime(int year, int month, int day,
                                                Map<String, Object> time, boolean basic) {
        int hour = toIntOrZero(time.get("hour"));
        int minute = toIntOrZero(time.get("minute"));
        int second = toIntOrZero(time.get("second"));
        String offStr = formatOffset(time, basic);
        String body = basic
            ? String.format("%04d%02d%02dT%02d%02d%02d", year, month, day, hour, minute, second)
            : String.format("%04d-%02d-%02dT%02d:%02d:%02d", year, month, day, hour, minute, second);
        return expressionMap(offStr != null ? body + offStr : body);
    }

    static Map<String, Object> expressionMap(String expr) {
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("expression", expr);
        return m;
    }

    @SuppressWarnings("unchecked")
    static String formatOffset(Map<String, Object> time, boolean basic) {
        Object offObj = time.get("utc_offset");
        if (!(offObj instanceof Map)) return null;
        Map<String, Object> off = (Map<String, Object>) offObj;
        Object signObj = off.get("sign");
        if (!(signObj instanceof String)) return null;
        String sign = (String) signObj;
        int hours = toIntOrZero(off.get("hours"));
        int minutes = toIntOrZero(off.get("minutes"));
        if (hours == 0 && minutes == 0) return "Z";
        return basic
            ? String.format("%s%02d%02d", sign, hours, minutes)
            : String.format("%s%02d:%02d", sign, hours, minutes);
    }

    static int toInt(Object v) {
        if (v == null) return -1;
        if (v instanceof Number) return ((Number) v).intValue();
        try { return Integer.parseInt(String.valueOf(v).trim()); }
        catch (NumberFormatException e) { return -1; }
    }

    static int toIntOrZero(Object v) {
        int i = toInt(v);
        return i < 0 ? 0 : i;
    }

    // ── Equivalence ─────────────────────────────────────────────────────────────

    static Object equivalent(String h1, String h2) {
        Object a = lookup(h1);
        Object b = lookup(h2);
        if (a == null || b == null) return null;
        return a.equals(b);
    }

    // ── Declared conformance classes ────────────────────────────────────────────

    static final String[] DECLARED_CLASSES = {
        "conf-class:fundamentals",
        "conf-class:calendar-date",
        "conf-class:time-of-day",
        "conf-class:date-and-time",
    };

    static final String[] DECLARED_PROFILES = {
        "profile:iso-8601-1-core",
    };

    // ── Main dispatch ───────────────────────────────────────────────────────────

    public static void main(String[] args) throws IOException {
        String javaVersion = System.getProperty("java.version");
        String major = javaVersion.split("\\.")[0];
        if (major.startsWith("1.")) major = javaVersion.split("\\.")[1];

        BufferedReader reader = new BufferedReader(new InputStreamReader(System.in));
        PrintWriter writer = new PrintWriter(new BufferedWriter(new OutputStreamWriter(System.out)));

        String line;
        while ((line = reader.readLine()) != null) {
            line = line.trim();
            if (line.isEmpty()) continue;

            Map<String, Object> response;
            try {
                Object parsed = JsonReader.parse(line);
                if (!(parsed instanceof Map)) {
                    response = errorResponse("request must be a JSON object");
                } else {
                    @SuppressWarnings("unchecked")
                    Map<String, Object> request = (Map<String, Object>) parsed;
                    String method = (String) request.get("method");
                    Object paramsObj = request.get("params");
                    @SuppressWarnings("unchecked")
                    Map<String, Object> params = paramsObj instanceof Map
                        ? (Map<String, Object>) paramsObj
                        : Collections.emptyMap();
                    response = dispatch(method, params, major, javaVersion);
                }
            } catch (Exception e) {
                response = errorResponse(e.getMessage() != null ? e.getMessage() : e.toString());
            }

            writer.println(Json.write(response));
            writer.flush();
        }
    }

    static Map<String, Object> dispatch(String method, Map<String, Object> params,
                                        String major, String javaVersion) {
        if (method == null) return errorResponse("no method");
        switch (method) {
            case "info": {
                Map<String, Object> result = new LinkedHashMap<>();
                result.put("name", "Java " + major + " java.time");
                result.put("language", "java");
                result.put("version", javaVersion);
                return resultResponse(result);
            }
            case "declared_conformance_classes":
                return resultResponse(Arrays.asList(DECLARED_CLASSES));
            case "declared_profiles":
                return resultResponse(Arrays.asList(DECLARED_PROFILES));
            case "try_parse": {
                String expr = (String) params.get("expression");
                if (expr == null) return errorResponse("no expression");
                ParseResult pr = tryParse(expr);
                Map<String, Object> result = new LinkedHashMap<>();
                result.put("valid", pr.valid);
                if (pr.valid) {
                    result.put("parsed", pr.handle);
                } else {
                    result.put("error", pr.error != null ? pr.error : "parse error");
                }
                result.put("api", pr.api);
                return resultResponse(result);
            }
            case "extract_components": {
                String handle = (String) params.get("parsed");
                Object result = handle == null
                    ? new LinkedHashMap<String, Object>()
                    : extractComponents(handle);
                return resultResponse(result);
            }
            case "generate":
                return resultResponse(generate(params.get("components")));
            case "equivalent":
                return resultResponse(equivalent(
                    (String) params.get("parsed_a"),
                    (String) params.get("parsed_b")));
            case "run_arithmetic": {
                Map<String, Object> r = new LinkedHashMap<>();
                r.put("result", "not-supported");
                r.put("notes", "java.time does not support ISO 8601 arithmetic");
                return resultResponse(r);
            }
            default:
                return errorResponse("Unknown method: " + method);
        }
    }

    static Map<String, Object> resultResponse(Object result) {
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("result", result);
        return m;
    }

    static Map<String, Object> errorResponse(String error) {
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("error", error);
        return m;
    }

    // ── JSON writer ─────────────────────────────────────────────────────────────

    static class Json {
        static String write(Object v) {
            StringBuilder sb = new StringBuilder();
            writeValue(sb, v);
            return sb.toString();
        }

        static void writeValue(StringBuilder sb, Object v) {
            if (v == null) { sb.append("null"); return; }
            if (v instanceof String) { writeString(sb, (String) v); return; }
            if (v instanceof Boolean) { sb.append((Boolean) v ? "true" : "false"); return; }
            if (v instanceof Number) {
                Number n = (Number) v;
                if (n instanceof Double || n instanceof Float) {
                    double d = n.doubleValue();
                    if (Double.isNaN(d) || Double.isInfinite(d)) {
                        sb.append("null");
                    } else if (d == Math.floor(d) && Math.abs(d) < 1e15) {
                        sb.append(Long.toString((long) d));
                    } else {
                        sb.append(n.toString());
                    }
                } else {
                    sb.append(n.toString());
                }
                return;
            }
            if (v instanceof Map) { writeObject(sb, (Map<?, ?>) v); return; }
            if (v instanceof Object[]) { writeArray(sb, (Object[]) v); return; }
            if (v instanceof Iterable) { writeIterable(sb, (Iterable<?>) v); return; }
            writeString(sb, String.valueOf(v));
        }

        static void writeString(StringBuilder sb, String s) {
            sb.append('"');
            for (int i = 0; i < s.length(); i++) {
                char c = s.charAt(i);
                switch (c) {
                    case '"':  sb.append("\\\""); break;
                    case '\\': sb.append("\\\\"); break;
                    case '\b': sb.append("\\b"); break;
                    case '\f': sb.append("\\f"); break;
                    case '\n': sb.append("\\n"); break;
                    case '\r': sb.append("\\r"); break;
                    case '\t': sb.append("\\t"); break;
                    default:
                        if (c < 0x20) {
                            sb.append(String.format("\\u%04x", (int) c));
                        } else {
                            sb.append(c);
                        }
                }
            }
            sb.append('"');
        }

        static void writeObject(StringBuilder sb, Map<?, ?> m) {
            sb.append('{');
            boolean first = true;
            for (Map.Entry<?, ?> e : m.entrySet()) {
                if (!first) sb.append(',');
                first = false;
                writeString(sb, String.valueOf(e.getKey()));
                sb.append(':');
                writeValue(sb, e.getValue());
            }
            sb.append('}');
        }

        static void writeArray(StringBuilder sb, Object[] arr) {
            sb.append('[');
            for (int i = 0; i < arr.length; i++) {
                if (i > 0) sb.append(',');
                writeValue(sb, arr[i]);
            }
            sb.append(']');
        }

        static void writeIterable(StringBuilder sb, Iterable<?> it) {
            sb.append('[');
            boolean first = true;
            for (Object o : it) {
                if (!first) sb.append(',');
                first = false;
                writeValue(sb, o);
            }
            sb.append(']');
        }
    }

    // ── JSON reader ─────────────────────────────────────────────────────────────

    static class JsonReader {
        final String s;
        int pos;

        JsonReader(String s) { this.s = s; }

        static Object parse(String s) {
            JsonReader r = new JsonReader(s);
            r.skipWs();
            Object v = r.readValue();
            r.skipWs();
            return v;
        }

        void skipWs() {
            while (pos < s.length()) {
                char c = s.charAt(pos);
                if (c == ' ' || c == '\t' || c == '\n' || c == '\r') pos++;
                else break;
            }
        }

        Object readValue() {
            skipWs();
            if (pos >= s.length()) throw new RuntimeException("Unexpected EOF");
            char c = s.charAt(pos);
            switch (c) {
                case '{': return readObject();
                case '[': return readArray();
                case '"': return readString();
                case 't': case 'f': return readBool();
                case 'n': return readNull();
                default: return readNumber();
            }
        }

        Map<String, Object> readObject() {
            Map<String, Object> m = new LinkedHashMap<>();
            expect('{');
            skipWs();
            if (peek() == '}') { pos++; return m; }
            while (true) {
                skipWs();
                String key = readString();
                skipWs();
                expect(':');
                Object v = readValue();
                m.put(key, v);
                skipWs();
                char c = next();
                if (c == ',') continue;
                if (c == '}') break;
                throw new RuntimeException("Expected , or } at " + (pos - 1));
            }
            return m;
        }

        List<Object> readArray() {
            List<Object> a = new ArrayList<>();
            expect('[');
            skipWs();
            if (peek() == ']') { pos++; return a; }
            while (true) {
                a.add(readValue());
                skipWs();
                char c = next();
                if (c == ',') continue;
                if (c == ']') break;
                throw new RuntimeException("Expected , or ] at " + (pos - 1));
            }
            return a;
        }

        String readString() {
            expect('"');
            StringBuilder sb = new StringBuilder();
            while (pos < s.length()) {
                char c = s.charAt(pos++);
                if (c == '"') return sb.toString();
                if (c == '\\') {
                    if (pos >= s.length()) throw new RuntimeException("Unterminated escape");
                    char e = s.charAt(pos++);
                    switch (e) {
                        case '"':  sb.append('"');  break;
                        case '\\': sb.append('\\'); break;
                        case '/':  sb.append('/');  break;
                        case 'b':  sb.append('\b'); break;
                        case 'f':  sb.append('\f'); break;
                        case 'n':  sb.append('\n'); break;
                        case 'r':  sb.append('\r'); break;
                        case 't':  sb.append('\t'); break;
                        case 'u':
                            if (pos + 4 > s.length()) throw new RuntimeException("Bad \\u");
                            int code = Integer.parseInt(s.substring(pos, pos + 4), 16);
                            sb.append((char) code);
                            pos += 4;
                            break;
                        default: throw new RuntimeException("Unknown escape \\" + e);
                    }
                } else {
                    sb.append(c);
                }
            }
            throw new RuntimeException("Unterminated string");
        }

        Object readNumber() {
            int start = pos;
            while (pos < s.length()) {
                char c = s.charAt(pos);
                if (Character.isDigit(c) || c == '-' || c == '+'
                        || c == '.' || c == 'e' || c == 'E') {
                    pos++;
                } else {
                    break;
                }
            }
            if (start == pos) throw new RuntimeException("Expected number at " + pos);
            String num = s.substring(start, pos);
            if (num.contains(".") || num.contains("e") || num.contains("E")) {
                return Double.parseDouble(num);
            }
            return Long.parseLong(num);
        }

        Boolean readBool() {
            if (s.startsWith("true", pos))  { pos += 4; return Boolean.TRUE; }
            if (s.startsWith("false", pos)) { pos += 5; return Boolean.FALSE; }
            throw new RuntimeException("Invalid literal at " + pos);
        }

        Object readNull() {
            if (s.startsWith("null", pos)) { pos += 4; return null; }
            throw new RuntimeException("Invalid literal at " + pos);
        }

        void expect(char c) {
            if (pos >= s.length() || s.charAt(pos) != c) {
                throw new RuntimeException("Expected '" + c + "' at " + pos);
            }
            pos++;
        }

        char peek() {
            if (pos >= s.length()) throw new RuntimeException("Unexpected EOF");
            return s.charAt(pos);
        }

        char next() {
            if (pos >= s.length()) throw new RuntimeException("Unexpected EOF");
            return s.charAt(pos++);
        }
    }
}
