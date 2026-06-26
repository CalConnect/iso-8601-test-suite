# TODO.up/03 — Split and expand time-of-day reqs

**Status:** DONE
**Depends on:** TODO.up/02 (time-shift split is prerequisite — UTC-of-day and local+shift reqs reference the time-shift IDs)
**Unblocks:** TODO.up/04 (date-and-time expansion uses these)
**Completed by:** `10db1c4 feat(reqs): split bundled requirements into atomic per-format requirements` — `requirements/8601-1/time-of-day.yaml` now holds 35 atomic reqs

## Problem

ISO 8601-1:2026 Clause 5.3 enumerates far more atomic representations than the current 17 reqs cover. Three clusters are bundled or missing:

1. **5.3.3 Beginning/ending of day** — 2 reqs cover what should be 12. Standard mandates basic/extended × beginning/ending × full/reduced × special-rules.
2. **5.3.4 UTC of day** — bundled into `req:time-utc`. Standard mandates 5 (basic full, basic hm, basic h, extended full, extended hm).
3. **5.3.5.2 Local time + shift** — 2 reqs cover what should be 4 (basic+basic-hm, basic+basic-h, extended+extended-hm, extended+basic-h).
4. **5.3.6 Time designator omission** — 1 req bundles 3 distinct rules.

## Scope

### 5.3.3 Beginning/ending of day — split into 12 atomic reqs

Replace `req:time-beginning-of-day` and `req:time-ending-of-day` with:

```
req:time-bod-basic-full              T000000
req:time-bod-extended-full           00:00:00 OR T00:00:00
req:time-bod-basic-reduced-hm        T0000
req:time-bod-extended-reduced-hm     00:00 OR T00:00
req:time-bod-basic-reduced-h         T00
req:time-bod-extended-reduced-h      00 OR T00
req:time-eod-basic-full              T240000
req:time-eod-extended-full           24:00:00 OR T24:00:00
req:time-eod-basic-reduced-hm        T2400
req:time-eod-extended-reduced-hm     24:00 OR T24:00
req:time-eod-basic-reduced-h         T24
req:time-eod-extended-reduced-h      24 OR T24
```

Additional rule-based reqs (separate from the format reqs above):
- `req:time-24-only-valid-eod` — hour 24 valid only in ending-of-day context (negative test: T240000 invalid as a clock time, valid as ending of day)
- `req:time-eod-implies-next-day-start` — semantic rule for arithmetic interpretation

### 5.3.4 UTC of day — split into 5

Replace `req:time-utc` with:
- `req:time-utc-basic-full` — T[hh][mm][ss]Z
- `req:time-utc-basic-hm` — T[hh][mm]Z
- `req:time-utc-basic-h` — T[hh]Z
- `req:time-utc-extended-full` — [hh]:[mm]:[ss]Z
- `req:time-utc-extended-hm` — [hh]:[mm]Z

### 5.3.5.2 Local time + shift — split into 4

Replace `req:time-offset-basic` and `req:time-offset-extended` with:
- `req:time-offset-basic-hm` — [time][shift] (both basic, full hm)
- `req:time-offset-basic-h` — [time][shiftH] (basic time, hours-only shift)
- `req:time-offset-extended-hm` — [timeX][shiftX] (both extended, full hm)
- `req:time-offset-extended-basic-h` — [timeX][shiftH] (extended time, basic hours-only shift)

### 5.3.6 Time designator omission — split into 3

Replace `req:time-designator-omission` with:
- `req:time-designator-omittable-when-unambiguous` — T may be omitted in time-only / UTC / shift expressions when unambiguous
- `req:time-designator-required-to-disambiguate` — T required when ambiguity (1920 vs T1920)
- `req:time-designator-not-needed-in-extended` — T not required in extended formats

## Tests to re-map

`tests/8601-1/time-of-day.yaml` currently has 54 tests against the 17 existing reqs. Re-map:

- 7 tests for `req:time-ending-of-day` → split across 6 new `time-eod-*` reqs
- 8 tests for `req:time-utc` → split across 5 new `time-utc-*` reqs
- 7 tests for `req:time-offset-extended` → split across 4 new `time-offset-*` reqs
- Tests for `req:time-designator-omission` → split across 3 new reqs

Add new tests for the gaps (basic/extended reduced variants for BoD/EoD that aren't currently covered).

## Profiles update

- `iso-8601-1-complete.yaml` time-of-day section: remove 4 bundled IDs, add 24 new IDs.
- `iso-8601-2-complete.yaml` same.
- `iso-8601-1-core.yaml` same.
- `iso-8601-1-basic-format.yaml` likely needs updates too.

## Acceptance

- `ruby scripts/validate` passes.
- All new reqs have ≥1 test.
- No remaining refs to `req:time-utc`, `req:time-beginning-of-day`, `req:time-ending-of-day`, `req:time-offset-basic`, `req:time-offset-extended`, `req:time-designator-omission`.

## Files

- MODIFIED: `requirements/8601-1/time-of-day.yaml`
- MODIFIED: `tests/8601-1/time-of-day.yaml`
- MODIFIED: 4 profile YAMLs

## Estimated size

~150 lines new YAML, ~50 lines modified.
