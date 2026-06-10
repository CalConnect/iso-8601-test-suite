# 04 — Dashboard: Profile-Scoped Stats

## Problem
Dashboard showed aggregate pass/fail across ALL requirements, misleading because
libraries target specific profiles.

## Completed
- [x] Library cards now show "Target Profiles" section with badge pills
- [x] Hero stats now show "X base + Y profile-specific" under Requirements
- [x] Pass rate still shown aggregate but with target_profiles context
- [x] Uses `libStats()` from shared composable (no inline computation)
