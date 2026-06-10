# 01 — Data Model: Include Profile-Specific Requirements

## Problem
`scripts/capability-matrix` only scanned `requirements/**/*.yaml` (257 base reqs).
40 profile-specific requirements from `profiles/*.yaml` `additional_requirements` were missing.

## Completed
- [x] Extended `build_requirements_index` to scan `profiles/*.yaml` for `additional_requirements`
- [x] Added `source_profile` field to profile-specific requirements
- [x] Added `profiles` back-reference array to ALL requirements (297/297 have it)
- [x] Added `target_profiles` to library metadata (inferred from adapter_results)
- [x] Fixed `TestSuiteLoader.all_tests` to also check `additional_tests` in profile files
- [x] Changed default output path from `site/src/matrix.json` to `site/public/matrix.json`
- [x] Regenerated `site/public/matrix.json` with 297 requirements
- [x] Verified with `ruby scripts/validate` — all passed
