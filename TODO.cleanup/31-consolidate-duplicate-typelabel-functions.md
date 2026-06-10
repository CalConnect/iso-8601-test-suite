# TODO.cleanup/31-consolidate-duplicate-typelabel-functions

**Status:** DONE

`capTypeLabel` and `typeLabel` in `useFormat.js` have identical implementations.
`capTypeLabel` is used in MatrixView for capability column headers; `typeLabel`
is used in DetailModal for test type display. Both map the same capability/test
type keys to human-readable labels.

Having two identical functions is a DRY violation — adding a new test type
requires updating both.

## Fix applied

Made `typeLabel` the canonical function and had `capTypeLabel` delegate to it.
Added a comment noting the delegation.
