# TODO.up/07 — Split bundled Part 2 reqs

**Status:** DONE
**Depends on:** TODO.up/01 (symbols, since explicit-representation reqs reference designators)
**Unblocks:** TODO.up/08 (tests update)
**Completed by:** `10db1c4 feat(reqs): split bundled requirements into atomic per-format requirements` — 15 atomic req-class files now in `requirements/8601-2/`

## Problem

Multiple Part 2 reqs bundle distinct formats:

| Req | File | Clause | Issue |
|---|---|---|---|
| `req:explicit-time-shift` | explicit-representation.yaml | 7.4 | Bundles Z + offset + positive + reduced precision |
| `req:explicit-time-reduced-precision` | explicit-representation.yaml | 7.3.1 | Bundles hour-only + hour+minute |
| `req:explicit-beginning-of-day` | explicit-representation.yaml | 7.3.2 | Bundles T0H0M0S + T0S omitted-zeros |
| `req:explicit-decimal-fractions` | explicit-representation.yaml | 7.12 | Bundles hour + minute + second |
| `req:explicit-omission-zero` | explicit-representation.yaml | 7.10 | Bundles all per-component omission |
| `req:grouped-application-date` | grouped-time-scale-units.yaml | 5.4 | Bundles 5.4.1–5.4.4 |
| `req:extended-interval-open-end` (and 3 others) | extended-time-intervals.yaml | 10.2 | Each bundles implicit + explicit |
| `req:arithmetic-conversion-boundaries` | arithmetic.yaml | 14.6 | Bundles 10 boundary pairs |
| `req:arithmetic-canonical-form` | arithmetic.yaml | 14.7 | Bundles 3 variants |

## Scope

### Explicit time shift (7.4) — split into 4

Replace `req:explicit-time-shift` with:
- `req:explicit-time-shift-utc` — ["Z"] form
- `req:explicit-time-shift-offset` — ["-"][timeUnits] form
- `req:explicit-time-shift-positive` — ahead-of-UTC shift
- `req:explicit-time-shift-reduced-precision` — omit time units (7.4.4)

### Explicit time reduced precision (7.3.1) — split into 2

Replace `req:explicit-time-reduced-precision` with:
- `req:explicit-time-reduced-hour` — hour-only
- `req:explicit-time-reduced-minute` — hour+minute

### Explicit beginning of day (7.3.2) — split into 2

Replace `req:explicit-beginning-of-day` with:
- `req:explicit-bod-full` — T0H0M0S
- `req:explicit-bod-omitted-zeros` — T0S (zeros omitted per 7.10)

### Explicit decimal fractions (7.12) — split into 3

Replace `req:explicit-decimal-fractions` with:
- `req:explicit-fraction-hour`
- `req:explicit-fraction-minute`
- `req:explicit-fraction-second`

### Explicit omission zero (7.10) — split per component

Replace `req:explicit-omission-zero` with:
- `req:explicit-omission-zero-component` — a zero-valued component may be omitted with its designator
- `req:explicit-omission-zero-precision-preservation` — except when omission would alter precision indication

### Grouped application (5.4) — split per 5.4.1–5.4.4

Replace `req:grouped-application-date` with:
- `req:grouped-application-no-lower-order` — group precision only (5.4.1)
- `req:grouped-application-with-lower-order` — lower-order precision (5.4.2)
- `req:grouped-boundary-adherence-valid` — valid lower-order within group (5.4.3)
- `req:grouped-boundary-adherence-invalid` — invalid lower-order exceeding boundary (5.4.4 negative test)

### Extended interval open/unknown (10.2) — split each into implicit+explicit

For each of `req:extended-interval-open-end`, `-open-start`, `-unknown-end`, `-unknown-start`, split into:
- `req:extended-interval-{type}-implicit`
- `req:extended-interval-{type}-explicit`

= 8 new reqs replacing 4 bundled ones.

### Arithmetic conversion boundaries (14.6) — split into 10

Replace `req:arithmetic-conversion-boundaries` with:
- 6 unequivocally-convertible pairs (century/decade, decade/year, year/month, week/day, day/hour, hour/minute)
- 4 non-convertible pairs (year/week, year/day, month/day, minute/second)

### Arithmetic canonical form (14.7) — split into 3

Replace `req:arithmetic-canonical-form` with:
- `req:arithmetic-canonical-form-concrete-context`
- `req:arithmetic-canonical-form-context-dependent`
- `req:arithmetic-canonical-form-algorithm` — references Annex D

## Tests to re-map

`tests/8601-2/` files for: explicit-representation (57 tests), grouped-time-scale-units (25 tests), extended-time-intervals (24 tests), arithmetic (31 tests).

The 8 tests for `req:explicit-time-shift` re-map across 4 new reqs. The 10 tests for `req:grouped-application-date` re-map across 4 new reqs. Etc.

## Profiles update

- `iso-8601-2-complete.yaml` updates per file.

## Acceptance

- `ruby scripts/validate` passes.
- All new reqs have ≥1 test.
- No remaining refs to the bundled req IDs.

## Files

- MODIFIED: `requirements/8601-2/explicit-representation.yaml`
- MODIFIED: `requirements/8601-2/grouped-time-scale-units.yaml`
- MODIFIED: `requirements/8601-2/extended-time-intervals.yaml`
- MODIFIED: `requirements/8601-2/arithmetic.yaml`
- MODIFIED: corresponding `tests/8601-2/*.yaml` files
- MODIFIED: `profiles/iso-8601-2-complete.yaml`

## Estimated size

~150 lines new YAML, ~60 lines modified.
