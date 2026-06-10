# 05 — Matrix: Profile Filter & Profile-Specific Badges

## Problem
MatrixView had no profile filter. Profile-specific requirements had no visual indicator.

## Completed
- [x] `profiles` prop passed to MatrixView from App.vue
- [x] Profile filter row with clickable buttons (blue accent, with profile logos)
- [x] Filtering uses `req.profiles` back-reference and `req.source_profile`
- [x] "PROFILE" badge shown on profile-specific requirements in the matrix
- [x] "Profile-Specific (X)" categories appear in category filter
