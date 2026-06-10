# TODO.cleanup/24-fix-capTypeLabel-round-trip

**Status:** DONE

`capTypeLabel` and `typeLabel` in `site/src/composables/useFormat.js` didn't handle
the `round_trip` test type — they would fall through to the raw string "round_trip"
instead of a human-readable label.

## Fix applied

Added `"round_trip" → "Round Trip"` mapping to both `capTypeLabel` and `typeLabel`.
Also made `typeLabel` explicit (was using ternary chains that returned undefined for
unknown types).
