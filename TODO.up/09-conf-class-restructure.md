# TODO.up/09 — Conformance class structural reorganization

**Status:** PENDING
**Depends on:** TODO.up/01 (symbols class), TODO.up/06 (missing fundamentals)
**Unblocks:** TODO.up/11 (profiles), TODO.up/12 (regenerate)

## Problem

Three structural mismatches between the current req-class taxonomy and the ISO 8601-2:2026 clause structure:

1. **`seasons` is a standalone class** but ISO 8601-2:2026 Clause 4.9 nests seasons inside "Sub-year groupings" alongside other forms. The current 7-req / 17-test class boundary does not match the standard's organization.

2. **`explicit-representation` bundles Clauses 7 AND pieces of 4.2**. Clause 7 is "Explicit representation of time-scale units" (K/O/J/C designators for time). Clause 4.2 introduces extended date forms (`X` substitution, J for year, etc.). They are conceptually distinct but currently share one class.

3. **Clause 11 (Explicit duration and extensions) has no class**. The 6+ reqs from Clause 11 (`PnYnMnDTnHnMnS` explicit form with designators) currently leak into `req-class:duration` (Part 1). They belong in their own Part 2 class.

## Scope

### A. Seasons placement

**Decision: keep `seasons` as its own class.**

Rationale: although the standard nests seasons under Clause 4.9, the test surface (17 tests, 7 reqs) and the clean separation from other Clause 4.9 forms (which are handled by `qualification` and `unspecified-digits`) make a standalone class the right granularity. Conformance declarations stay simple — an adapter either supports seasons or doesn't.

**Action: no change to the class.** Document the decision in a comment at the top of `requirements/8601-2/seasons.yaml`:

```yaml
# NOTE: ISO 8601-2:2026 Clause 4.9 nests seasons under "Sub-year groupings".
# Kept as a standalone class for conformance declaration simplicity —
# the other Clause 4.9 forms live in qualification/unspecified-digits.
```

### B. Split explicit-representation

Split `req-class:explicit-representation` into:

- `req-class:explicit-representation` (retained) — Clause 7 only. K/O/J/C designators for explicit time-scale unit notation. After removing the Clause 4.2 leaks, this class will have ~20 reqs / ~45 tests.
- `req-class:extended-date-forms` (NEW) — Clause 4.2. Houses the extended date forms that currently leak into explicit-representation:
  - `req:explicit-extended-year-extended` (X-substitution forms)
  - `req:explicit-extended-season`
  - etc. — enumerate from the current `explicit-representation.yaml` file

**Action:**
- Create `requirements/8601-2/extended-date-forms.yaml` and `tests/8601-2/extended-date-forms.yaml`.
- Move the Clause 4.2 reqs and their tests into the new files.
- Update `suite.yaml` to register the new class.

### C. New Clause 11 class

Create `req-class:explicit-duration-and-extensions` for ISO 8601-2:2026 Clause 11.

Initial req set (6 reqs, derived from Clause 11 enumeration):
- `req:explicit-duration-designator-required` — leading `P` mandatory
- `req:explicit-duration-date-time-divider` — `T` separates date and time components
- `req:explicit-duration-year-designator-Y`
- `req:explicit-duration-month-designator-M-date`
- `req:explicit-duration-day-designator-D`
- `req:explicit-duration-time-designators-H-M-S`

(initial seed — TODO.up/10 expands the full atomic set)

**Action:**
- Create `requirements/8601-2/explicit-duration-and-extensions.yaml`.
- Create `tests/8601-2/explicit-duration-and-extensions.yaml` (seed 6 tests).
- Register in `suite.yaml`.

### D. Update SuiteIndex file lists

After file moves and additions, update:
- `lib/test_suite/suite_index.rb` (if it hardcodes file lists — verify; per the design notes, file lists are data-driven, so likely no change needed).
- `suite.yaml` manifest.
- The `requirements/8601-2/` directory listing expected by the loader.

## Acceptance

- `ruby scripts/validate` passes.
- `seasons` class has a documenting comment.
- `explicit-representation` class contains only Clause 7 reqs.
- New `extended-date-forms` class contains only Clause 4.2 reqs.
- New `explicit-duration-and-extensions` class is registered and has ≥1 req + ≥1 test.

## Files

- NEW: `requirements/8601-2/extended-date-forms.yaml`
- NEW: `tests/8601-2/extended-date-forms.yaml`
- NEW: `requirements/8601-2/explicit-duration-and-extensions.yaml`
- NEW: `tests/8601-2/explicit-duration-and-extensions.yaml`
- MODIFIED: `requirements/8601-2/explicit-representation.yaml` (remove Clause 4.2 reqs)
- MODIFIED: `tests/8601-2/explicit-representation.yaml` (remove Clause 4.2 tests)
- MODIFIED: `requirements/8601-2/seasons.yaml` (add header comment)
- MODIFIED: `suite.yaml` (register new classes)

## Estimated size

~80 lines new YAML, ~40 lines moved (mechanical).
