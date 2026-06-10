# TODO.cleanup/11-fix-run-tests-output-profile-results

**Status:** DONE

`scripts/run-tests` was outputting profile additional test results under `conformance_class_results` with `profile:*` IDs. Fixed to use `profile_results` section per the schema.

## Fixes applied

1. **`scripts/run-tests` — `infer_class`** — Returns `[:conformance_class, id]` or `[:profile, id]` tuples instead of bare strings. Profile tests identified by checking `class_for_test` return value starting with `"profile:"`.

2. **`scripts/run-tests` — `write_results`** — Splits grouped results into `conformance_class_results` and `profile_results` based on the type tag. Uses string key names (`"conformance_class"` / `"profile"`) not symbols to ensure correct YAML serialization.

3. **`scripts/run-tests` — declaration check** — Updated to destructure `infer_class` tuple and only check declarations for `:conformance_class` type, not `:profile` type. Profile additional tests now run instead of being skipped as "not declared".

4. **`scripts/run-tests` — `HashUtil` integration** — Added `require_relative '../lib/hash_util'` and `HashUtil.symbolize_keys(result)` after handler execution. Fixes string-key vs symbol-key mismatch between exec adapter JSON responses and Ruby symbol-based access.

5. **`scripts/run-tests` — `$schema` header** — `write_results` now writes `# yaml-language-server: $schema=../schema/conformance-result.yaml` header to output files.

6. **`scripts/run-tests` — `list_available`** — Shows traceability class count instead of deprecated `conformance_classes` count.

7. **`lib/suite_index.rb` — `index_profiles`** — Skips `TEMPLATE.yaml` to avoid loading template test data.

8. **All result files regenerated** with correct format (profile_results section, $schema headers, no nil result fields).

## Result

- Ruby: 191 passed, 164 failed, 378 not-supported (profile tests now run!)
- Node: 125 passed, 520 failed, 88 not-supported
- Python: 178 passed, 490 failed, 65 not-supported
