# TODO.up/01 — Add `req-class:symbols` (Clause 3.2)

**Status:** PENDING
**Depends on:** nothing
**Unblocks:** TODO.up/03, TODO.up/04 (time-shift split uses designator reqs)

## Problem

ISO 8601-1:2026 Clause 3.2 defines ~20 atomic symbol requirements that the test suite does not model at all. The earlier "char-set shouldn't be its own conf class" decision was correct at the time (the bundled `req:character-set` was wrong), but the underlying standard actually mandates many atomic symbol reqs.

Currently every parser test implicitly relies on these symbols being valid, but no test specifically verifies e.g. "the `T` designator is recognized" or "the `,` decimal sign is accepted as alternative to `.`".

## Scope

Create `requirements/8601-1/symbols.yaml` with `id: req-class:symbols`, source clause 3.2, with the following atomic reqs:

### Designator symbols (3.2.5) — 10 reqs
- `req:designator-H` — hours designator
- `req:designator-M` — months/minutes designator (dual-role)
- `req:designator-P` — duration designator
- `req:designator-R` — recurring interval designator
- `req:designator-S` — seconds designator
- `req:designator-T` — time designator
- `req:designator-W` — week designator
- `req:designator-Y` — years designator
- `req:designator-Z` — UTC designator

(Combined M-for-both stays as 1 req since the standard uses one symbol.)

### Separator symbols (3.2.6) — 6 reqs
- `req:separator-hyphen` — `-` extended-format separator
- `req:separator-colon` — `:` extended-format separator
- `req:separator-solidus` — `/` interval/recurring separator
- `req:separator-double-hyphen` — `--` mutual-agreement alt to solidus
- `req:separator-decimal-period` — `.` decimal sign
- `req:separator-decimal-comma` — `,` decimal sign

### Character rules (3.2.1) — 4 reqs
- `req:char-repertoire` — character repertoire restricted to ISO/IEC 646
- `req:char-no-space` — space character forbidden in expressions
- `req:char-hyphen-minus-unification` — hyphen and minus mapped to hyphen-minus
- `req:char-bracket-omission` — brackets/quotation marks omitted in implementation

## Conformance class wiring

- Add new `conf-class:symbols` in `tests/8601-1/symbols.yaml` with `requirements_class: req-class:symbols`.
- Add positive tests (each designator/separator recognized in a real expression).
- Add negative tests (space rejected, non-ASCII rejected, etc.).
- No `dependencies:` — this is a leaf class, parallel to `fundamentals`.

## Acceptance

- `ruby scripts/validate` passes with new files.
- All 20 new reqs have at least one test.
- `iso-8601-1-complete` profile gains `req-class:symbols` in its traceability.

## Out of scope

- Updating other classes' reqs to depend on these new symbol reqs (that's future work).
- Adding symbols to other profiles (only `-complete`).

## Files

- NEW: `requirements/8601-1/symbols.yaml`
- NEW: `tests/8601-1/symbols.yaml`
- MODIFIED: `profiles/iso-8601-1-complete.yaml` (add `conf-class:symbols` to traceability)
- MODIFIED: `profiles/iso-8601-2-complete.yaml` (same)

## Estimated size

~120 lines new YAML, ~5 lines modified YAML.
