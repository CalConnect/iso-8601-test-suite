/* -*- mode: c -*-
 * ISO 8601 Test Suite — C stdlib strftime/strptime adapter (JSON protocol)
 *
 * Implements the newline-delimited JSON protocol for use with:
 *   ruby run-tests --adapter "exec:gcc -o /tmp/c-stdio adapters/c/stdio.c && /tmp/c-stdio"
 *
 * Uses C standard library strftime/strptime for date/time operations.
 * Limited to what POSIX/C99 provides:
 *   - strptime for parsing (basic + extended formats)
 *   - strftime for generation
 *   - No duration, interval, or recurring interval support
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <ctype.h>

#define MAX_LINE 4096
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

/* ── JSON helpers ─────────────────────────────────────────────────────────── */

static void json_str(FILE *f, const char *s) {
    fputc('"', f);
    for (; *s; s++) {
        if (*s == '"') fputs("\\\"", f);
        else if (*s == '\\') fputs("\\\\", f);
        else if (*s == '\n') fputs("\\n", f);
        else fputc(*s, f);
    }
    fputc('"', f);
}

/* Extract a string value for a given key from a JSON line.
 * Finds "key" then reads the following string value. */
static int json_get_string(const char *line, const char *key, char *out, size_t outsz) {
    char pattern[64];
    snprintf(pattern, sizeof(pattern), "\"%s\"", key);
    const char *p = strstr(line, pattern);
    if (!p) return 0;
    p += strlen(pattern);
    p = strchr(p, ':');
    if (!p) return 0;
    p++;
    while (*p == ' ' || *p == '\t') p++;
    if (*p != '"') return 0;
    p++;
    const char *end = p;
    while (*end && *end != '"') {
        if (*end == '\\' && end[1]) end++;
        end++;
    }
    size_t len = end - p;
    if (len >= outsz) len = outsz - 1;
    /* Unescape minimal */
    size_t oi = 0;
    for (size_t i = 0; i < len && oi < outsz - 1; i++) {
        if (p[i] == '\\' && i + 1 < len) {
            i++;
            switch (p[i]) {
                case 'n': out[oi++] = '\n'; break;
                case 't': out[oi++] = '\t'; break;
                case '"': out[oi++] = '"'; break;
                case '\\': out[oi++] = '\\'; break;
                default: out[oi++] = p[i]; break;
            }
        } else {
            out[oi++] = p[i];
        }
    }
    out[oi] = '\0';
    return 1;
}

/* Extract an integer value for a given key. Optionally scope the search
 * to start after a containing key (for nested objects). */
static int json_get_int_after(const char *start, const char *key, int *out) {
    char pattern[64];
    snprintf(pattern, sizeof(pattern), "\"%s\"", key);
    const char *p = strstr(start, pattern);
    if (!p) return 0;
    p += strlen(pattern);
    p = strchr(p, ':');
    if (!p) return 0;
    p++;
    while (*p == ' ' || *p == '\t') p++;
    *out = atoi(p);
    return 1;
}

/* Extract a handle (string like "h42" or number) → integer ID */
static int json_get_handle(const char *line, const char *key, int *out) {
    char raw[32];
    if (!json_get_string(line, key, raw, sizeof(raw))) return 0;
    /* Skip optional 'h' prefix */
    const char *p = raw;
    if (*p == 'h') p++;
    *out = atoi(p);
    return 1;
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
            /* Escaped literal like \., \+, \- */
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

    /* Z suffix */
    if (expr[len - 1] == 'Z') {
        expr[len - 1] = '\0';
        *has_offset = 1;
        *gmtoff = 0;
        return 1;
    }

    /* ±HH:MM or ±HHMM suffix */
    if (len >= 6 && (expr[len - 6] == '+' || expr[len - 6] == '-') &&
        isdigit((unsigned char)expr[len - 5]) && isdigit((unsigned char)expr[len - 4]) &&
        isdigit((unsigned char)expr[len - 2]) && isdigit((unsigned char)expr[len - 1]) &&
        expr[len - 3] == ':') {
        /* ±HH:MM */
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
        /* ±HHMM */
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

/* ── Protocol methods ─────────────────────────────────────────────────────── */

static void cmd_info(void) {
    const char *label = getenv("ADAPTER_LABEL");
    const char *version = getenv("ADAPTER_VERSION");
    printf("{\"result\":{\"name\":\"%s\",\"language\":\"c\",\"version\":\"%s\"}}\n",
           label ? label : "C strftime/strptime",
           version ? version : "c99");
}

static void cmd_try_parse(const char *orig_expr) {
    /* Strip trailing timezone suffix, parse offset manually */
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
            printf("{\"result\":{\"valid\":true,\"parsed\":\"h%d\",\"api\":\"strptime\"}}\n", h);
            return;
        }
    }
    printf("{\"result\":{\"valid\":false,\"error\":\"parse error\",\"api\":\"strptime\"}}\n");
}

static void cmd_extract_components(int handle) {
    CacheEntry *e = lookup(handle);
    if (!e) { printf("{\"result\":{}}\n"); return; }
    struct tm *tm = &e->tm;

    /* Normalize tm for strftime ( mktime fills wday/yday ) */
    struct tm normalized = *tm;
    normalized.tm_isdst = -1;
    mktime(&normalized);

    printf("{\"result\":{");
    printf("\"calendar\":{\"year\":%d,\"month\":%d,\"day\":%d}",
           tm->tm_year + 1900, tm->tm_mon + 1, tm->tm_mday);

    /* Week date components via strftime (works even though strptime can't parse %G/%V/%u) */
    char weekbuf[32];
    strftime(weekbuf, sizeof(weekbuf), "%G\t%V\t%u", &normalized);
    int wy, wn, wd;
    if (sscanf(weekbuf, "%d\t%d\t%d", &wy, &wn, &wd) == 3) {
        printf(",\"week\":{\"week_year\":%d,\"week\":%d,\"day_of_week\":%d}", wy, wn, wd);
    }

    /* Ordinal date */
    printf(",\"ordinal\":{\"year\":%d,\"day_of_year\":%d}",
           tm->tm_year + 1900, tm->tm_yday + 1);

    if (e->has_time) {
        printf(",\"time\":{\"hour\":%d,\"minute\":%d,\"second\":%d",
               tm->tm_hour, tm->tm_min, tm->tm_sec);
        if (e->has_offset) {
            int off = e->gmtoff;
            printf(",\"utc_offset\":{\"sign\":\"%s\",\"hours\":%d,\"minutes\":%d}",
                   off >= 0 ? "+" : "-", abs(off) / 3600, (abs(off) % 3600) / 60);
        }
        printf("}");
    }
    printf("}}\n");
}

static void cmd_generate(const char *components) {
    int year = 0, month = 0, day = 0, hour = 0, minute = 0, second = 0;
    int has_cal = 0, has_time = 0, is_basic = 0;
    int off_h = 0, off_m = 0;
    const char *off_sign = "+";
    int has_offset = 0;

    if (strstr(components, "\"basic\"")) is_basic = 1;

    const char *cal = strstr(components, "\"calendar\"");
    if (cal) {
        has_cal = json_get_int_after(cal, "year", &year)
               && json_get_int_after(cal, "month", &month)
               && json_get_int_after(cal, "day", &day);
    }

    const char *tc = strstr(components, "\"time\"");
    if (tc) {
        has_time = 1;
        json_get_int_after(tc, "hour", &hour);
        json_get_int_after(tc, "minute", &minute);
        json_get_int_after(tc, "second", &second);
        const char *off = strstr(tc, "\"utc_offset\"");
        if (off) {
            has_offset = 1;
            json_get_int_after(off, "hours", &off_h);
            json_get_int_after(off, "minutes", &off_m);
            char sign[8];
            if (json_get_string(off, "sign", sign, sizeof(sign))) off_sign = strdup(sign);
        }
    }

    if (!has_cal && !has_time) { printf("{\"result\":null}\n"); return; }

    char buf[64];
    if (has_cal) {
        struct tm tm = {0};
        tm.tm_year = year - 1900;
        tm.tm_mon = month - 1;
        tm.tm_mday = day;
        tm.tm_hour = hour;
        tm.tm_min = minute;
        tm.tm_sec = second;
        tm.tm_isdst = -1;
        mktime(&tm);

        const char *offset_suffix = "";
        char offbuf[16] = "";
        if (has_offset) {
            if (off_h == 0 && off_m == 0 && off_sign[0] == '+') {
                offset_suffix = "Z";
            } else {
                snprintf(offbuf, sizeof(offbuf), "%s%02d:%02d", off_sign, off_h, off_m);
                offset_suffix = offbuf;
            }
        }

        if (has_time) {
            if (is_basic)
                snprintf(buf, sizeof(buf), "%04d%02d%02dT%02d%02d%02d%s",
                         year, month, day, hour, minute, second, offset_suffix);
            else
                snprintf(buf, sizeof(buf), "%04d-%02d-%02dT%02d:%02d:%02d%s",
                         year, month, day, hour, minute, second, offset_suffix);
        } else {
            if (is_basic)
                snprintf(buf, sizeof(buf), "%04d%02d%02d", year, month, day);
            else
                snprintf(buf, sizeof(buf), "%04d-%02d-%02d", year, month, day);
        }
    } else {
        /* Time only */
        const char *offset_suffix = "";
        char offbuf[16] = "";
        if (has_offset) {
            if (off_h == 0 && off_m == 0 && off_sign[0] == '+') {
                offset_suffix = "Z";
            } else {
                snprintf(offbuf, sizeof(offbuf), "%s%02d:%02d", off_sign, off_h, off_m);
                offset_suffix = offbuf;
            }
        }
        if (is_basic)
            snprintf(buf, sizeof(buf), "%02d%02d%02d%s", hour, minute, second, offset_suffix);
        else
            snprintf(buf, sizeof(buf), "%02d:%02d:%02d%s", hour, minute, second, offset_suffix);
    }

    printf("{\"result\":{\"expression\":");
    json_str(stdout, buf);
    printf("}}\n");
}

static void cmd_equivalent(int h1, int h2) {
    CacheEntry *a = lookup(h1), *b = lookup(h2);
    if (!a || !b) { printf("{\"result\":null}\n"); return; }
    struct tm ta = a->tm, tb = b->tm;
    ta.tm_isdst = -1; tb.tm_isdst = -1;
    time_t t1 = mktime(&ta), t2 = mktime(&tb);
    printf("{\"result\":%s}\n", t1 == t2 ? "true" : "false");
}

/* ── Main loop ─────────────────────────────────────────────────────────────── */

int main(void) {
    char line[MAX_LINE];
    while (fgets(line, sizeof(line), stdin)) {
        size_t len = strlen(line);
        while (len > 0 && (line[len-1] == '\n' || line[len-1] == '\r')) line[--len] = '\0';
        if (len == 0) continue;

        /* Extract method */
        char method[32];
        if (!json_get_string(line, "method", method, sizeof(method))) {
            printf("{\"error\":\"no method\"}\n"); fflush(stdout); continue;
        }

        if (strcmp(method, "info") == 0) {
            cmd_info();
        } else if (strcmp(method, "try_parse") == 0) {
            char expr[512];
            if (!json_get_string(line, "expression", expr, sizeof(expr))) {
                printf("{\"error\":\"no expression\"}\n");
            } else {
                cmd_try_parse(expr);
            }
        } else if (strcmp(method, "extract_components") == 0) {
            int h;
            if (!json_get_handle(line, "parsed", &h)) {
                printf("{\"result\":{}}\n");
            } else {
                cmd_extract_components(h);
            }
        } else if (strcmp(method, "generate") == 0) {
            const char *cp = strstr(line, "\"components\"");
            if (!cp) {
                printf("{\"result\":null}\n");
            } else {
                cp = strchr(cp, ':');
                cmd_generate(cp ? cp + 1 : "{}");
            }
        } else if (strcmp(method, "equivalent") == 0) {
            int ha, hb;
            if (!json_get_handle(line, "parsed_a", &ha) || !json_get_handle(line, "parsed_b", &hb)) {
                printf("{\"result\":null}\n");
            } else {
                cmd_equivalent(ha, hb);
            }
        } else if (strcmp(method, "run_arithmetic") == 0) {
            printf("{\"result\":{\"result\":\"not-supported\",\"notes\":\"C has no ISO 8601 arithmetic\"}}\n");
        } else if (strcmp(method, "declared_conformance_classes") == 0) {
            printf("{\"result\":[\"conf-class:fundamentals\",\"conf-class:calendar-date\",\"conf-class:time-of-day\",\"conf-class:date-and-time\"]}\n");
        } else if (strcmp(method, "declared_profiles") == 0) {
            printf("{\"result\":[\"profile:iso-8601-1-core\"]}\n");
        } else {
            printf("{\"error\":\"Unknown method: %s\"}\n", method);
        }
        fflush(stdout);
    }
    return 0;
}
