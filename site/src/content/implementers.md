# For implementers

**Audience:** developers writing or maintaining a date/time library. You want to know:

1. Does my library conform to ISO 8601?
2. Where does it fail?
3. How do I fix it?

This document walks the answer to each question. It assumes you've read [the conformance model](/docs/conformance-model) and [the test types](/docs/test-types); skim those first if any terminology here is unclear.

## Quick start

1. Pick your runtime. The suite already has adapters for Ruby `Date`, Python `datetime`, Node.js `Date`, C `strftime`/`strptime`, C++ `std::chrono`, Rust `chrono`, and Java `java.time`. If yours is on this list, you can skip to [Reading the report](#reading-the-report).
2. If your library is *not* on the list, write an adapter (see [Writing an adapter](#writing-an-adapter)). The exec protocol lets you test any language without writing Ruby.
3. Run the suite: `ruby scripts/run-tests --adapter your-adapter` or `ruby scripts/run-tests --adapter "exec:node adapters/your-lib.mjs"`.
4. Read the result on the dashboard's `/implementation/<your-lib-id>` page or in the YAML written by `--output results/your-lib.yaml`.

## Declared conformance classes: read this first

The single most common confusion for new implementers is the `declared_conformance_classes` field. Read this section carefully.

A test result for a requirement your library has *not declared* is reported as `not-supported`, **not** as `fail`. This is intentional: it would be misleading to score a library against features it never claimed to implement.

Concretely: if your result file declares only `conf-class:calendar-date` and `conf-class:time-of-day`, every test outside those classes is recorded as `not-supported`. Your pass rate is computed over your declared classes only.

- **Underscoping is honest.** Declare only what you actually implement.
- **Overscoping is misleading.** Declaring a class you don't implement will tank your pass rate without giving you useful signal about where to focus.
- **The conformance class names** are the ModSpec class IDs from `requirements/8601-1/*.yaml` and `requirements/8601-2/*.yaml`. Examples: `conf-class:calendar-date`, `conf-class:duration`, `conf-class:explicit-representation`.

If your library is a general-purpose date library, the typical declaration set is all of Part 1 (9 classes) plus whichever Part 2 classes you implement.

See [the conformance model](/docs/conformance-model) for the full declared/not-declared, supported/not-supported matrix.

<a id="reading-the-report"></a>
## Reading the per-implementation report

Each implementation has a dashboard page at `/implementation/<id>` and a downloadable YAML at `/results/<id>.yaml`. Both surface the same data:

- **Capability counts:** pass, partial, fail, not-supported, not-declared.
- **Per-profile determination:** full / partial / none, computed across the conformance classes the profile selects.
- **Per-test detail:** input expression, expected components, actual output, the API the adapter called, and notes from the adapter about why it failed.

The capability matrix view (`/matrix`) shows every requirement × every version. Click any cell to expand the underlying test cases. For each test, the dashboard shows:

```
test_id:           conf-test:cal-date-parse-001
test_type:         parsing
given.expression:  "19850412"            ← input the adapter received
expect.components: {calendar: {year: 1985, month: 4, day: 12}}
result:            fail
actual:            {valid: false}        ← what the adapter returned
api:               Date.strptime         ← the API the adapter called
notes:             "strptime needs explicit format string"
```

The `notes` field is your strongest debugging signal: the adapter is expected to record *why* it couldn't process the input (missing format string, exception caught, ambiguous result, etc.).

<a id="writing-an-adapter"></a>
## Writing an adapter

Adapters live in `adapters/` and wrap a specific date/time implementation. Two paths:

### Native Ruby adapter

Copy `adapters/TEMPLATE.rb` to `adapters/<name>.rb`, rename the class to `<CamelCaseName>Adapter` (e.g. `rust-chrono` → `RustChronoAdapter`), and implement:

| Method | Returns
|---|---
| `try_parse(expression, options)`  | `{valid:, parsed:, api:}` or `{valid: false, error:, api:}`
| `extract_components(parsed)`      | Component hash, e.g. `{calendar: {year:, month:, day:}}`
| `generate(components)`            | `{expression: "..."}` or `nil`
| `equivalent?(obj_a, obj_b)`       | `true`, `false`, or `nil` (cannot determine)
| `run_arithmetic(test)`            | Optional: result hash, default not-supported

Run with `ruby scripts/run-tests --adapter <name>`.

### Exec adapter (any language)

For Python, JavaScript, Rust, Java, C — anything outside Ruby — use the exec protocol. The harness starts your adapter as a child process and exchanges newline-delimited JSON over stdin/stdout.

Adapter responsibilities:

1. On startup, respond to `info` with `{name, language, version}`.
2. On `try_parse`, parse the expression, cache the parsed object keyed by an opaque handle, and return `{valid: true, parsed: <handle>, api: "..."}` or `{valid: false, error: "...", api: "..."}`.
3. On `extract_components`, look up the cached object by handle and return a component hash.
4. On `generate`, build an expression from components and return `{expression: "..."}` or `null`.
5. On `equivalent`, compare two cached objects and return `true`/`false`/`null`.
6. On `run_arithmetic`, execute the arithmetic test or return not-supported.

Working examples:

- `adapters/python-datetime.py` (Python standard library)
- `adapters/node-datetime.js` (JavaScript Date)
- `adapters/rust-chrono/` (Rust chrono crate)
- `adapters/c-stdio.c` (C `strftime`/`strptime`)
- `adapters/cpp-chrono.cpp` (C++20 `std::chrono`)
- `adapters/JavaDateTime.java` (Java `java.time`)

Register the adapter in `lib/test_suite/capability_matrix.rb`'s `ADAPTER_DEFS` with `id`, `name`, `family`, `logo`, and the `exec:` command.

## Common failure patterns

These patterns recur across independent implementations. If your library is failing, start here.

### Basic format (`YYYYMMDD`, no separators)

The most common failure across the entire corpus. Most stdlib parsers only accept the *extended* format (`YYYY-MM-DD`) and reject the *basic* format (`YYYYMMDD`).

- **Affected requirement IDs**: `req:cal-date-basic-full`, `req:time-basic-full`, `req:date-time-cal-basic-local`, `req:dur-alt-calendar-basic`, and the entire `week-date-basic-*` family.
- **Typical fix**: support an explicit "compact"/"basic" format string alongside the extended one. Ruby's `Date.strptime("19850412", "%Y%m%d")` works; the adapter has to know to use it. If your library only has a single `parse` entry point, you'll need to detect the format and dispatch.

### Week dates, basic format

Week dates (`YYYY-Www-D`) are sparsely supported even in extended form. Basic form (`YYYYWwwD`) is rarer still.

- **Affected**: `req:week-date-basic-full`, `req:week-date-basic-week-only`.
- **Fix**: add an ISO 8601 week-date parser. C++ `std::chrono` and Python `datetime` both lack this; the suite's adapters for these languages mark the whole family as not-supported.

### 24-hour clock wraparound

Several libraries return the wrong result for midnight and times near it. The classic failure is `24:00:00` (end-of-day notation), which ISO 8601 permits but most libraries reject as out-of-range.

- **Affected**: `req:24-hour-clock`.
- **Fix**: accept `24:00:00` and normalize to `00:00:00` of the following day.

### Century and decade representation (Part 2)

ISO 8601-2 adds century (`19`) and decade (`198x`) representations. Almost no stdlib implements these — they're a Part 2 extension.

- **Affected**: `req:century-representation`, `req:decade-representation`.
- **Fix**: usually out-of-scope unless your library targets Part 2. If so, treat `19` as `1900-01-01` and `198x` as the range `1980-01-01 / 1989-12-31`.

### Duration alternate forms

ISO 8601 allows date-and-time duration (`P1Y2M3DT4H5M6S`) and alternate calendar duration. The alternate form (`P0Y-1D`, used to subtract) is rare.

- **Affected**: `req:dur-alt-calendar-basic`, `req:dur-alt-calendar-ext`.
- **Fix**: only relevant if your library implements durations.

### Time intervals with abbreviated end

`1985-04-12/15` means "from 1985-04-12 to 1985-04-15". Most parsers reject the abbreviated end form.

- **Affected**: `req:interval-abbreviated-end`.
- **Fix**: if your library has any interval support, the abbreviated end is a truncation rule — apply it before dispatching to your full parser.

## Recording results

Once your adapter passes the bulk of your declared classes, record the result in `results/<your-lib>.yaml` using the schema in `schema/conformance-result.yaml`. See `results/TEMPLATE.yaml` for the shape and any existing result file for a worked example.

Key fields:

- `id: result:<name>` — match the adapter `id`.
- `declared_conformance_classes: [...]` — the ModSpec class IDs your library claims to implement. **Set this honestly.**
- `verification: automated` if a script ran the tests; `manual` if a human recorded results; `inferred` if based on known behavior.
- Per-class aggregate status + per-test results with API call, input, expected, and actual.

## Declaring conformance

The conformance result file is your library's formal declaration. When published:

- Declare only classes your library actually passes.
- Update the declaration when your library adds or drops support.
- If your library is general-purpose, the typical declaration is all of Part 1 plus whatever Part 2 extensions you implement.

The suite's `scripts/validate` step cross-checks every result file against the schema; CI runs this on every push that touches YAML files.

## Where to go next

- [The conformance model](/docs/conformance-model) — declared vs. not-declared semantics in depth.
- [Test types](/docs/test-types) — what each test type expects.
- [For application developers](/docs/application-developers) — if you also maintain consumers of your library.
- [Project README](https://github.com/CalConnect/iso-8601-test-suite/blob/main/README.adoc) — full reference for the adapter protocol, YAML schemas, and CLI options.
