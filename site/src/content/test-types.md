# Test types

This document defines the test types used in the suite and the semantics of each. The suite uses six types; the current corpus exercises five (`round_trip` is defined and supported by the harness but not used in the test data today).

Each test in `tests/8601-{1,2}/*.yaml` has a `test_type:` field. The harness dispatches the test to the corresponding handler in `lib/test_suite/test_type_handlers.rb`. Adding a new test type means appending to the `HANDLERS` hash — no other change is required.

## The six test types

### `validity`

Asks: *is this expression well-formed ISO 8601?*

```yaml
test_type: validity
given:
  expression: "19850412"
expect:
  valid: true
```

The adapter's `try_parse` is called; only the `valid` boolean is checked. The adapter may parse successfully or fail; either way, the test asserts only that the expression is or isn't valid ISO 8601.

Use `validity` when you want to test the parser's *rejection* behavior (e.g. "basic format with separators should be rejected") without caring about the specific parsed components.

### `parsing`

Asks: *does this expression parse to the expected components?*

```yaml
test_type: parsing
given:
  expression: "1985-04-12"
expect:
  valid: true
  components:
    calendar:
      year: 1985
      month: 4
      day: 12
```

The adapter's `try_parse` is called; if valid, `extract_components` extracts the component hash. The expected and actual hashes are compared recursively.

Use `parsing` when the specific field values matter — calendar date, time, time zone, duration components, etc. This is the most common test type in the suite.

### `generation`

Asks: *given these components, does the adapter produce the expected expression?*

```yaml
test_type: generation
given:
  components:
    calendar:
      year: 1985
      month: 4
      day: 12
expect:
  expression: "1985-04-12"
```

The adapter's `generate` is called with the components. The returned expression is compared to `expect.expression` for exact equality.

Use `generation` to test the formatting path. Generation tests catch bugs where a library parses correctly but emits a non-canonical or wrong form.

### `equivalence`

Asks: *do these two expressions represent the same instant?*

```yaml
test_type: equivalence
given:
  expression_a: "2024-03-15T10:00:00Z"
  expression_b: "2024-03-15T11:00:00+01:00"
expect:
  equivalent: true
```

Both expressions are parsed; the adapter's `equivalent?` compares the parsed objects. Returns `true`, `false`, or `nil` (cannot determine).

Use `equivalence` to test that the adapter correctly normalizes across representations — UTC vs. offset, basic vs. extended, etc.

### `round_trip`

Asks: *does parse → extract → generate → re-parse produce an equivalent result?*

```yaml
test_type: round_trip
given:
  expression: "1985-04-12"
expect:
  expression: "1985-04-12"   # optional; if absent, semantic equivalence is used
```

The expression is parsed, components are extracted, the adapter generates from those components, and the generated expression is either compared to `expect.expression` (if specified) or re-parsed and checked for semantic equivalence to the original.

Use `round_trip` to catch asymmetries between parse and format paths. A library that accepts `1985-04-12` but emits `04/12/1985` will fail this test even if its `parsing` and `generation` tests individually pass.

### `arithmetic`

Asks: *given a parsed expression and an arithmetic operation, does the adapter produce the expected result?*

```yaml
test_type: arithmetic
given:
  expression: "2024-03-15"
  operation: "add"
  duration: "P1M"
expect:
  expression: "2024-04-15"
```

The adapter's `run_arithmetic` is called. The default implementation returns `not-supported`; adapters that implement arithmetic override this method.

Use `arithmetic` to test date/time math: adding durations, computing differences, etc. Few stdlibs expose this in a way the adapter can call, so `arithmetic` tests are sparse across the corpus.

## Test type → adapter API mapping

Each test type drives specific adapter methods:

| Test type | Adapter methods called
|---|---
| `validity`     | `try_parse`
| `parsing`      | `try_parse`, `extract_components`
| `generation`   | `generate`
| `equivalence`  | `try_parse`, `equivalent?`
| `round_trip`   | `try_parse`, `extract_components`, `generate`, `equivalent?`
| `arithmetic`   | `run_arithmetic` (optional; default returns not-supported)

An adapter that does not implement a method can return `nil` (for `generate`, `equivalent?`, `run_arithmetic`) and the harness will record the test as `not-supported` rather than `fail`.

## Test type → capability mapping

The dashboard's Matrix view collapses the six test types into three capability columns per library:

- **Parse** — `parsing`, `validity` (does the library read this form?)
- **Gen** — `generation`, `round_trip` (does the library produce this form?)
- **Arith** — `arithmetic` (does the library compute with this form?)

`equivalence` does not get its own column; it is folded into Parse on the matrix because it relies on the parser.

## Common confusions

### "Why does my library pass `parsing` but fail `generation` for the same requirement?"

The two test types exercise different code paths. A library can parse `1985-04-12` correctly while its default formatter emits `1985-04-12T00:00:00` or some other canonical form that doesn't match `expect.expression`. This is common; it doesn't mean the library is wrong, only that its formatting canonicalization differs from the test's expected form.

### "Why does `round_trip` pass even though `generation` failed?"

When `expect.expression` is absent, `round_trip` falls back to semantic equivalence: parse the generated expression and check it matches the original parsed object. So a library that emits `1985-04-12T00` for input `1985-04-12` fails `generation` (different string) but passes `round_trip` (same calendar date).

### "What does `not-supported` mean for a `generation` test?"

The adapter's `generate` method returned `nil`. The library may not implement formatting for this component type, or the adapter's `generate` doesn't handle this case. Check the adapter source.

## Adding a new test type

1. Append a handler to `HANDLERS` in `lib/test_suite/test_type_handlers.rb`. The handler is a lambda taking `(adapter, test)` and returning a result hash.
2. The result hash must include `"result"` set to `"pass"`, `"fail"`, `"not-supported"`, or `"error"`. Include `"actual"` and `"notes"` for diagnostics.
3. Add tests using the new type in `tests/`.
4. Run `ruby scripts/validate` to confirm the schema accepts the new type.
5. Run `ruby scripts/run-tests` against any adapter to confirm dispatch works.

## Where to go next

- [The conformance model](/docs/conformance-model) — how test outcomes roll up into per-class and per-profile determinations.
- [Identifier scheme](/docs/identifier-scheme) — how test IDs are formed.
- [For implementers](/docs/implementers) — adapter API reference for each method these test types call.
