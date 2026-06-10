# TODO.cleanup/15-fix-edition-year-in-site-views

**Status:** DONE

RequirementsView and RequirementsPartView display "ISO 8601-1:2019" and "ISO 8601-2:2019"
but the suite.yaml says edition 1 (2026). All other files (README, AboutView, suite.yaml)
correctly use :2026.

## Fixes applied

1. `site/src/views/RequirementsView.vue` — Changed title strings from ":2019" to ":2026".
2. `site/src/views/RequirementsPartView.vue` — Changed SECTION_META title strings from ":2019" to ":2026".
