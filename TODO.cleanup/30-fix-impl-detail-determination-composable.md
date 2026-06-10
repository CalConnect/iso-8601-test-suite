# TODO.cleanup/30-fix-impl-detail-determination-composable

**Status:** DONE

ImplementationDetailView computes `det` with inline logic that differs from the
shared `overallDetermination` composable in `useStats.js`.

Inline logic:
  full = every status === "pass"
  partial = some status === "pass"
  none = otherwise

Shared composable:
  full = every status === "pass"
  partial = some status === "pass" OR "partial"
  none = otherwise

The difference: if all statuses are "partial" (each requirement has mixed
pass/fail), the inline returns "none" while the composable correctly returns
"partial". ImplementationReportView already uses the shared composable.

## Fix applied

Replaced inline determination logic with `overallDetermination()` from
`useStats.js`, matching ImplementationReportView and ImplementationsView.
