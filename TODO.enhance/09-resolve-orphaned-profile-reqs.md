**Status:** DONE


## Issue

Profile files define `additional_requirements` with `req:` IDs that do not exist in any
requirements class file under `requirements/`. These are orphaned identifiers — they are
referenced by conformance tests within the profile but have no corresponding requirement
definition in the requirements hierarchy.

## Affected profiles and orphaned IDs

### `profiles/rfc-3339.yaml`
- `req:rfc-3339-extended-format-only` — referenced by tests but not defined in `requirements/`
- `req:rfc-3339-t-uppercase` — referenced by tests but not defined in `requirements/`
- `req:rfc-3339-offset-required` — referenced by tests but not defined in `requirements/`
- `req:rfc-3339-no-hour-24` — referenced by tests but not defined in `requirements/`

### `profiles/w3c-datetime.yaml`
- Similar pattern of profile-specific requirements defined inline

### `profiles/edtf-level-0.yaml`, `edtf-level-1.yaml`, `edtf-level-2.yaml`
- EDTF-specific requirements defined inline in profile files

## RFC 5141 context

These requirements are committee-defined resources under the `techdefined` production:

```
urn:iso:std:iso:8601:-1:ed-1:en:tech:tc154.wg5:req:rfc-3339-extended-format-only
```

However, RFC 5141 requires that each identifier be resolvable to a definition. Currently
these IDs are only defined inline within profile YAML, not in the canonical `requirements/`
directory structure.

## Resolution options

**Option A — Create standalone requirements files for profiles**:
- Add `requirements/profiles/rfc-3339.yaml` with the additional requirement definitions
- Update profile files to reference these instead of defining inline
- Pros: consistent structure, all requirements are discoverable
- Cons: new directory level

**Option B — Accept inline requirements as valid**:
- Document that profile `additional_requirements` are self-contained definitions
- Update `scripts/validate` to recognize profile-defined requirements as valid targets
- Pros: no structural change, profiles remain self-contained
- Cons: two different locations for requirement definitions

**Option C — Hybrid approach**:
- Profile `additional_requirements` contains both the ID and the full definition
- Validate script checks that all referenced `req:` IDs exist either in `requirements/`
  or in a profile's `additional_requirements`
- Pros: best validation coverage with minimal structural change

## Recommended approach

Option C — update the schema to require `statement` and `clause` fields in
`additional_requirements` entries (so they are complete requirement definitions),
and update `scripts/validate` to index them alongside requirements from `requirements/`.
