# TODO.up/02 — Split bundled fundamentals reqs

**Status:** DONE
**Depends on:** nothing
**Unblocks:** TODO.up/08 (tests update)
**Completed by:** `10db1c4 feat(reqs): split bundled requirements into atomic per-format requirements` — all 5 atomic time-shift reqs present in `requirements/8601-1/fundamentals.yaml`

## Problem

`req:time-shift` in `requirements/8601-1/fundamentals.yaml` bundles 4 distinct formats from Clause 4.3.13 into one statement: basic hm, basic h, extended hm, and Z designator. The clause also mandates "+" sign non-omission — its own atomic rule.

Per the atomicity rule (each format/option = its own req), this must split into 5.

## Scope

Replace `req:time-shift` (lines 113–121 of `fundamentals.yaml`) with 5 atomic reqs:

```yaml
- id: req:time-shift-basic-hm
  clause: "urn:iso:std:iso:8601:-1:ed-1:en:clause:4.3.13:tech:time-shift-basic-hm"
  statement: >
    A time shift in basic format may be expressed as a sign, two-digit hour,
    and two-digit minute: [±][hh][mm].
  format: basic
  pattern: "[±][hh][mm]"

- id: req:time-shift-basic-h
  clause: "urn:iso:std:iso:8601:-1:ed-1:en:clause:4.3.13:tech:time-shift-basic-h"
  statement: >
    A time shift in basic format may omit the minutes when they are zero,
    expressing only the sign and two-digit hour: [±][hh].
  format: basic
  pattern: "[±][hh]"

- id: req:time-shift-extended-hm
  clause: "urn:iso:std:iso:8601:-1:ed-1:en:clause:4.3.13:tech:time-shift-extended-hm"
  statement: >
    A time shift in extended format uses a colon separator between hour and
    minute: [±][hh]:[mm].
  format: extended
  pattern: "[±][hh][\":\"][mm]"

- id: req:time-shift-utc
  clause: "urn:iso:std:iso:8601:-1:ed-1:en:clause:4.3.13:tech:time-shift-utc"
  statement: >
    The UTC designator ["Z"] indicates zero time shift from UTC.
  format: any
  pattern: "\"Z\""

- id: req:time-shift-sign-mandatory
  clause: "urn:iso:std:iso:8601:-1:ed-1:en:clause:4.3.13:tech:time-shift-sign-mandatory"
  statement: >
    The sign of a time shift shall be explicit; the plus sign shall not be
    omitted. A positive shift indicates ahead of UTC; a negative shift
    indicates behind UTC.
  format: any
```

## Tests to re-map

In `tests/8601-1/fundamentals.yaml`, the 5 tests currently under `req:time-shift` (valid-022 through valid-025, plus any others) split as:

- `fundamentals-valid-022` (input `Z`) → `req:time-shift-utc`
- `fundamentals-valid-023` (input `+01:00`) → `req:time-shift-extended-hm`
- `fundamentals-valid-024` (input `-05:00`) → `req:time-shift-extended-hm`
- `fundamentals-valid-025` (input `+0500`) → `req:time-shift-basic-hm`
- ADD: `fundamentals-valid-046` (input `+05`) → `req:time-shift-basic-h`
- ADD: `fundamentals-valid-047` (input `0100`, no sign) → `req:time-shift-sign-mandatory` (negative test)

## Profiles update

- `profiles/iso-8601-1-complete.yaml` fundamentals section: remove `req:time-shift`, add the 5 new IDs.
- `profiles/iso-8601-2-complete.yaml` same.
- `profiles/iso-8601-1-core.yaml` same (if it includes time-shift).
- Any other profile that references `req:time-shift`.

## Acceptance

- `ruby scripts/validate` passes.
- All 5 new reqs have at least one test.
- No remaining references to `req:time-shift` anywhere in the repo (`grep -r "req:time-shift" .` returns only the 5 new IDs).

## Out of scope

- Splitting other fundamentals reqs (`expansion`, `leading-zeros` are single-concept and stay).
- Adding brand-new fundamentals reqs (leap seconds, proleptic — see TODO.up/07).

## Files

- MODIFIED: `requirements/8601-1/fundamentals.yaml`
- MODIFIED: `tests/8601-1/fundamentals.yaml`
- MODIFIED: `profiles/iso-8601-1-complete.yaml`, `iso-8601-2-complete.yaml`, `iso-8601-1-core.yaml`

## Estimated size

~40 lines new YAML, ~15 lines modified.
