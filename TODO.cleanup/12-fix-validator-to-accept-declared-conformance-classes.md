# TODO.cleanup/12-fix-validator-to-accept-declared-conformance-classes

**Status:** DONE

## Fixes applied

1. **`schema/conformance-result.yaml`** — Added `declared_conformance_classes` field:
   ```yaml
   declared_conformance_classes:
     type: array
     items:
       type: string
       pattern: "^(8601-[12]:)?conf-class:[a-z0-9-]+$"
   ```

2. **`results/node-datetime.yaml`** — Regenerated with `$schema` header via run-tests.

3. **`results/python-datetime.yaml`** — Regenerated with `$schema` header via run-tests.

4. **`results/ruby-date.yaml`** — Regenerated with `$schema` header via run-tests.

5. **`profiles/TEMPLATE.yaml`** — Fixed `$schema` path from `profile.yaml` to `../schema/profile.yaml`.

6. **`scripts/validate` — `phase_profiles`** — Added `next if File.basename(f) == "TEMPLATE.yaml"` to skip template. Updated output to show "traceability classes" instead of deprecated "classes" count.
