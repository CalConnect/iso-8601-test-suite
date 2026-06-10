# 03 — Fix Requirement Detail for Profile-Specific Requirements

## Problem
Profile-specific requirements (e.g. `req:w3c-datetime-extended-format-only`) didn't appear
in the `reqs` array, so `activeReq` in App.vue returned null.

## Completed
- [x] Profile-specific reqs now in `reqs` array (auto-fixes `activeReq` lookup)
- [x] `relatedProfiles` now uses `req.profiles` back-reference (data-driven, no scanning)
- [x] `relatedRequirements` handles both base (clause grouping) and profile-specific (source_profile grouping)
- [x] "Profile-Specific" badge shown on profile-specific requirements
- [x] "Source Profile" section shown for profile-specific requirements
- [x] `/requirement/w3c-datetime-extended-format-only` now shows results with test data
