# For application developers

**Audience:** you're picking a date/time library for an application and want to know what you can rely on. This doc explains what ISO 8601 conformance *means in practice*, how to read a library's report, and what to watch out for.

You don't need to read the standards (ISO 8601-1:2026, -2:2026) to use this document. You don't need to know anything about ModSpec, conformance classes, or test runners.

## What "ISO 8601 conformance" means in practice

ISO 8601 is the international standard for writing dates and times. You've seen its extended format everywhere:

```
1985-04-12
1985-04-12T10:15:30+02:00
2024-W12-3
P1Y2M3DT4H
```

A library is "ISO 8601 conformant" if it correctly parses and produces these expressions. This sounds simple. It isn't, because:

1. The standard defines *basic format* (no separators, `19850412`) and *extended format* (with separators, `1985-04-12`). Many libraries only handle extended.
2. The standard defines *week dates* (`2024-W12-3`), *ordinal dates* (`2024-073`), *durations* (`P1Y2M3DT4H`), *time intervals* (`1985-04-12/1985-04-15`), and *recurring intervals* (`R5/...`).
3. Part 2 of the standard adds centuries (`19`), decades (`198x`), unspecified digits (`1985-04-XX`), qualifiers, and the EDTF subset used by libraries and archives.

No mainstream stdlib implements everything. "Conformant" is always relative to a feature subset.

## How to read a library's report

Open the dashboard's Implementations page and click a library. You'll see:

- **Overall pass rate**: percentage of capability checks that passed, computed only over what the library *declared* it implements.
- **Per-profile determination**: full / partial / none for each profile (RFC 3339, W3C Datetime, EDTF Level 0/1/2, ISO 8601-1 complete, ISO 8601-2 complete, ISO 8601-1 basic format).
- **Capability counts**: pass, partial, fail, not-supported, not-declared.

The important interpretation:

- **Pass rate < 100%** is normal. The standard is large.
- **Not-declared ≠ failure**. The library didn't claim to implement that class.
- **Not-supported ≠ failure either**. The library declared the class but a specific capability (e.g. arithmetic) isn't implemented.
- **Fail** is the only "this should work but doesn't" signal.

Click into any profile to see the per-test detail. Each failed test shows exactly what input was sent, what was expected, and what the library returned.

## Choosing by use case

The dashboard's current data (June 2026) supports these rough recommendations. Treat them as starting points — re-check the dashboard for the latest numbers.

### Calendar dates only (basic forms accepted)

You're parsing `YYYY-MM-DD` (extended) and need to also accept `YYYYMMDD` (basic, e.g. from legacy systems or filename stamps).

- **Best**: **Ruby Date** (all versions), **Python datetime** (3.10+), **Java java.time**, **Node.js Date** with explicit format handling.
- **Watch out**: Python 3.8 and Node.js 18 reject basic format unless you pass an explicit format string. C `strptime` is platform-dependent.

### Calendar dates with time and time zones

You're parsing `2024-03-15T10:30:00+02:00` and similar.

- **Best**: **Ruby Date/DateTime**, **Java java.time**, **Python datetime**.
- **Watch out**: Node.js Date has known timezone parsing quirks; verify with the actual time zones you need to support. C++ `std::chrono` lacks time zone names (only offsets).

### Week dates (`2024-W12-3`)

- **Best**: **Ruby Date**, **Java java.time**, **Rust chrono**.
- **Watch out**: Python `datetime` has no week-date parser. C++ `std::chrono` has no week-date parser. Basic format (`2024W123`) is unsupported almost everywhere.

### Durations (`P1Y2M3DT4H5M6S`)

- **Best**: **Ruby Duration** (gem), **Java java.time Duration/Period**.
- **Watch out**: Most stdlibs don't parse ISO 8601 durations at all. C, C++, Rust chrono, Node.js Date all return not-supported.

### Time intervals (`1985-04-12/1985-04-15`)

- **Best**: **Ruby Date** (with manual handling).
- **Watch out**: Interval parsing is rare. The abbreviated end form (`1985-04-12/15`) is unsupported everywhere.

### RFC 3339 (the Internet date/time format)

RFC 3339 is the profile used by JSON, XML, ATOM, and most APIs. It's a strict subset of ISO 8601 extended format.

- **Best**: **Java java.time**, **Ruby DateTime**, **Python datetime** (3.11+), **Node.js Date**.
- Most modern libraries handle RFC 3339 correctly. Verify leap-second handling if relevant to your domain.

### W3C Datetime format

Used in HTML `<time>`, XML Schema `dateTime`, and many web specs.

- **Best**: **Java java.time**, **Ruby DateTime**, **Python datetime** (3.11+).
- Same caveats as RFC 3339.

### EDTF (Extended Date/Time Format)

Used by libraries, archives, and historical databases. Levels 0, 1, 2.

- **Best**: **None of the stdlibs in the suite fully support EDTF.** This is a real gap; you'll need a dedicated EDTF library.
- Level 0 (seasons, uncertain/approximate) is the most attainable subset.

### ISO 8601-2 extensions (centuries, decades, qualifiers)

Used in archival, scientific, and bibliographic contexts.

- **Best**: **None of the stdlibs in the suite implement Part 2 comprehensively.**
- If you need Part 2, you need a specialized library.

## Common gotchas

These are the things that will bite you even with a "conformant" library.

### Basic format vs extended format

ISO 8601 allows both `19850412` and `1985-04-12`. They mean the same thing. Most libraries only handle extended. If your input might be in basic format (legacy data, file names, machine-generated timestamps), test explicitly.

### Week 53

ISO week 53 exists in some years (e.g. 2020, 2026). Some libraries compute week numbers wrong around the year boundary. Test with edge-case dates.

### Ordinal date `2024-073`

Day-of-year form. Easy to confuse with a different format. Verify that your library interprets `2024-073` as "March 13, 2024" (the 73rd day).

### Leap seconds

ISO 8601 permits `23:59:60`. Almost no library accepts it. If you work with astronomical or precise timekeeping data, this matters; otherwise ignore.

### Time zone designators

`+02:00`, `+0200`, `+02`, `Z` all mean different things to different libraries. The standard allows all four; your library probably accepts one.

### Negative years (BC/BCE)

`-0044-03-15` (the Ides of March, 44 BC). Most stdlibs reject negative years or compute them inconsistently.

## Using the dashboard

A one-minute tour:

1. **Dashboard page (`/`)**: top-level stats. Scroll to "Implementations Tested" for the family-grouped overview.
2. **Implementations page (`/implementations`)**: every library version grouped by family. Click any card for the per-version report.
3. **Matrix page (`/matrix`)**: every requirement × every version. Use the category filter (top right) to scope to a feature area. Click any cell for the underlying tests.
4. **Profiles page (`/profiles`)**: per-profile conformance across all libraries. Useful for "is my subset well-supported?"

## Beyond conformance

This suite tests *format conformance*. It does not test:

- **Internationalization**: locale-specific month names, calendar systems other than Gregorian.
- **Performance**: parsing speed, memory usage.
- **Daylight-saving edge cases**: the "spring forward" and "fall back" hours. Test these explicitly with your time zone data.
- **Calendar arithmetic correctness**: adding a month to January 31 gives different answers in different libraries (Feb 28? Feb 29? Error?).
- **Leap years**: most libraries handle these, but `1900-02-29` (not a leap year under Gregorian rules) is a classic off-by-one.

For these concerns, supplement the conformance suite with your own tests.

## Where to go next

- [For implementers](/docs/implementers) — if you also maintain the library.
- [The conformance model](/docs/conformance-model) — for the formal definitions behind "declared", "supported", "pass", "fail".
- The dashboard: start at the [implementations page](/implementations) and drill into the library you're considering.
