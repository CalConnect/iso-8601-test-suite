# TODO.cleanup/05-fix-schema-consistency

**Status:** DONE

Schema and documentation files are inconsistent after recent feature additions (round_trip, parse_mode, traceability).

## Fixes applied

1. **`suite.yaml`** — Added `round_trip` to `test_types` with description.

2. **`schema/profile.yaml`** — Added `round_trip` to `additional_tests.items.test_type` enum. Added `parse_mode` field to additional test items.

3. **`README.adoc`** — Multiple updates:
   - Added `round_trip` row to test types table
   - Added "Parsing modes" subsection documenting `parse_mode` (dedicated vs undifferentiated)
   - Updated `try_parse(expression)` → `try_parse(expression, options = {})` in adapter interface table
   - Updated JSON protocol `try_parse` params to document `options` field with `parse_mode`
   - Updated profiles table (added iso-8601-1-basic-format, replaced "Conformance classes" with "Description", added traceability explanation)
   - Updated statistics to say "8 profiles"
   - Added "Creating a new profile" section with step-by-step guide
   - Added reference to node-datetime.js adapter
