# TODO.cleanup/16-add-round-trip-to-capability-mapping

**Status:** DONE

`TEST_TYPE_TO_CAPABILITY` in `scripts/capability-matrix` maps test types to capability
keys for the matrix JSON output. The `round_trip` type was added to `suite.yaml` and
the conformance-class schema but the mapping table was not updated. This caused round_trip
tests to use the raw type name "round_trip" as the capability key instead of a semantic
category.

## Fix applied

Added `"round_trip" => "parse_general"` to `TEST_TYPE_TO_CAPABILITY` in `scripts/capability-matrix`.
Round-trip tests (parse → extract → generate → compare) are fundamentally about parsing
correctness, same as validity and equivalence tests.
