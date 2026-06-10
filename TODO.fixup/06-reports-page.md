# 06 — Wire Reports Page

## Problem
ReportsView.vue existed but was unwired. File list was hardcoded.

## Completed
- [x] ReportsView imported in App.vue
- [x] `/reports` route detection added
- [x] "Reports" nav item added to top navigation
- [x] ReportsView rendered for `/reports` route
- [x] File paths now data-driven (uses `lib.id` to construct path)
- [x] Uses `libStats()` from shared composable
