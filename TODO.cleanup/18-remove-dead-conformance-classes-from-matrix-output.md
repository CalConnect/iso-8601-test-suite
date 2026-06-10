# TODO.cleanup/18-remove-dead-conformance-classes-from-matrix-output

**Status:** DONE

`scripts/capability-matrix` outputs a `conformance_classes: []` (empty array) for every
profile in matrix.json. Since all profiles use `traceability`, this legacy field is dead
data that no view reads meaningfully. The empty arrays waste bandwidth and confuse readers
of the raw JSON.

## Fix applied

In `build_profiles_index`, replaced `conformance_classes: data["conformance_classes"] || []`
with `traceability_class_count: (data["traceability"] || []).length` — a single integer.
Updated the matrix output key from `conformance_classes` to `traceability_class_count`.
Regenerated matrix.json.
