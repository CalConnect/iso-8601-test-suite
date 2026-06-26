# TODO.up/04 — Expand date-and-time reqs

**Status:** DONE
**Depends on:** TODO.up/03 (the new time-shift-utc and time-offset-* reqs)
**Unblocks:** TODO.up/05 (time-interval and duration use these)
**Completed by:** `10db1c4 feat(reqs): split bundled requirements into atomic per-format requirements` — `requirements/8601-1/date-and-time.yaml` now holds 31 atomic reqs

## Problem

ISO 8601-1:2026 Clause 5.4.2 mandates **24** complete date-and-time representations (3 date types × 4 shift variants × 2 formats). Current suite has **18** (missing the hours-only-shift variant — 6 reqs).

Additionally `req:date-time-reduced-precision` (5.4.3) bundles multiple date-type × precision × format combinations into one statement.

## Scope

### 5.4.2 — Add 6 missing shiftH (hours-only shift) variants

For each of calendar / ordinal / week date, basic AND extended:
- `req:date-time-cal-basic-shift-h` — [date]["T"][time][±][hh]
- `req:date-time-cal-extended-shift-h` — [dateX]["T"][timeX][±][hh]
- `req:date-time-ord-basic-shift-h` — [odate]["T"][time][±][hh]
- `req:date-time-ord-extended-shift-h` — [odateX]["T"][timeX][±][hh]
- `req:date-time-week-basic-shift-h` — [wdate]["T"][time][±][hh]
- `req:date-time-week-extended-shift-h` — [wdateX]["T"][timeX][±][hh]

### 5.4.3 — Split reduced precision into atomic variants

Replace `req:date-time-reduced-precision` with:
- `req:date-time-cal-basic-reduced-hm` — calendar date + T[hh][mm]
- `req:date-time-cal-extended-reduced-hm` — calendar dateX + T[hh]:[mm]
- `req:date-time-ord-basic-reduced-hm` — ordinal date + T[hh][mm]
- `req:date-time-ord-extended-reduced-hm` — ordinal dateX + T[hh]:[mm]
- `req:date-time-week-basic-reduced-hm` — week date + T[hh][mm]
- `req:date-time-week-extended-reduced-hm` — week dateX + T[hh]:[mm]
- `req:date-time-format-consistency` — expression shall be entirely basic OR entirely extended (negative test for mixed)

## Tests to re-map

`tests/8601-1/date-and-time.yaml` currently has 37 tests. Need to:

- Add 6 new tests for the new shift-h reqs (one positive parse each).
- Re-map tests for `req:date-time-reduced-precision` to the 6 split variants.
- Add 1 negative test for mixed format consistency.

## Profiles update

- `iso-8601-1-complete.yaml` date-and-time section: add 6 shift-h IDs, replace 1 reduced-precision with 7 split IDs.
- `iso-8601-2-complete.yaml` same.
- `iso-8601-1-core.yaml` likely unaffected (core doesn't include hours-only shift).

## Acceptance

- `ruby scripts/validate` passes.
- New shift-h reqs each have ≥1 test.
- Mixed-format negative test passes (e.g., `1985-04-12T2320.5` should be invalid).

## Files

- MODIFIED: `requirements/8601-1/date-and-time.yaml`
- MODIFIED: `tests/8601-1/date-and-time.yaml`
- MODIFIED: 2-3 profile YAMLs

## Estimated size

~80 lines new YAML, ~20 lines modified.
