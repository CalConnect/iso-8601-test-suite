# 02 — Shared Composables: Extract DRY Utility Functions

## Problem
`statusColor()`, `statusBg()`, `statusIcon()`, `trunc()`, `fmtTag()`, `capTypeLabel()`,
`pctBarColor()`, `pctColor()`, `libStats()` were copy-pasted across 5+ views.

## Completed
- [x] Created `site/src/composables/useStatus.js` — statusColor, statusBg, statusIcon, detClass, detLabel
- [x] Created `site/src/composables/useFormat.js` — trunc, fmtTag, capTypeLabel, typeLabel, clauseUrl, formatValue, libShortName
- [x] Created `site/src/composables/useStats.js` — libStats, reqStats, reqStatsBreakdown, profilePct, profileAdapterPct, pctColor, pctBarColor, profileBarColor, overallDetermination
- [x] Refactored all 8 views + 2 components to import from composables
- [x] Zero function duplication remaining across views
