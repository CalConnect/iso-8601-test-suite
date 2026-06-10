# TODO.cleanup/25-fix-implementation-detail-determination-values

**Status:** DONE

ImplementationDetailView computed `det` as `"pass"` / `"partial"` / `"fail"` / `"not-applicable"`,
but the `detClass()` and `detLabel()` functions from `useStatus.js` expect `"full"` / `"partial"` /
`"none"`. This caused fully compliant profiles to display "Not Implemented" badges in the
implementation detail page.

## Fix applied

Changed determination values in ImplementationDetailView to use `"full"` / `"partial"` / `"none"`,
consistent with the shared composable functions used by ImplementationReportView and
ImplementationsView.
