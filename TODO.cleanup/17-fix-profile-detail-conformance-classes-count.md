# TODO.cleanup/17-fix-profile-detail-conformance-classes-count

**Status:** DONE

ProfileDetailView's summary card shows "Conformance Classes: 0" for all profiles because
it reads `profile.conformance_classes` (now always `[]` since all profiles migrated to
`traceability`). Should show the traceability class count instead.

## Fix applied

Changed `ProfileDetailView.vue` summary card to use `profile.traceability?.length || 0`
and relabeled from "Conformance Classes" to "Traceability Classes" to match the data model.
