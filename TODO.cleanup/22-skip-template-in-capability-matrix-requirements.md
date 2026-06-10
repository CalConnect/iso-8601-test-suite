# TODO.cleanup/22-skip-template-in-capability-matrix-requirements

**Status:** DONE

`build_requirements_index` in `scripts/capability-matrix` scans `profiles/**/*.yaml` for
additional requirements without skipping `TEMPLATE.yaml`. While TEMPLATE currently has
no additional_requirements (so no data leaks), this is a latent bug — if someone adds
example requirements to the template, they'd appear in the matrix output.

## Fix applied

Added `next if File.basename(f) == "TEMPLATE.yaml"` in the profile requirements scan
loop of `build_requirements_index`, consistent with the same skip in `SuiteIndex`.
