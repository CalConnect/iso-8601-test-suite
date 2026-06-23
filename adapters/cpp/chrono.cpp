// ISO 8601 Test Suite — C++ std::chrono + get_time adapter (JSON protocol)
//
// Implements the newline-delimited JSON protocol for use with:
//   ruby run-tests --adapter "exec:./adapters/cpp/cpp-chrono"
//
// Uses C++20 <chrono> calendar types (year_month_day, weekday) combined with
// C-style get_time/strftime for parsing/formatting. strptime is not in the C++
// standard, so we use get_time with std::tm.
//
// Limitations:
//   - macOS get_time doesn't support %G/%V/%u (ISO week dates)
//   - macOS get_time doesn't support %z (timezone offset parsing)
//   - get_time with smart normalization accepts Feb 30 → Mar 2 (we re-validate)
//
// Build: clang++ -std=c++20 -O2 -o adapters/cpp/cpp-chrono adapters/cpp/chrono.cpp

#ifndef ADAPTER_LABEL
#define ADAPTER_LABEL "C++ std::chrono"
#endif

#include <chrono>
#include <cstdint>
#include <cstdio>
#include <cstring>
#include <ctime>
#include <iomanip>
#include <iostream>
#include <map>
#include <sstream>
#include <string>
#include <vector>

namespace ch = std::chrono;

// ── Object cache for handle-based passing through JSON ───────────────────────

struct CacheEntry {
    enum Type { TM_STRUCT, REDUCED } type;
    std::tm value;
    int offset_seconds = 0;
    bool has_offset = false;
    bool has_date = false;
    bool has_time = false;
    std::string reduced_type;  // "decade" or "century"
    int reduced_value = 0;
};

static std::map<std::string, CacheEntry> cache;
static int handle_counter = 0;

static std::string store(std::tm t, int off_secs = 0, bool has_off = false,
                         bool has_d = true, bool has_t = false) {
    handle_counter++;
    std::string h = "h" + std::to_string(handle_counter);
    cache[h] = CacheEntry{CacheEntry::TM_STRUCT, t, off_secs, has_off, has_d, has_t, "", 0};
    return h;
}

static std::string store_reduced(const std::string& type, int val) {
    handle_counter++;
    std::string h = "h" + std::to_string(handle_counter);
    cache[h] = CacheEntry{CacheEntry::REDUCED, {}, 0, false, false, false, type, val};
    return h;
}

// ── JSON helpers (minimal) ───────────────────────────────────────────────────

static std::string json_escape(const std::string& s) {
    std::string out;
    out.reserve(s.size() + 2);
    for (char c : s) {
        switch (c) {
            case '"': out += "\\\""; break;
            case '\\': out += "\\\\"; break;
            case '\n': out += "\\n"; break;
            case '\t': out += "\\t"; break;
            default: out += c;
        }
    }
    return out;
}

static std::string parse_json_string(const std::string& json, const std::string& key) {
    std::string pat = "\"" + key + "\"";
    size_t k = json.find(pat);
    if (k == std::string::npos) return "";
    k = json.find('"', k + pat.size());
    if (k == std::string::npos) return "";
    k++;
    std::string out;
    while (k < json.size() && json[k] != '"') {
        if (json[k] == '\\' && k + 1 < json.size()) {
            char next = json[k+1];
            if (next == 'n') out += '\n';
            else if (next == 't') out += '\t';
            else out += next;
            k += 2;
        } else {
            out += json[k++];
        }
    }
    return out;
}

static int parse_json_int(const std::string& json, const std::string& key, int default_val = 0) {
    std::string pat = "\"" + key + "\"";
    size_t k = json.find(pat);
    if (k == std::string::npos) return default_val;
    k += pat.size();
    k = json.find_first_of("-0123456789", k);
    if (k == std::string::npos) return default_val;
    try { return std::stoi(json.substr(k)); } catch (...) { return default_val; }
}

static std::string parse_json_object(const std::string& json, const std::string& key) {
    std::string pat = "\"" + key + "\"";
    size_t k = json.find(pat);
    if (k == std::string::npos) return "";
    k = json.find('{', k);
    if (k == std::string::npos) return "";
    int depth = 0;
    size_t start = k;
    for (; k < json.size(); k++) {
        if (json[k] == '{') depth++;
        else if (json[k] == '}') { depth--; if (depth == 0) return json.substr(start, k - start + 1); }
    }
    return "";
}

// Extract first key/value pairs from a flat JSON object
static std::map<std::string, std::string> parse_flat_object(const std::string& obj) {
    std::map<std::string, std::string> out;
    if (obj.empty()) return out;
    size_t i = 1; // skip {
    while (i < obj.size() && obj[i] != '}') {
        // skip whitespace/comma
        while (i < obj.size() && (obj[i] == ' ' || obj[i] == ',')) i++;
        if (i >= obj.size() || obj[i] == '}') break;
        // parse key
        if (obj[i] != '"') break;
        i++;
        std::string key;
        while (i < obj.size() && obj[i] != '"') {
            if (obj[i] == '\\' && i+1 < obj.size()) { key += obj[i+1]; i += 2; }
            else key += obj[i++];
        }
        i++; // skip closing quote
        while (i < obj.size() && (obj[i] == ' ' || obj[i] == ':')) i++;
        // parse value
        std::string val;
        if (i < obj.size() && obj[i] == '"') {
            i++;
            while (i < obj.size() && obj[i] != '"') {
                if (obj[i] == '\\' && i+1 < obj.size()) { val += obj[i+1]; i += 2; }
                else val += obj[i++];
            }
            i++;
        } else {
            while (i < obj.size() && obj[i] != ',' && obj[i] != '}') {
                val += obj[i++];
            }
        }
        out[key] = val;
    }
    return out;
}

// ── Timezone stripping ───────────────────────────────────────────────────────
// Returns true if a valid timezone suffix was found and stripped from expr.
static bool strip_tz(std::string& expr, int& offset_secs, bool& has_offset) {
    has_offset = false;
    offset_secs = 0;
    if (expr.empty()) return false;

    if (expr.back() == 'Z' || expr.back() == 'z') {
        expr.pop_back();
        offset_secs = 0;
        has_offset = true;
        return true;
    }
    // Look for offset suffix only if T is present
    size_t t_pos = expr.find('T');
    if (t_pos == std::string::npos) return false;

    size_t pos = expr.find_last_of("+-");
    if (pos == std::string::npos || pos <= t_pos) return false;
    std::string off = expr.substr(pos);
    if (off.size() != 3 && off.size() != 5 && !(off.size() == 6 && off[3] == ':')) return false;

    char sign = off[0];
    int hh = 0, mm = 0;
    if (off.size() == 3) {
        // +HH
        hh = (off[1]-'0')*10 + (off[2]-'0');
    } else if (off.size() == 5) {
        // +HHMM
        hh = (off[1]-'0')*10 + (off[2]-'0');
        mm = (off[3]-'0')*10 + (off[4]-'0');
    } else if (off.size() == 6) {
        // +HH:MM
        hh = (off[1]-'0')*10 + (off[2]-'0');
        mm = (off[4]-'0')*10 + (off[5]-'0');
    } else {
        return false;
    }
    if (hh > 23 || mm > 59) return false;
    offset_secs = (sign == '-' ? -1 : 1) * (hh*3600 + mm*60);
    expr = expr.substr(0, pos);
    has_offset = true;
    return true;
}

// ── Parse logic ──────────────────────────────────────────────────────────────

struct ParseResult {
    bool valid = false;
    std::string handle;
    std::string error;
    std::string api = "cpp-chrono";
};

static bool try_pattern(const std::string& expr, const std::string& fmt, std::tm& out) {
    std::istringstream is(expr);
    out = std::tm{};
    is >> std::get_time(&out, fmt.c_str());
    if (is.fail()) return false;
    // Reject trailing unparsed chars
    char c;
    if (is >> c) return false;
    return true;
}

static bool validate_tm(const std::tm& t, bool has_year, bool has_month, bool has_day) {
    if (has_month && (t.tm_mon < 0 || t.tm_mon > 11)) return false;
    if (has_day && (t.tm_mday < 1 || t.tm_mday > 31)) return false;
    // Validate day-of-month for the specific month
    static const int days_in_month[] = {31,28,31,30,31,30,31,31,30,31,30,31};
    if (has_year && has_month && has_day && t.tm_mon >= 0 && t.tm_mon <= 11) {
        int max_day = days_in_month[t.tm_mon];
        if (t.tm_mon == 1) {
            int y = t.tm_year + 1900;
            bool leap = (y % 4 == 0 && y % 100 != 0) || (y % 400 == 0);
            if (leap) max_day = 29;
        }
        if (t.tm_mday > max_day) return false;
    }
    return true;
}

struct Pattern {
    const char* fmt;
    const char* specifiers;
    int expected_len;  // -1 means no fixed length
};

// Validate that parsed tm has all the fields required by specifiers
static bool matches_pattern(const std::tm& t, const std::string& specifiers) {
    for (char s : specifiers) {
        switch (s) {
            case 'Y': if (t.tm_year == 0) return false; break;
            case 'm': if (t.tm_mon <= 0) return false; break;
            case 'd': if (t.tm_mday <= 0) return false; break;
            case 'j': if (t.tm_yday <= 0) return false; break;
            case 'H': if (t.tm_hour < 0) return false; break;
            case 'M': break;  // minute=0 is valid
            case 'S': break;  // second=0 is valid
        }
    }
    return true;
}

// Verify the input string contains required literal chars and has expected length
static bool validate_input_for_pattern(const std::string& expr, const std::string& fmt, int expected_len) {
    if (expected_len > 0 && (int)expr.size() != expected_len) return false;
    if (fmt.find('T') != std::string::npos && expr.find('T') == std::string::npos) return false;
    if (fmt.find(":") != std::string::npos && expr.find(':') == std::string::npos) return false;
    if (fmt.find("-W") != std::string::npos && expr.find("-W") == std::string::npos) return false;
    if (fmt.find('W') != std::string::npos && expr.find('W') == std::string::npos) return false;
    if (fmt.find('-') != std::string::npos && expr.find('-') == std::string::npos) return false;
    return true;
}

static ParseResult try_parse(const std::string& raw) {
    std::string expr = raw;
    int offset_secs = 0;
    bool has_offset = false;
    strip_tz(expr, offset_secs, has_offset);

    // Expanded year format: +YYYYYYMMDD or +YYYYYY-MM-DD
    bool expanded = false;
    int year_offset = 0;
    if (!expr.empty() && (expr[0] == '+' || expr[0] == '-')) {
        expanded = true;
        // Determine year width by total length (4-9 expanded year digits)
        // For +YYYYMMDD: sign + 4 year + 4 md = 9; +YYYYYYYYMMDD: 11
        // Strategy: try with 4, 5, 6 expanded digits
        std::vector<int> year_widths = {4, 5, 6, 7, 8};
        for (int yw : year_widths) {
            std::string pat_ext = "+" + std::string(yw, '%') + "Y-%m-%d";
            // Manual parsing: sign + yw year digits + optional -MM-DD or MMDD
            // Replace + with [+-] for the pattern
            // Actually, get_time uses %Y which already accepts + sign on some platforms
            std::tm t{};
            // Try extended: sign + yw digits + -MM-DD
            // Use sscanf for more control
            int y_sign = (expr[0] == '-') ? -1 : 1;
            std::string body = expr.substr(1);
            // Try basic: yw digits then 2 month then 2 day
            if ((int)body.size() == yw + 4) {
                std::string ystr = body.substr(0, yw);
                std::string mstr = body.substr(yw, 2);
                std::string dstr = body.substr(yw+2, 2);
                bool all_digit = true;
                for (char c : body) if (!std::isdigit((unsigned char)c)) { all_digit = false; break; }
                if (all_digit) {
                    int y = std::stoi(ystr) * y_sign;
                    int m = std::stoi(mstr);
                    int d = std::stoi(dstr);
                    std::tm ct{};
                    ct.tm_year = y - 1900;
                    ct.tm_mon = m - 1;
                    ct.tm_mday = d;
                    if (validate_tm(ct, true, true, true)) {
                        return ParseResult{true, store(ct, offset_secs, has_offset), "", "expanded-basic"};
                    }
                }
            }
            // Try extended: yw digits then -MM-DD
            if ((int)body.size() == yw + 6 && body[yw] == '-' && body[yw+3] == '-') {
                std::string ystr = body.substr(0, yw);
                std::string mstr = body.substr(yw+1, 2);
                std::string dstr = body.substr(yw+4, 2);
                bool all_digit_y = true, all_digit_md = true;
                for (char c : ystr) if (!std::isdigit((unsigned char)c)) { all_digit_y = false; break; }
                for (char c : mstr + dstr) if (!std::isdigit((unsigned char)c)) { all_digit_md = false; break; }
                if (all_digit_y && all_digit_md) {
                    int y = std::stoi(ystr) * y_sign;
                    int m = std::stoi(mstr);
                    int d = std::stoi(dstr);
                    std::tm ct{};
                    ct.tm_year = y - 1900;
                    ct.tm_mon = m - 1;
                    ct.tm_mday = d;
                    if (validate_tm(ct, true, true, true)) {
                        return ParseResult{true, store(ct, offset_secs, has_offset), "", "expanded-extended"};
                    }
                }
            }
        }
        return ParseResult{false, "", "parse error", "cpp-chrono"};
    }

    // Reduced-precision: exactly 2 digits = century, 3 digits = decade
    if (expr.size() == 2 && std::isdigit((unsigned char)expr[0]) && std::isdigit((unsigned char)expr[1])) {
        return ParseResult{true, store_reduced("century", std::stoi(expr)), "", "reduced-precision"};
    }
    if (expr.size() == 3) {
        bool all_d = true;
        for (char c : expr) if (!std::isdigit((unsigned char)c)) { all_d = false; break; }
        if (all_d) return ParseResult{true, store_reduced("decade", std::stoi(expr)), "", "reduced-precision"};
    }

    // DateTime patterns (must come before date-only)
    // Each entry: { pattern, expected_specifiers_for_validation, expected_input_length }
    static const Pattern dt_patterns[] = {
        {"%Y-%m-%dT%H:%M:%S", "YmdHMS", 19},
        {"%Y%m%dT%H%M%S",     "YmdHMS", 15},
        {"%Y-%m-%dT%H:%M",    "YmdHM",  16},
        {"%Y%m%dT%H%M",       "YmdHM",  12},
        {"%Y-%jT%H:%M:%S",    "YjHMS",  18},
        {"%Y%jT%H%M%S",       "YjHMS",  14},
        {"%Y-%jT%H:%M",       "YjHM",   15},
        {"%Y%jT%H%M",         "YjHM",   11},
        {"%Y-%m-%dT%H",       "YmdH",   13},
        {"%Y%m%dT%H",         "YmdH",    9},
    };

    for (const auto& pat : dt_patterns) {
        if (!validate_input_for_pattern(expr, pat.fmt, pat.expected_len)) continue;
        std::tm t{};
        if (try_pattern(expr, pat.fmt, t)) {
            if (!matches_pattern(t, pat.specifiers)) continue;
            if (std::string(pat.specifiers).find("m") != std::string::npos
                && std::string(pat.specifiers).find("d") != std::string::npos
                && !validate_tm(t, true, true, true)) continue;
            return ParseResult{true, store(t, offset_secs, has_offset, true, true), "", "get_time"};
        }
    }

    // Date-only patterns
    static const Pattern date_patterns[] = {
        {"%Y-%m-%d", "Ymd", 10},
        {"%Y%m%d",   "Ymd",  8},
        {"%Y-%m",    "Ym",   7},
        {"%Y-%j",    "Yj",   8},
        {"%Y%j",     "Yj",   7},
        {"%Y",       "Y",    4},
    };
    for (const auto& pat : date_patterns) {
        if (!validate_input_for_pattern(expr, pat.fmt, pat.expected_len)) continue;
        std::tm t{};
        if (try_pattern(expr, pat.fmt, t)) {
            if (!matches_pattern(t, pat.specifiers)) continue;
            if (std::string(pat.specifiers).find("m") != std::string::npos
                && std::string(pat.specifiers).find("d") != std::string::npos
                && !validate_tm(t, true, true, true)) continue;
            return ParseResult{true, store(t, offset_secs, has_offset, true, false), "", "get_time"};
        }
    }

    // Time-only patterns (strip T prefix)
    std::string time_str = expr;
    if (!time_str.empty() && time_str[0] == 'T') time_str = time_str.substr(1);
    static const Pattern time_patterns[] = {
        {"%H:%M:%S", "HMS", 8},
        {"%H%M%S",   "HMS", 6},
        {"%H:%M",    "HM",  5},
        {"%H%M",     "HM",  4},
        {"%H",       "H",   2},
    };
    for (const auto& pat : time_patterns) {
        std::tm t{};
        if (try_pattern(time_str, pat.fmt, t)) {
            return ParseResult{true, store(t, offset_secs, has_offset, false, true), "", "get_time"};
        }
    }

    return ParseResult{false, "", "parse error", "cpp-chrono"};
}

// ── Extract components ───────────────────────────────────────────────────────

static int day_of_year(int y, int m, int d) {
    static const int acc[] = {0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334};
    int doy = acc[m-1] + d;
    bool leap = (y % 4 == 0 && y % 100 != 0) || (y % 400 == 0);
    if (leap && m > 2) doy++;
    return doy;
}

// Convert day-of-year to month/day
static void yday_to_md(int y, int yday, int& m, int& d) {
    static const int days_before[] = {0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334, 366};
    bool leap = (y % 4 == 0 && y % 100 != 0) || (y % 400 == 0);
    int dy = yday;
    for (int i = 1; i <= 12; i++) {
        int next = days_before[i];
        if (i > 2 && leap) next += 1;
        if (dy <= next) {
            m = i;
            int prev = days_before[i-1];
            if (i-1 >= 2 && leap) prev += 1;
            d = dy - prev;
            return;
        }
    }
    m = 12; d = 31;
}

static void iso_week(int y, int m, int d, int& week_year, int& week, int& dow) {
    // ISO weekday: Monday=1, Sunday=7
    std::tm t{};
    t.tm_year = y - 1900;
    t.tm_mon = m - 1;
    t.tm_mday = d;
    std::mktime(&t);
    int wd = t.tm_wday; // Sunday=0, Monday=6
    dow = (wd == 0) ? 7 : wd;

    // Compute ISO week
    int doy = day_of_year(y, m, d);
    int week_calc = (10 + doy - dow) / 7;
    if (week_calc < 1) {
        // Belongs to last week of previous year
        week_year = y - 1;
        // Compute last week of prev year: Dec 28 is always in last week
        int prev_doy = day_of_year(y-1, 12, 28);
        std::tm p{};
        p.tm_year = y-1-1900; p.tm_mon = 11; p.tm_mday = 28;
        std::mktime(&p);
        int prev_wd = (p.tm_wday == 0) ? 7 : p.tm_wday;
        week = (10 + prev_doy - prev_wd) / 7;
    } else if (week_calc > 52) {
        // Check if it's actually week 53 or week 1 of next year
        int total_days = ((y % 4 == 0 && y % 100 != 0) || (y % 400 == 0)) ? 366 : 365;
        // Dec 28 always in last week
        int last_doy = day_of_year(y, 12, 28);
        std::tm l{};
        l.tm_year = y-1900; l.tm_mon = 11; l.tm_mday = 28;
        std::mktime(&l);
        int last_wd = (l.tm_wday == 0) ? 7 : l.tm_wday;
        int max_week = (10 + last_doy - last_wd) / 7;
        if (week_calc > max_week) {
            week_year = y + 1;
            week = 1;
        } else {
            week_year = y;
            week = week_calc;
        }
    } else {
        week_year = y;
        week = week_calc;
    }
}

static std::string extract_components(const std::string& handle) {
    auto it = cache.find(handle);
    if (it == cache.end()) return "{}";
    const CacheEntry& e = it->second;

    if (e.type == CacheEntry::REDUCED) {
        return "{\"calendar\":{\"" + e.reduced_type + "\":" + std::to_string(e.reduced_value) + "}}";
    }

    const std::tm& t = e.value;
    int y = t.tm_year + 1900;
    int m = t.tm_mon + 1;
    int d = t.tm_mday;
    int yday = t.tm_yday;

    // If only year+yday were parsed (ordinal date), convert to month/day
    bool has_date = e.has_date;
    if (has_date && t.tm_mday == 0 && t.tm_yday > 0) {
        yday_to_md(y, yday, m, d);
    }
    bool has_time = e.has_time;

    std::ostringstream os;
    os << "{";

    bool first = true;
    if (has_date) {
        os << "\"calendar\":{\"year\":" << y << ",\"month\":" << m << ",\"day\":" << d << "}";
        first = false;
        // Week date
        int wy, w, wd;
        iso_week(y, m, d, wy, w, wd);
        os << ",\"week\":{\"week_year\":" << wy << ",\"week\":" << w << ",\"day_of_week\":" << wd << "}";
        // Ordinal: use parsed yday if available, else compute
        int doy = (t.tm_yday > 0 && t.tm_mday == 0) ? t.tm_yday : day_of_year(y, m, d);
        os << ",\"ordinal\":{\"year\":" << y << ",\"day_of_year\":" << doy << "}";
    }

    if (has_time) {
        if (!first) os << ",";
        os << "\"time\":{\"hour\":" << t.tm_hour << ",\"minute\":" << t.tm_min << ",\"second\":" << t.tm_sec;
        if (e.has_offset) {
            int sign = (e.offset_seconds < 0) ? -1 : 1;
            int abs_sec = std::abs(e.offset_seconds);
            os << ",\"utc_offset\":{\"sign\":\"" << (sign > 0 ? "+" : "-") << "\","
               << "\"hours\":" << (abs_sec / 3600) << ",\"minutes\":" << ((abs_sec % 3600) / 60) << "}";
        }
        os << "}";
    }

    os << "}";
    return os.str();
}

// ── Generate ─────────────────────────────────────────────────────────────────

static std::string generate(const std::string& components) {
    std::string cal = parse_json_object(components, "calendar");
    std::string time = parse_json_object(components, "time");
    std::string fmt = parse_json_string(components, "format");
    bool basic = (fmt == "basic");

    if (!cal.empty()) {
        auto cv = parse_flat_object(cal);
        if (cv.count("year") && cv.count("month") && cv.count("day")) {
            int y = std::stoi(cv["year"]);
            int m = std::stoi(cv["month"]);
            int d = std::stoi(cv["day"]);
            char buf[32];
            if (basic) std::snprintf(buf, sizeof(buf), "%04d%02d%02d", y, m, d);
            else std::snprintf(buf, sizeof(buf), "%04d-%02d-%02d", y, m, d);
            return "{\"expression\":\"" + std::string(buf) + "\"}";
        }
    }
    return "";
}

// ── Equivalence ──────────────────────────────────────────────────────────────

static bool equivalent(const std::string& ha, const std::string& hb) {
    auto ia = cache.find(ha);
    auto ib = cache.find(hb);
    if (ia == cache.end() || ib == cache.end()) return false;
    const CacheEntry& a = ia->second;
    const CacheEntry& b = ib->second;
    if (a.type == CacheEntry::REDUCED || b.type == CacheEntry::REDUCED) {
        return a.type == b.type && a.reduced_type == b.reduced_type && a.reduced_value == b.reduced_value;
    }
    const std::tm& ta = a.value;
    const std::tm& tb = b.value;
    return (ta.tm_year == tb.tm_year && ta.tm_mon == tb.tm_mon && ta.tm_mday == tb.tm_mday &&
            ta.tm_hour == tb.tm_hour && ta.tm_min == tb.tm_min && ta.tm_sec == tb.tm_sec);
}

// ── Dispatch ─────────────────────────────────────────────────────────────────

static const char* DECLARED_CLASSES[] = {
    "conf-class:fundamentals",
    "conf-class:calendar-date",
    "conf-class:time-of-day",
    "conf-class:date-and-time",
};

int main() {
    std::ios::sync_with_stdio(false);
    std::cin.tie(nullptr);
    std::string line;
    while (std::getline(std::cin, line)) {
        if (line.empty()) continue;
        std::string response;
        try {
            std::string method = parse_json_string(line, "method");
            if (method == "info") {
                response = "{\"result\":{\"name\":\"" ADAPTER_LABEL "\",\"language\":\"cpp\",\"version\":\"C++20\"}}";
            } else if (method == "declared_conformance_classes") {
                response = "{\"result\":[";
                for (size_t i = 0; i < sizeof(DECLARED_CLASSES)/sizeof(DECLARED_CLASSES[0]); i++) {
                    if (i > 0) response += ",";
                    response += std::string("\"") + DECLARED_CLASSES[i] + "\"";
                }
                response += "]}";
            } else if (method == "declared_profiles") {
                response = "{\"result\":[\"profile:iso-8601-1-core\"]}";
            } else if (method == "try_parse") {
                std::string expr = parse_json_string(line, "expression");
                ParseResult pr = try_parse(expr);
                if (pr.valid) {
                    response = "{\"result\":{\"valid\":true,\"parsed\":\"" + pr.handle + "\",\"api\":\"" + json_escape(pr.api) + "\"}}";
                } else {
                    response = "{\"result\":{\"valid\":false,\"error\":\"" + json_escape(pr.error) + "\",\"api\":\"" + json_escape(pr.api) + "\"}}";
                }
            } else if (method == "extract_components") {
                std::string h = parse_json_string(line, "parsed");
                std::string comps = extract_components(h);
                response = "{\"result\":" + comps + "}";
            } else if (method == "generate") {
                std::string comps = parse_json_object(line, "components");
                std::string r = generate(comps);
                if (r.empty()) response = "{\"result\":null}";
                else response = "{\"result\":" + r + "}";
            } else if (method == "equivalent") {
                std::string ha = parse_json_string(line, "parsed_a");
                std::string hb = parse_json_string(line, "parsed_b");
                bool eq = equivalent(ha, hb);
                response = "{\"result\":" + std::string(eq ? "true" : "false") + "}";
            } else if (method == "run_arithmetic") {
                response = "{\"result\":{\"result\":\"not-supported\",\"notes\":\"C++ std::chrono arithmetic not implemented\"}}";
            } else {
                response = "{\"error\":\"Unknown method: " + json_escape(method) + "\"}";
            }
        } catch (const std::exception& ex) {
            response = std::string("{\"error\":\"") + json_escape(ex.what()) + "\"}";
        }
        std::cout << response << "\n";
        std::cout.flush();
    }
    return 0;
}
