# TODO.cleanup/32-update-result-template-fields

**Status:** DONE

`results/TEMPLATE.yaml` was missing `declared_conformance_classes` and
`profile_results` fields that `run-tests` generates in its output. The template
serves as documentation for manual result creation and should demonstrate all
available schema fields.

## Fix applied

Added `declared_conformance_classes` and `profile_results` sections to the
template, matching the conformance-result.yaml schema. Kept existing
`profiles_tested` field as a simpler alternative.
