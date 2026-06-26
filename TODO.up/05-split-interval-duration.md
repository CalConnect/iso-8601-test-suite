# TODO.up/05 — Split bundled interval and duration reqs

**Status:** DONE
**Depends on:** TODO.up/04 (uses date-time split)
**Unblocks:** TODO.up/08 (tests update)
**Completed by:** `10db1c4 feat(reqs): split bundled requirements into atomic per-format requirements` and `18c3aaf feat: split extended-interval bundled reqs into implicit/explicit atomic`. Note: actual filenames are `time-interval.yaml` and `duration.yaml` (doc guessed `intervals.yaml`/`durations.yaml`); splits landed there.

## Problem

Two bundled reqs need splitting:

1. **`req:interval-abbreviated-end`** (Clause 5.5.1) — bundles all higher-order omission patterns into one statement. Standard enumerates at least 3 (year omitted, month omitted, day omitted).

2. **`req:dur-reduced`** (Clause 5.5.2.3) — bundles all zero-component omission into one. Each omitted component (Y, M, D, H, M, S) is its own atomic format.

3. **`req:dur-fraction`** (Clause 5.5.2.3) — currently says "lowest-order component" but doesn't distinguish dot vs comma decimal sign. Standard treats them as alternatives.

## Scope

### Interval abbreviated end — split into 3+ atomic

Replace `req:interval-abbreviated-end` with:
- `req:interval-abbreviated-end-year-omitted` — end date omits year, inherits from start (e.g., `2018-01-15/02-20`)
- `req:interval-abbreviated-end-month-omitted` — end date omits year+month
- `req:interval-abbreviated-end-day-omitted` — end date omits year+month+day (just time)
- `req:interval-abbreviation-ambiguity-rule` — the result must remain unambiguous

### Duration reduced — split into 6 (one per component)

Replace `req:dur-reduced` with:
- `req:dur-reduced-year-omitted`
- `req:dur-reduced-month-omitted`
- `req:dur-reduced-day-omitted`
- `req:dur-reduced-hour-omitted`
- `req:dur-reduced-minute-omitted`
- `req:dur-reduced-second-omitted`
- `req:dur-reduced-at-least-one-required` — at least one number+designator must remain

### Duration fraction — split by decimal sign

Replace `req:dur-fraction` with:
- `req:dur-fraction-period` — `.` decimal sign
- `req:dur-fraction-comma` — `,` decimal sign (alternative)
- `req:dur-fraction-leading-zero` — zero required before sign if value < 1

## Tests to re-map

`tests/8601-1/time-interval.yaml` (20 tests) and `tests/8601-1/duration.yaml` (25 tests):

- 9 composite tests for `req:dur-reduced` → split across 7 new dur-reduced-* reqs
- Tests for `req:dur-fraction` → split across 3 new reqs
- Tests for `req:interval-abbreviated-end` → split across 4 new reqs

## Profiles update

- `iso-8601-1-complete.yaml`, `iso-8601-2-complete.yaml`, plus any profile that includes these reqs.

## Acceptance

- `ruby scripts/validate` passes.
- All new reqs have ≥1 test.

## Files

- MODIFIED: `requirements/8601-1/time-interval.yaml`
- MODIFIED: `requirements/8601-1/duration.yaml`
- MODIFIED: `tests/8601-1/time-interval.yaml`
- MODIFIED: `tests/8601-1/duration.yaml`
- MODIFIED: profile YAMLs

## Estimated size

~70 lines new YAML, ~30 lines modified.
