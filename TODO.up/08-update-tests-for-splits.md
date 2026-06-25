# TODO.up/08 — Update all test references for req splits

**Status:** PENDING
**Depends on:** TODO.up/02, 03, 04, 05, 06, 07 (all req splits must land first)
**Unblocks:** TODO.up/11 (profiles), TODO.up/12 (regenerate)

## Problem

`ruby scripts/validate` enforces test→req referential integrity. When a bundled req splits into N atomic reqs, every test that referenced the old ID must be remapped to one of the new atomic IDs — otherwise validate fails with `references undefined requirement` across all 24 result YAMLs.

This TODO consolidates the test-side work from TODOs 02–07 into one workstream because **all splits must land and all test re-maps must land together** in a single reviewable PR. Doing them piecemeal leaves the suite in a broken intermediate state.

## Scope

For each split below: in the named test file, change every `requirements:` block that pointed at the old ID to point at the appropriate new atomic ID.

### From TODO.up/02 (fundamentals time-shift)

File: `tests/8601-1/fundamentals.yaml`

- 5 tests currently referencing `req:time-shift` → re-map to:
  - basic hm form → `req:time-shift-basic-hm`
  - basic h form → `req:time-shift-basic-h`
  - extended hm form → `req:time-shift-extended-hm`
  - UTC form → `req:time-shift-utc`
  - negative-sign-required → `req:time-shift-sign-mandatory`

### From TODO.up/03 (time-of-day)

File: `tests/8601-1/time-of-day.yaml`

- 7 tests for `req:time-beginning-of-day` → split across 6 new `time-bod-*` IDs by format variant.
- 7 tests for `req:time-ending-of-day` → split across 6 new `time-eod-*` IDs.
- 8 tests for `req:time-utc` → split across 5 new `time-utc-*` IDs.
- Tests for `req:time-offset-basic` → split across `time-offset-basic-hm`, `-h`.
- 7 tests for `req:time-offset-extended` → split across 4 new `time-offset-*` IDs.
- Tests for `req:time-designator-omission` → split across 3 new IDs.

### From TODO.up/04 (date-and-time)

File: `tests/8601-1/date-and-time.yaml`

- Tests for `req:date-time-reduced-precision` → split across 6 new `date-time-{cal,ord,week}-{basic,extended}-reduced-hm` IDs.
- Add 6 new tests for the new `date-time-*-shift-h` reqs (one positive parse each).
- Add 1 negative test for `req:date-time-format-consistency` (e.g., `1985-04-12T2320.5` is invalid: mixed basic/extended).

### From TODO.up/05 (interval and duration)

Files: `tests/8601-1/time-interval.yaml`, `tests/8601-1/duration.yaml`

- Tests for `req:interval-abbreviated-end` → split across 4 new IDs based on what's omitted (year/month/day/ambiguity).
- 9 tests for `req:dur-reduced` → split across 7 new `dur-reduced-*-omitted` IDs (per component) + 1 "at-least-one-required" negative.
- Tests for `req:dur-fraction` → split across 3 new IDs (`-period`, `-comma`, `-leading-zero`).

### From TODO.up/06 (missing fundamentals reqs)

File: `tests/8601-1/fundamentals.yaml`

- Add `fundamentals-valid-046` — `2016-12-31T23:59:60` → valid (positive leap second, 2016 had one).
- Add `fundamentals-valid-048` — `1500-01-01` → valid under proleptic rule (mutual agreement).
- Add `fundamentals-valid-049` — `-0001` → valid (year -1).
- Add `fundamentals-valid-050` — `10000` → invalid (out of 4-digit range, requires expansion).
- Tests currently under `req:year-representation` re-map to `req:year-range-0000-9999` or `req:year-minus-sign`.

### From TODO.up/07 (Part 2 bundles)

Files: `tests/8601-2/explicit-representation.yaml`, `grouped-time-scale-units.yaml`, `extended-time-intervals.yaml`, `arithmetic.yaml`

- 8 tests for `req:explicit-time-shift` → split across 4 new IDs.
- Tests for `req:explicit-time-reduced-precision` → split across 2 new IDs.
- Tests for `req:explicit-beginning-of-day` → split across 2 new IDs.
- Tests for `req:explicit-decimal-fractions` → split across 3 new IDs.
- 7 tests for `req:explicit-omission-zero` → split across 2 new IDs.
- 10 tests for `req:grouped-application-date` → split across 4 new IDs per 5.4.1–5.4.4.
- Tests for each of 4 `req:extended-interval-{open,unknown}-{start,end}` → split into implicit+explicit = 8 new IDs.
- Tests for `req:arithmetic-conversion-boundaries` → split across 10 new IDs.
- Tests for `req:arithmetic-canonical-form` → split across 3 new IDs.

## Composite test handling

46 tests reference ≥2 reqs. Per the atomicity rule, **none of these should remain composite after this restructuring** unless they are *true equivalence* tests (basic ↔ extended variants of the same atomic concept). For equivalence tests:

- Keep them as single tests, but update their `requirements:` list to reference the 2 atomic variants being equivalence-checked (e.g., `req:cal-date-basic-full` + `req:cal-date-extended-full`).
- Add a `purpose: equivalence` field so the test type handler can distinguish them from semantic-bundle tests.

For non-equivalence composite tests (the 14 `dur-parse-005`-style "reduced+designator" tests): split into 2 atomic tests, each referencing one of the split reqs.

## Acceptance

- `ruby scripts/validate` passes with no `references undefined requirement` errors.
- Every new atomic req from TODOs 02–07 has ≥1 test.
- All 24 `results/*.yaml` files validate against the updated tests/ files.
- Composite test count drops from 46 to ≤10 (only true equivalence tests remain).

## Files

- MODIFIED: `tests/8601-1/fundamentals.yaml`
- MODIFIED: `tests/8601-1/time-of-day.yaml`
- MODIFIED: `tests/8601-1/date-and-time.yaml`
- MODIFIED: `tests/8601-1/time-interval.yaml`
- MODIFIED: `tests/8601-1/duration.yaml`
- MODIFIED: `tests/8601-2/explicit-representation.yaml`
- MODIFIED: `tests/8601-2/grouped-time-scale-units.yaml`
- MODIFIED: `tests/8601-2/extended-time-intervals.yaml`
- MODIFIED: `tests/8601-2/arithmetic.yaml`

## Estimated size

~150 lines modified, ~30 lines new test cases added.
