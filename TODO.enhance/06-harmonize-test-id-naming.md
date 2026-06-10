**Status:** DONE


## Issue

Part 1 and Part 2 conformance tests use different naming conventions for their `conf-test:` IDs,
making the test suite inconsistent.

## Current naming patterns

**Part 1** (abbreviated prefix style):
```
conf-test:cal-date-parse-001
conf-test:ord-date-parse-001
conf-test:week-date-parse-001
conf-test:time-parse-basic-001
conf-test:datetime-parse-001
conf-test:duration-parse-001
conf-test:interval-parse-001
conf-test:recurring-parse-001
```

**Part 2** (verbose full-name style):
```
conf-test:explicit-calendar-date-parsing-001
conf-test:negative-year-parsing-001
conf-test:exponential-year-parsing-001
conf-test:significant-digits-parsing-001
conf-test:qualification-parsing-001
conf-test:unspecified-digits-parsing-001
conf-test:seasons-parsing-001
```

## RFC 5141 context

Test IDs are committee-defined resources under RFC 5141:

```
urn:iso:std:iso:8601:-1:ed-1:en:tech:tc154.wg5:conf-test:cal-date-parse-001
urn:iso:std:iso:8601:-2:ed-1:en:tech:tc154.wg5:conf-test:explicit-calendar-date-parsing-001
```

Consistent naming makes the URN namespace more usable and predictable.

## Decision needed

Choose one convention and apply consistently:

**Option A — Abbreviated prefix** (current Part 1 style):
- `{class-prefix}-{test-type}-{seq}`
- Examples: `cal-date-parse-001`, `explicit-repr-parse-001`, `neg-val-parse-001`
- Pros: shorter, more scannable in large lists
- Cons: less self-documenting

**Option B — Verbose name** (current Part 2 style):
- `{descriptive-name}-{seq}`
- Examples: `calendar-date-parsing-basic-001`, `explicit-calendar-date-parsing-001`
- Pros: self-documenting, no ambiguity
- Cons: longer URNs

**Recommendation**: Option A is more practical — add a `test_type` tag and `description` field
for human readability while keeping IDs compact.

## Implementation steps

1. Decide on naming convention (Option A or B)
2. Rename all test IDs consistently across both parts
3. Update all cross-references (profile files, result files, suite.yaml)
4. Update `scripts/validate` to enforce the chosen convention via regex
5. Run `ruby scripts/validate` to verify no broken references
