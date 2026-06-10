# 07 — Full Audit Checklist

## Data Integrity
- [x] matrix.json has 297 requirements (257 base + 40 profile-specific) ✓
- [x] All profile-specific reqs have `source_profile` field ✓
- [x] All profile-specific reqs have `profiles` back-reference ✓
- [x] All base reqs have `profiles` back-reference ✓
- [x] All libraries have `target_profiles` array ✓
- [x] `ruby scripts/validate` passes ✓

## Navigation Integrity
- [x] 6 nav items: Dashboard, Matrix, Profiles, Requirements, Implementations, Reports
- [x] All library cards → `/implementation/:id`
- [x] All requirement IDs → `/requirement/:id` (including profile-specific)
- [x] All profile cards → `/profile/:id`
- [x] Breadcrumbs on all detail pages
- [x] Back navigation via breadcrumbs

## Code Quality (DRY, OCP, Model-Driven)
- [x] 3 shared composables (useStatus, useFormat, useStats)
- [x] Zero duplicated status/format/stats functions across views
- [x] All data from matrix.json — no hardcoded data in Vue components
- [x] ReportsView file paths data-driven from `lib.id`
- [x] Business logic in computed properties, not templates
- [x] Consistent component prop interfaces

## Files Changed
- `scripts/capability-matrix` — data model (profiles back-ref, target_profiles, profile reqs)
- `lib/test_suite_loader.rb` — fixed all_tests to include profile additional_tests
- `site/src/composables/useStatus.js` — created
- `site/src/composables/useFormat.js` — created
- `site/src/composables/useStats.js` — created
- `site/src/App.vue` — Reports route, profiles prop to MatrixView
- `site/src/views/DashboardView.vue` — profile-scoped stats, target_profiles display
- `site/src/views/MatrixView.vue` — profile filter, PROFILE badges
- `site/src/views/RequirementsView.vue` — PROFILE badges on cards
- `site/src/views/RequirementDetailView.vue` — profile-specific req support
- `site/src/views/ImplementationsView.vue` — shared composable usage
- `site/src/views/ImplementationDetailView.vue` — shared composable usage
- `site/src/views/ProfilesView.vue` — shared composable usage
- `site/src/views/ProfileDetailView.vue` — shared composable usage
- `site/src/views/ReportsView.vue` — data-driven, shared composable usage
- `site/src/components/DetailModal.vue` — shared composable usage
