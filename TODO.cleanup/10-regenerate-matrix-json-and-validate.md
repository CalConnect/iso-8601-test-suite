# TODO.cleanup/10-regenerate-matrix-json-and-validate

**Status:** DONE

## Verification

1. `ruby scripts/validate` — **ALL PASSED.** Zero errors, zero warnings, 64 files checked, all 15 phases pass.
2. `ruby scripts/capability-matrix -o site/public/matrix.json` — regenerated (308 requirements × 4 libraries × 8 profiles).
3. `cd site && npx vite build` — builds successfully (30 modules, 715ms).
4. All result files regenerated with correct format (profile_results, $schema headers, no nil fields).

## Changes from validation baseline

- Before: 6 errors (profile IDs in conformance_class_results), 3 warnings (missing $schema)
- After: **0 errors, 0 warnings, ALL PASSED**
