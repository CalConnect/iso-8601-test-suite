# TODO.cleanup/09-add-profile-comparison-and-selection-guidance

**Status:** DONE (partial — selection guidance added; comparison feature deferred)

## Fixes applied

### Profile selection guidance on Profiles page

**`site/src/views/ProfilesView.vue`** — Added a 3-column guidance grid above the profile cards:

- **Web & Internet** — RFC 3339 (APIs, protocols), W3C Datetime (HTML metadata)
- **Libraries & Archives** — EDTF Level 0/1/2 (extended dates, uncertain/approximate, structured expressions)
- **Full Compliance** — Basic Format (compact storage), ISO 8601-1 Complete, ISO 8601-2 Complete

Each profile name is a clickable link that navigates to the profile detail page.

### Deferred: Profile comparison feature

Side-by-side comparison of two profiles (requirements overlap, unique requirements) is a larger feature
that should be addressed when specifically requested.
