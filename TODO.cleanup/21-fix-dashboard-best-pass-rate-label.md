# TODO.cleanup/21-fix-dashboard-best-pass-rate-label

**Status:** DONE

Dashboard shows a large number labeled "Best Pass Rate" but displays a raw count of
passed capability groups (e.g. "191"), not a percentage. This is misleading — "rate"
implies a percentage.

## Fix applied

Changed the stat to show the best library's overall pass percentage instead of raw count.
Updated the computed property to derive the percentage from `libStats`, matching the
display format of the other percentage-based stats on the dashboard.
