**Status:** DONE


## Issue

Test `expect.components` fields use ~200+ distinct keys across all test files (e.g., `calendar`,
`ordinal`, `week`, `time`, `duration`, `interval`, `qualification`, `unspecified`, `exponential`,
etc.), but there is no schema or documentation defining the complete set of valid component keys,
their types, and their allowed values.

This makes it impossible to validate test files for structural correctness and creates risk of
inconsistent key names across files.

## Current state

Component keys are defined implicitly by usage:

```yaml
# From tests/8601-1/calendar-date.yaml
expect:
  valid: true
  components:
    calendar:
      year: 1985
      month: 4
      day: 12

# From tests/8601-2/qualification.yaml
expect:
  valid: true
  components:
    calendar:
      year: 2004
      month: 2
      day: 12
    qualification:
      uncertain: true
```

## RFC 5141 context

The component vocabulary is a committee-defined resource. Under RFC 5141 §2.2, such resources
can be identified using the `techdefined` production:

```
techdefined = ":tech" *techelement
```

For example, a component vocabulary definition could be identified as:

```
urn:iso:std:iso:8601:-1:ed-1:en:tech:tc154.wg5:vocabulary:component-model
```

However, since the component vocabulary is internal to this test suite (not part of the ISO
standard itself), a local identifier scheme is more appropriate:

```
vocab:component-model
```

## Proposed fix

1. **Create `schema/components.yaml`** — a YAML Schema file that defines the complete component model:
   - All valid top-level keys: `calendar`, `ordinal`, `week`, `time`, `duration`, `interval`,
     `recurring`, `qualification`, `unspecified`, `exponential`, `significant_digits`, `season`,
     `grouping`, `set`
   - Allowed sub-keys and types for each (e.g., `calendar.year` → integer, `time.utc_offset.sign` → `+`/`-`)
   - Required vs optional fields
   - Value constraints (e.g., month: 1–12, day: 1–31, hour: 0–24)

2. **Add `$schema` reference** — each test file's `expect.components` should validate against this schema

3. **Document in README.adoc** — add a "Component model" section listing all component types and fields

4. **Update `scripts/validate`** — add a phase that validates component keys and value types in all tests
   against the vocabulary

5. **Harmonize key names** — audit all test files for inconsistent key naming and normalize
