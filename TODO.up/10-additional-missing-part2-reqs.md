# TODO.up/10 — Additional missing Part 2 atomic reqs

**Status:** DONE
**Depends on:** TODO.up/07 (Part 2 bundle splits), TODO.up/09 (explicit-duration class)
**Unblocks:** TODO.up/11 (profiles), TODO.up/12 (regenerate)
**Completed by:** `10db1c4 feat(reqs): split bundled requirements into atomic per-format requirements` — `req:negative-year-*` reqs in `requirements/8601-2/negative-values.yaml`, `req:selection-position-i-*` reqs in `requirements/8601-2/date-time-selection.yaml`

## Problem

The Part 2 audit surfaced four clusters of atomic reqs that are entirely missing from the suite (not bundled — just absent). Each cluster is a single clause or sub-clause that enumerates options not currently modeled.

## Scope

### A. Year before one (Clause 4.3.7)

ISO 8601-2:2026 Clause 4.3.7 introduces explicit grammar for years before year 0001. Currently implicit in `req:expansion` (Part 1 Clause 3.4) but the Part 2 clause enumerates distinct formats.

Add 3 reqs to `requirements/8601-2/negative-values.yaml`:
- `req:negative-year-expanded-form` — expanded form (`-YYYYY` and beyond) for years before 0
- `req:negative-year-sign-mandatory` — minus sign never optional for negative years
- `req:negative-year-precision` — expanded form precision rules for negative values

Tests: `tests/8601-2/negative-values.yaml` — add 3 tests.

### B. Position selection I (Clause 12.3.9)

Clause 12.3.9 defines "position selection I" — selecting the i-th occurrence within an interval. Currently bundled into `req-class:date-time-selection` but not enumerated atomically.

Add to `requirements/8601-2/date-time-selection.yaml`:
- `req:selection-position-i-single` — `[interval]/[i]` selects the i-th element
- `req:selection-position-i-last` — `i=-1` selects the last element (negative indexing)
- `req:selection-position-i-out-of-range` — `i` outside `[1, N]` is invalid (negative test)

Tests: `tests/8601-2/date-time-selection.yaml` — add 3 tests.

### C. Nested selection (Clause 12.3.11)

Clause 12.3.11 defines nested selection — selecting within a selection. Not modeled.

Add to `requirements/8601-2/date-time-selection.yaml`:
- `req:selection-nested-arbitrary-depth` — selections may nest to arbitrary depth
- `req:selection-nested-parenthesization` — parentheses or brackets required for nested expression disambiguation
- `req:selection-nested-valid-only-if-outer-valid` — semantic rule: nested selection is valid only if outer selection is valid

Tests: 3 tests covering valid nested, invalid (unparenthesized), and outer-invalid case.

### D. Reduced-precision unspecified (Clause 9.2.6–9.2.10)

Clause 9 enumerates "unspecified digits" forms. Sub-clauses 9.2.6 through 9.2.10 cover reduced-precision variants of unspecified values. Currently `req:unspecified-anywhere-calendar-date` bundles all of them.

Split `req:unspecified-anywhere-calendar-date` into per-Clause-9.2 form atomic reqs:
- `req:unspecified-year-omitted` — Clause 9.2.6: year omitted entirely
- `req:unspecified-month-omitted` — Clause 9.2.7: month omitted
- `req:unspecified-day-omitted` — Clause 9.2.8: day omitted
- `req:unspecified-combination` — Clause 9.2.9: combination of above
- `req:unspecified-time-omitted` — Clause 9.2.10: time components omitted

Re-map 10 existing tests across 5 new IDs.

### E. Explicit duration expansion (Clause 11)

Following TODO.up/09's creation of `req-class:explicit-duration-and-extensions`, expand the initial 6-req seed to cover the full Clause 11 enumeration.

Add to `requirements/8601-2/explicit-duration-and-extensions.yaml`:
- `req:explicit-duration-week-designator-W` — `PnW` form (week-only duration)
- `req:explicit-duration-fraction-lowest-order` — decimal fraction on lowest-order component
- `req:explicit-duration-zero-value-omission` — zero-value components may be omitted
- `req:explicit-duration-date-component-absence` — when no `T`, no time components allowed
- `req:explicit-duration-time-component-presence` — time components require `T` separator

Tests: 5 new tests in `tests/8601-2/explicit-duration-and-extensions.yaml`.

## Acceptance

- `ruby scripts/validate` passes.
- Each new req has ≥1 test.
- No remaining references to the bundled `req:unspecified-anywhere-calendar-date` (all 10 tests re-mapped).

## Files

- MODIFIED: `requirements/8601-2/negative-values.yaml`
- MODIFIED: `requirements/8601-2/date-time-selection.yaml`
- MODIFIED: `requirements/8601-2/unspecified-digits.yaml` (split unspecified-anywhere-calendar-date)
- MODIFIED: `requirements/8601-2/explicit-duration-and-extensions.yaml` (expand seed)
- MODIFIED: corresponding `tests/8601-2/*.yaml` files

## Estimated size

~70 lines new YAML, ~20 lines modified.
