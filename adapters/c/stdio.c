/* -*- mode: c -*-
 * ISO 8601 Test Suite — C stdlib strftime/strptime adapter (JSON protocol)
 *
 * Implements the newline-delimited JSON protocol for use with:
 *   ruby run-tests --adapter "exec:gcc -o /tmp/c-stdio adapters/c/stdio.c adapters/c/vendor/cjson/cJSON.c && /tmp/c-stdio"
 *
 * Uses C standard library strftime/strptime for date/time operations.
 * Limited to what POSIX/C99 provides:
 *   - strptime for parsing (basic + extended formats)
 *   - strftime for generation
 *   - No duration, interval, or recurring interval support
 *
 * JSON I/O is handled by cJSON (vendored at adapters/c/vendor/cjson/,
 * MIT licensed — see LICENSE in that directory).
 *
 * Tier 2 qualification notes (declared via qualification_notes()):
 *   - input-preprocessing: trailing timezone suffix stripped before parse.
 *     macOS BSD libc strptime does not support %z, so the adapter
 *     recognizes 'Z' and numeric UTC offsets at the end of the expression,
 *     strips them, parses the core date/time with a format that has no
 *     timezone directive, then re-attaches the offset to the result.
 *
 * This is a workaround for a BSD libc gap. An upstream bug report should
 * be filed so the workaround can eventually be removed.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <ctype.h>

#include "vendor/cjson/cJSON.h"

#define MAX_LINE 65536
#define INITIAL_CACHE_CAPACITY 1024

/* ── Handle cache (dynamically grown — no silent wraparound) ──────────────── */

typedef struct {
    struct tm tm;
    int has_time;
    int gmtoff;
    int has_offset;
} CacheEntry;

static CacheEntry *cache = NULL;
static int cache_capacity = 0;
static int handle_counter = 0;

static void ensure_cache_capacity(int needed) {
    if (needed <= cache_capacity) return;
    int new_cap = cache_capacity == 0 ? INITIAL_CACHE_CAPACITY : cache_capacity;
    while (new_cap < needed) new_cap *= 2;
    CacheEntry *new_cache = realloc(cache, sizeof(CacheEntry) * new_cap);
    if (!new_cache) {
        fprintf(stderr, "FATAL: handle cache realloc failed\n");
        exit(1);
    }
    cache = new_cache;
    cache_capacity = new_cap;
}

static int store(struct tm *tm, int has_time, int gmtoff, int has_offset) {
    handle_counter++;
    ensure_cache_capacity(handle_counter + 1);
    cache[handle_counter].tm = *tm;
    cache[handle_counter].has_time = has_time;
    cache[handle_counter].gmtoff = gmtoff;
    cache[handle_counter].has_offset = has_offset;
    return handle_counter;
}

static CacheEntry *lookup(int h) {
    if (h < 1 || h > handle_counter) return NULL;
    return &cache[h];
}

/* ── Regex matching (minimal: ^...\d{n}...$ ) ────────────────────────────── */

static int match_pattern(const char *pattern, const char *str) {
    const char *p = pattern;
    const char *s = str;
    if (*p == '^') p++;
    while (*p && *p != '$') {
        if (p[0] == '\\' && p[1] == 'd') {
            int count = 1;
            p += 2;
            if (*p == '{') {
                count = atoi(p + 1);
                while (*p && *p != '}') p++;
                if (*p == '}') p++;
            }
            for (int i = 0; i < count; i++) {
                if (!isdigit((unsigned char)*s)) return 0;
                s++;
            }
        } else if (p[0] == '\\' && p[1]) {
            if (*s != p[1]) return 0;
            p += 2;
            s++;
        } else if (*p == *s) {
            p++;
            s++;
        } else {
            return 0;
        }
    }
    if (*p == '$') p++;
    return *p == '\0' && *s == '\0';
}

/* ── Timezone offset handling ────────────────────────────────────────────────
 * macOS strptime does not support %z. We strip the trailing timezone suffix
 * from the expression, parse the offset manually, then parse the core
 * date/time with a format string that has no timezone directives.
 */

static int parse_and_strip_tz(char *expr, int *gmtoff, int *has_offset) {
    size_t len = strlen(expr);
    *gmtoff = 0;
    *has_offset = 0;

    if (len == 0) return 1;

    if (expr[len - 1] == 'Z') {
        expr[len - 1] = '\0';
        *has_offset = 1;
        *gmtoff = 0;
        return 1;
    }

    if (len >= 6 && (expr[len - 6] == '+' || expr[len - 6] == '-') &&
        isdigit((unsigned char)expr[len - 5]) && isdigit((unsigned char)expr[len - 4]) &&
        isdigit((unsigned char)expr[len - 2]) && isdigit((unsigned char)expr[len - 1]) &&
        expr[len - 3] == ':') {
        int sign = (expr[len - 6] == '-') ? -1 : 1;
        int h = (expr[len - 5] - '0') * 10 + (expr[len - 4] - '0');
        int m = (expr[len - 2] - '0') * 10 + (expr[len - 1] - '0');
        *gmtoff = sign * (h * 3600 + m * 60);
        *has_offset = 1;
        expr[len - 6] = '\0';
        return 1;
    }

    if (len >= 5 && (expr[len - 5] == '+' || expr[len - 5] == '-') &&
        isdigit((unsigned char)expr[len - 4]) && isdigit((unsigned char)expr[len - 3]) &&
        isdigit((unsigned char)expr[len - 2]) && isdigit((unsigned char)expr[len - 1])) {
        int sign = (expr[len - 5] == '-') ? -1 : 1;
        int h = (expr[len - 4] - '0') * 10 + (expr[len - 3] - '0');
        int m = (expr[len - 2] - '0') * 10 + (expr[len - 1] - '0');
        *gmtoff = sign * (h * 3600 + m * 60);
        *has_offset = 1;
        expr[len - 5] = '\0';
        return 1;
    }

    return 1;
}

/* ── strptime format registry ───────────────────────────────────────────────
 * Patterns match the CORE date/time part only (timezone is stripped before
 * matching). This avoids %z which is unsupported on macOS strptime.
 */

typedef struct {
    const char *pattern;
    const char *format;
    int has_time;
} FormatEntry;

static const FormatEntry FORMATS[] = {
    /* Calendar date-time, extended format */
    {"^\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}$",  "%Y-%m-%dT%H:%M:%S", 1},
    {"^\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}$",          "%Y-%m-%dT%H:%M",    1},

    /* Calendar date-time, basic format */
    {"^\\d{4}\\d{2}\\d{2}T\\d{2}\\d{2}\\d{2}$",       "%Y%m%dT%H%M%S",      1},
    {"^\\d{4}\\d{2}\\d{2}T\\d{2}\\d{2}$",              "%Y%m%dT%H%M",        1},

    /* Ordinal date-time, extended format */
    {"^\\d{4}-\\d{3}T\\d{2}:\\d{2}:\\d{2}$",          "%Y-%jT%H:%M:%S",    1},
    {"^\\d{4}-\\d{3}T\\d{2}:\\d{2}$",                  "%Y-%jT%H:%M",       1},

    /* Ordinal date-time, basic format */
    {"^\\d{4}\\d{3}T\\d{2}\\d{2}\\d{2}$",              "%Y%jT%H%M%S",        1},
    {"^\\d{4}\\d{3}T\\d{2}\\d{2}$",                    "%Y%jT%H%M",          1},

    /* Date-only, extended */
    {"^\\d{4}-\\d{2}-\\d{2}$",   "%Y-%m-%d", 0},
    {"^\\d{4}-\\d{2}$",          "%Y-%m",    0},
    {"^\\d{4}$",                  "%Y",       0},
    {"^\\d{4}-\\d{3}$",          "%Y-%j",    0},

    /* Date-only, basic */
    {"^\\d{4}\\d{2}\\d{2}$",    "%Y%m%d",   0},
    {"^\\d{4}\\d{3}$",           "%Y%j",     0},

    /* Time-only, basic format with T prefix */
    {"^T\\d{2}\\d{2}\\d{2}$",   "T%H%M%S",  1},
    {"^T\\d{2}\\d{2}$",          "T%H%M",    1},
    {"^T\\d{2}$",                "T%H",      1},

    /* Time-only, extended format */
    {"^\\d{2}:\\d{2}:\\d{2}$",  "%H:%M:%S", 1},
    {"^\\d{2}:\\d{2}$",          "%H:%M",    1},
    {NULL, NULL, 0}
};

/* ── Output helpers ───────────────────────────────────────────────────────────
 * Each command returns a cJSON object representing the `result` payload.
 * The main loop wraps it as `{"result": <payload>}` and prints one line.
 */

static void reply(cJSON *result) {
    cJSON *wrapper = cJSON_CreateObject();
    cJSON_AddItemToObject(wrapper, "result", result ? result : cJSON_CreateNull());
    char *s = cJSON_PrintUnformatted(wrapper);
    fputs(s, stdout);
    fputc('\n', stdout);
    free(s);
    cJSON_Delete(wrapper);
}

static void reply_error(const char *msg) {
    cJSON *wrapper = cJSON_CreateObject();
    cJSON_AddStringToObject(wrapper, "error", msg);
    char *s = cJSON_PrintUnformatted(wrapper);
    fputs(s, stdout);
    fputc('\n', stdout);
    free(s);
    cJSON_Delete(wrapper);
}

/* ── Protocol methods ─────────────────────────────────────────────────────── */

static cJSON *cmd_info(void) {
    const char *label = getenv("ADAPTER_LABEL");
    const char *version = getenv("ADAPTER_VERSION");
    cJSON *o = cJSON_CreateObject();
    cJSON_AddStringToObject(o, "name", label ? label : "C strftime/strptime");
    cJSON_AddStringToObject(o, "language", "c");
    cJSON_AddStringToObject(o, "version", version ? version : "c99");
    return o;
}

static cJSON *cmd_try_parse(const char *orig_expr) {
    char expr[512];
    strncpy(expr, orig_expr, sizeof(expr) - 1);
    expr[sizeof(expr) - 1] = '\0';

    int gmtoff = 0, has_offset = 0;
    parse_and_strip_tz(expr, &gmtoff, &has_offset);

    for (const FormatEntry *e = FORMATS; e->pattern; e++) {
        if (!match_pattern(e->pattern, expr)) continue;
        struct tm tm = {0};
        tm.tm_isdst = -1;
        char *ret = strptime(expr, e->format, &tm);
        if (ret && *ret == '\0') {
            int h = store(&tm, e->has_time, gmtoff, has_offset && e->has_time);
            char handle_str[16];
            snprintf(handle_str, sizeof(handle_str), "h%d", h);
            cJSON *o = cJSON_CreateObject();
            cJSON_AddTrueToObject(o, "valid");
            cJSON_AddStringToObject(o, "parsed", handle_str);
            cJSON_AddStringToObject(o, "api", "strptime");
            return o;
        }
    }

    cJSON *o = cJSON_CreateObject();
    cJSON_AddFalseToObject(o, "valid");
    cJSON_AddStringToObject(o, "error", "parse error");
    cJSON_AddStringToObject(o, "api", "strptime");
    return o;
}

static cJSON *offset_to_json(int off) {
    cJSON *o = cJSON_CreateObject();
    cJSON_AddStringToObject(o, "sign", off >= 0 ? "+" : "-");
    int abs_off = abs(off);
    cJSON_AddNumberToObject(o, "hours", abs_off / 3600);
    cJSON_AddNumberToObject(o, "minutes", (abs_off % 3600) / 60);
    return o;
}

static cJSON *cmd_extract_components(int handle) {
    CacheEntry *e = lookup(handle);
    if (!e) return cJSON_CreateObject();

    struct tm *tm = &e->tm;
    struct tm normalized = *tm;
    normalized.tm_isdst = -1;
    mktime(&normalized);

    cJSON *result = cJSON_CreateObject();

    cJSON *cal = cJSON_CreateObject();
    cJSON_AddNumberToObject(cal, "year", tm->tm_year + 1900);
    cJSON_AddNumberToObject(cal, "month", tm->tm_mon + 1);
    cJSON_AddNumberToObject(cal, "day", tm->tm_mday);
    cJSON_AddItemToObject(result, "calendar", cal);

    /* Week date components via strftime (works even though strptime can't parse %G/%V/%u) */
    char weekbuf[32];
    strftime(weekbuf, sizeof(weekbuf), "%G\t%V\t%u", &normalized);
    int wy, wn, wd;
    if (sscanf(weekbuf, "%d\t%d\t%d", &wy, &wn, &wd) == 3) {
        cJSON *week = cJSON_CreateObject();
        cJSON_AddNumberToObject(week, "week_year", wy);
        cJSON_AddNumberToObject(week, "week", wn);
        cJSON_AddNumberToObject(week, "day_of_week", wd);
        cJSON_AddItemToObject(result, "week", week);
    }

    cJSON *ord = cJSON_CreateObject();
    cJSON_AddNumberToObject(ord, "year", tm->tm_year + 1900);
    cJSON_AddNumberToObject(ord, "day_of_year", tm->tm_yday + 1);
    cJSON_AddItemToObject(result, "ordinal", ord);

    if (e->has_time) {
        cJSON *t = cJSON_CreateObject();
        cJSON_AddNumberToObject(t, "hour", tm->tm_hour);
        cJSON_AddNumberToObject(t, "minute", tm->tm_min);
        cJSON_AddNumberToObject(t, "second", tm->tm_sec);
        if (e->has_offset) {
            cJSON_AddItemToObject(t, "utc_offset", offset_to_json(e->gmtoff));
        }
        cJSON_AddItemToObject(result, "time", t);
    }

    return result;
}

/* Read a nested integer: parent -> child_key. Returns 0 if absent. */
static int get_int(const cJSON *parent, const char *key, int *out) {
    cJSON *v = cJSON_GetObjectItemCaseSensitive(parent, key);
    if (!cJSON_IsNumber(v)) return 0;
    *out = v->valueint;
    return 1;
}

static int get_string(const cJSON *parent, const char *key, const char **out) {
    cJSON *v = cJSON_GetObjectItemCaseSensitive(parent, key);
    if (!cJSON_IsString(v)) return 0;
    *out = v->valuestring;
    return 1;
}

static void format_offset_suffix(char *buf, size_t bufsz, const char *sign, int h, int m) {
    if (h == 0 && m == 0 && sign[0] == '+') {
        snprintf(buf, bufsz, "Z");
    } else {
        snprintf(buf, bufsz, "%s%02d:%02d", sign, h, m);
    }
}

static cJSON *cmd_generate(const cJSON *components) {
    const char *fmt_str = NULL;
    int is_basic = (get_string(components, "format", &fmt_str) && strcmp(fmt_str, "basic") == 0);

    cJSON *cal = cJSON_GetObjectItemCaseSensitive(components, "calendar");
    cJSON *time_comp = cJSON_GetObjectItemCaseSensitive(components, "time");

    int has_cal = cJSON_IsObject(cal);
    int has_time = cJSON_IsObject(time_comp);

    if (!has_cal && !has_time) return NULL;

    int year = 0, month = 0, day = 0;
    if (has_cal) {
        if (!get_int(cal, "year", &year) || !get_int(cal, "month", &month) || !get_int(cal, "day", &day)) {
            return NULL;
        }
    }

    int hour = 0, minute = 0, second = 0;
    const char *off_sign = "+";
    int off_h = 0, off_m = 0, has_offset = 0;
    if (has_time) {
        get_int(time_comp, "hour", &hour);
        get_int(time_comp, "minute", &minute);
        get_int(time_comp, "second", &second);
        cJSON *off = cJSON_GetObjectItemCaseSensitive(time_comp, "utc_offset");
        if (cJSON_IsObject(off)) {
            has_offset = 1;
            get_int(off, "hours", &off_h);
            get_int(off, "minutes", &off_m);
            const char *sign_str = NULL;
            if (get_string(off, "sign", &sign_str)) off_sign = sign_str;
        }
    }

    char offset_suffix[16] = "";
    if (has_offset) {
        format_offset_suffix(offset_suffix, sizeof(offset_suffix), off_sign, off_h, off_m);
    }

    char buf[64];
    if (has_cal && has_time) {
        if (is_basic)
            snprintf(buf, sizeof(buf), "%04d%02d%02dT%02d%02d%02d%s",
                     year, month, day, hour, minute, second, offset_suffix);
        else
            snprintf(buf, sizeof(buf), "%04d-%02d-%02dT%02d:%02d:%02d%s",
                     year, month, day, hour, minute, second, offset_suffix);
    } else if (has_cal) {
        if (is_basic)
            snprintf(buf, sizeof(buf), "%04d%02d%02d", year, month, day);
        else
            snprintf(buf, sizeof(buf), "%04d-%02d-%02d", year, month, day);
    } else {
        if (is_basic)
            snprintf(buf, sizeof(buf), "%02d%02d%02d%s", hour, minute, second, offset_suffix);
        else
            snprintf(buf, sizeof(buf), "%02d:%02d:%02d%s", hour, minute, second, offset_suffix);
    }

    cJSON *o = cJSON_CreateObject();
    cJSON_AddStringToObject(o, "expression", buf);
    return o;
}

static cJSON *cmd_equivalent(int h1, int h2) {
    CacheEntry *a = lookup(h1), *b = lookup(h2);
    if (!a || !b) return cJSON_CreateNull();
    struct tm ta = a->tm, tb = b->tm;
    ta.tm_isdst = -1; tb.tm_isdst = -1;
    time_t t1 = mktime(&ta), t2 = mktime(&tb);
    return cJSON_CreateBool(t1 == t2);
}

static cJSON *qualification_notes(void) {
    cJSON *arr = cJSON_CreateArray();
    cJSON *note = cJSON_CreateObject();
    cJSON_AddStringToObject(note, "category", "input-preprocessing");
    cJSON_AddStringToObject(note, "summary", "trailing timezone suffix stripped before parse");
    cJSON_AddStringToObject(note, "detail",
        "macOS BSD libc strptime does not support %z, so the adapter "
        "recognizes 'Z' and numeric UTC offsets at the end of the expression, "
        "strips them, parses the core date/time with a format that has no "
        "timezone directive, then re-attaches the offset to the result.");
    cJSON_AddItemToArray(arr, note);
    return arr;
}

/* Parse a handle string of the form "h42" (or a bare number). Returns 0 on failure. */
static int handle_to_int(const cJSON *v, int *out) {
    if (cJSON_IsString(v)) {
        const char *s = v->valuestring;
        if (*s == 'h') s++;
        *out = atoi(s);
        return *out > 0;
    }
    if (cJSON_IsNumber(v)) {
        *out = v->valueint;
        return *out > 0;
    }
    return 0;
}

/* ── Main loop ─────────────────────────────────────────────────────────────── */

int main(void) {
    char line[MAX_LINE];
    while (fgets(line, sizeof(line), stdin)) {
        size_t len = strlen(line);
        while (len > 0 && (line[len-1] == '\n' || line[len-1] == '\r')) line[--len] = '\0';
        if (len == 0) continue;

        cJSON *req = cJSON_Parse(line);
        if (!req) {
            reply_error("invalid JSON");
            fflush(stdout);
            continue;
        }

        cJSON *method_v = cJSON_GetObjectItemCaseSensitive(req, "method");
        const char *method = cJSON_IsString(method_v) ? method_v->valuestring : "";
        cJSON *params = cJSON_GetObjectItemCaseSensitive(req, "params");

        if (strcmp(method, "info") == 0) {
            reply(cmd_info());
        } else if (strcmp(method, "try_parse") == 0) {
            const char *expr = NULL;
            if (!get_string(params, "expression", &expr)) expr = "";
            reply(cmd_try_parse(expr));
        } else if (strcmp(method, "extract_components") == 0) {
            cJSON *h_v = cJSON_GetObjectItemCaseSensitive(params, "parsed");
            int h;
            if (handle_to_int(h_v, &h)) reply(cmd_extract_components(h));
            else reply(cJSON_CreateObject());
        } else if (strcmp(method, "generate") == 0) {
            cJSON *comps = cJSON_GetObjectItemCaseSensitive(params, "components");
            reply(cmd_generate(comps ? comps : cJSON_CreateObject()));
        } else if (strcmp(method, "equivalent") == 0) {
            cJSON *ha_v = cJSON_GetObjectItemCaseSensitive(params, "parsed_a");
            cJSON *hb_v = cJSON_GetObjectItemCaseSensitive(params, "parsed_b");
            int ha, hb;
            if (handle_to_int(ha_v, &ha) && handle_to_int(hb_v, &hb)) {
                reply(cmd_equivalent(ha, hb));
            } else {
                reply(cJSON_CreateNull());
            }
        } else if (strcmp(method, "run_arithmetic") == 0) {
            cJSON *o = cJSON_CreateObject();
            cJSON_AddStringToObject(o, "result", "not-supported");
            cJSON_AddStringToObject(o, "notes", "C has no ISO 8601 arithmetic");
            reply(o);
        } else if (strcmp(method, "declared_conformance_classes") == 0) {
            cJSON *arr = cJSON_CreateArray();
            cJSON_AddItemToArray(arr, cJSON_CreateStringReference("conf-class:fundamentals"));
            cJSON_AddItemToArray(arr, cJSON_CreateStringReference("conf-class:calendar-date"));
            cJSON_AddItemToArray(arr, cJSON_CreateStringReference("conf-class:time-of-day"));
            cJSON_AddItemToArray(arr, cJSON_CreateStringReference("conf-class:date-and-time"));
            reply(arr);
        } else if (strcmp(method, "declared_profiles") == 0) {
            cJSON *arr = cJSON_CreateArray();
            cJSON_AddItemToArray(arr, cJSON_CreateStringReference("profile:iso-8601-1-core"));
            reply(arr);
        } else if (strcmp(method, "qualification_notes") == 0) {
            reply(qualification_notes());
        } else {
            char err[64];
            snprintf(err, sizeof(err), "Unknown method: %s", method);
            reply_error(err);
        }

        cJSON_Delete(req);
        fflush(stdout);
    }
    return 0;
}
