// ISO 8601 Test Suite — C++ std::chrono + get_time adapter (JSON protocol)
//
// Implements the newline-delimited JSON protocol for use with:
//   ruby run-tests --adapter "exec:./adapters/cpp/cpp-chrono"
//
// Uses C++20 <chrono> calendar types (year_month_day, weekday) combined with
// C-style get_time/strftime for parsing/formatting. strptime is not in the C++
// standard, so we use get_time with std::tm.
//
// Known limitations (declared as qualification notes):
//   - macOS get_time doesn't support %G/%V/%u (ISO week dates)
//   - macOS get_time doesn't support %z (timezone offset parsing); adapter
//     pre-strips the offset and re-applies it to the result.
//
// Not supported (returned as not-supported — C++ std::tm has no equivalent):
//   - Reduced precision dates (century, decade)
//   - ISO week date extraction (tm has no ISO week field; computing one would
//     be fabrication)
//   - Ordinal day-of-year when the input was a calendar date (tm_yday is only
//     populated by %j; computing it from y/m/d would be fabrication)
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
    std::tm value;
    int offset_seconds = 0;
    bool has_offset = false;
    bool has_date = false;
    bool has_time = false;
};

static std::map<std::string, CacheEntry> cache;
static int handle_counter = 0;

static std::string store(std::tm t, int off_secs = 0, bool has_off = false,
                         bool has_d = true, bool has_t = false) {
    handle_counter++;
    std::string h = "h" + std::to_string(handle_counter);
    cache[h] = CacheEntry{t, off_secs, has_off, has_d, has_t};
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
    char c;
    if (is >> c) return false;
    return true;
}

static ParseResult try_parse(const std::string& raw) {
    std::string expr = raw;
    int offset_secs = 0;
    bool has_offset = false;
    strip_tz(expr, offset_secs, has_offset);

    // DateTime patterns (must come before date-only)
    static const char* dt_formats[] = {
        "%Y-%m-%dT%H:%M:%S",
        "%Y%m%dT%H%M%S",
        "%Y-%m-%dT%H:%M",
        "%Y%m%dT%H%M",
        "%Y-%jT%H:%M:%S",
        "%Y%jT%H%M%S",
        "%Y-%jT%H:%M",
        "%Y%jT%H%M",
        "%Y-%m-%dT%H",
        "%Y%m%dT%H",
    };

    for (const char* fmt : dt_formats) {
        std::tm t{};
        if (try_pattern(expr, fmt, t)) {
            return ParseResult{true, store(t, offset_secs, has_offset, true, true), "", "get_time"};
        }
    }

    // Date-only patterns
    static const char* date_formats[] = {
        "%Y-%m-%d",
        "%Y%m%d",
        "%Y-%m",
        "%Y-%j",
        "%Y%j",
        "%Y",
    };
    for (const char* fmt : date_formats) {
        std::tm t{};
        if (try_pattern(expr, fmt, t)) {
            return ParseResult{true, store(t, offset_secs, has_offset, true, false), "", "get_time"};
        }
    }

    // Time-only patterns (strip T prefix)
    std::string time_str = expr;
    if (!time_str.empty() && time_str[0] == 'T') time_str = time_str.substr(1);
    static const char* time_formats[] = {
        "%H:%M:%S",
        "%H%M%S",
        "%H:%M",
        "%H%M",
        "%H",
    };
    for (const char* fmt : time_formats) {
        std::tm t{};
        if (try_pattern(time_str, fmt, t)) {
            return ParseResult{true, store(t, offset_secs, has_offset, false, true), "", "get_time"};
        }
    }

    return ParseResult{false, "", "parse error", "cpp-chrono"};
}

// ── Extract components ───────────────────────────────────────────────────────

static std::string extract_components(const std::string& handle) {
    auto it = cache.find(handle);
    if (it == cache.end()) return "{}";
    const CacheEntry& e = it->second;
    const std::tm& t = e.value;

    int y = t.tm_year + 1900;
    int m = t.tm_mon + 1;
    int d = t.tm_mday;

    std::ostringstream os;
    os << "{";

    bool first = true;
    if (e.has_date) {
        os << "\"calendar\":{\"year\":" << y << ",\"month\":" << m << ",\"day\":" << d << "}";
        first = false;
        if (t.tm_yday > 0) {
            os << ",\"ordinal\":{\"year\":" << y << ",\"day_of_year\":" << (t.tm_yday) << "}";
        }
    }

    if (e.has_time) {
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
    const std::tm& ta = ia->second.value;
    const std::tm& tb = ib->second.value;
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
