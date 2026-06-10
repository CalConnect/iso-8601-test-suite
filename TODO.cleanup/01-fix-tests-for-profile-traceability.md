# TODO.cleanup/01-fix-tests-for-profile-traceability

**Status:** DONE

`tests_for_profile()` in `lib/test_suite_loader.rb` only read `conformance_classes`, ignoring `traceability`. All profiles migrated to `traceability` only, so profile detail pages showed 0 conformance classes and `adapter_results` were incomplete.

**Fix:** Updated `tests_for_profile` to prefer `traceability` (with per-requirement filtering), fall back to `conformance_classes` for legacy profiles. Regenerated `matrix.json`.
