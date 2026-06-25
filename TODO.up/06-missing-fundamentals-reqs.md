# TODO.up/06 — Add missing fundamentals reqs (leap seconds, proleptic)

**Status:** PENDING
**Depends on:** nothing
**Unblocks:** TODO.up/08 (tests update)

## Problem

Two atomic requirements from Clause 4 are not modeled:

1. **Leap seconds** (Clause 4.2.3 / 4.3.10) — the standard explicitly allows `ss=60` for positive leap seconds and `ss=58` for negative leap seconds. Currently implicit in `req:24-hour-clock` but not as its own atomic testable req.

2. **Proleptic Gregorian use before 1582** (Clause 4.2.1) — mutual-agreement rule for using Gregorian calendar before its introduction. Not modeled.

3. **Year range and minus sign rules** (Clause 4.3.2) — currently bundled into `req:year-representation`. Should split into:
   - 4-digit year range 0000–9999 (atomic)
   - Minus sign for years before year zero (atomic)
   - Expanded year form (atomic — but already covered by `req:expansion`)

## Scope

### Leap seconds — 3 new atomic reqs

Add to `requirements/8601-1/fundamentals.yaml`:
- `req:leap-second-positive` — second value 60 allowed for positive leap second
- `req:leap-second-negative` — second value 58 allowed for negative leap second
- `req:second-range-59-normal` — second 00-59 normal range (clarifying boundary)

### Proleptic Gregorian — 1 new req

- `req:proleptic-gregorian-mutual-agreement` — by mutual agreement, the Gregorian calendar may be used proleptically before 1582

### Year range split — split `req:year-representation` into 2

Replace with:
- `req:year-range-0000-9999` — 4-digit ordinal 0000 through 9999, beginning with 0000 for year zero
- `req:year-minus-sign` — minus sign prefix for years preceding year zero

(`req:expansion` already covers expanded years separately.)

## Tests to add

`tests/8601-1/fundamentals.yaml`:

- `fundamentals-valid-046` — input `2016-12-31T23:59:60` → valid (positive leap second, 2016 had one)
- `fundamentals-valid-047` — input `2017-12-31T23:59:60` → invalid (2017 had no leap second; harder to test, may skip)
- `fundamentals-valid-048` — input `1500-01-01` → valid under proleptic rule (mutual agreement)
- `fundamentals-valid-049` — input `-0001` → valid (year -1)
- `fundamentals-valid-050` — input `10000` → invalid (out of 4-digit range, requires expansion)

## Profiles update

- `iso-8601-1-complete.yaml` fundamentals section: add new req IDs.

## Acceptance

- `ruby scripts/validate` passes.
- Each new req has ≥1 test.

## Out of scope

- Modeling the IERS leap-second bulletin mechanism (out of scope for syntactic test suite).
- Adding atomic reqs for other Clause 4 concepts that are already adequately modeled.

## Files

- MODIFIED: `requirements/8601-1/fundamentals.yaml`
- MODIFIED: `tests/8601-1/fundamentals.yaml`
- MODIFIED: profile YAMLs

## Estimated size

~40 lines new YAML, ~10 lines modified.
