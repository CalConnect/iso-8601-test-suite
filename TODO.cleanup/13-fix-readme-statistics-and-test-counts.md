# TODO.cleanup/13-fix-readme-statistics-and-test-counts

**Status:** DONE

## Fixes applied

1. **Statistics section** — Updated from stale hardcoded numbers to actual counts:
   - Part 1: 99 requirements, 275 tests (unchanged)
   - Part 2: 158 requirements, 363 tests (unchanged)
   - Added: 51 additional requirements across 8 profiles
   - Added: 308 total requirements
   - Profile tests: 75 → 95
   - Total tests: 713 → 733

2. **Usage examples** — Removed specific per-profile test counts (they change) and updated total from 713 to 733.

3. **Profile description** — Updated from "conformance classes + additional tests" to "traceability requirements + additional tests" to reflect the new model.

4. **Directory structure** — Updated "7 files" → "8 + TEMPLATE" for profiles.

## Verified counts (from `ruby scripts/validate`)

```
308 requirements (257 in classes + 51 in profiles)
733 conformance tests (275 Part 1 + 363 Part 2 + 95 profile)
22 requirements classes
8 profiles
```
