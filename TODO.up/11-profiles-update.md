# TODO.up/11 — Update profiles for new req-classes and req splits

**Status:** DONE
**Depends on:** TODO.up/01 through 10 (all req/class changes must land first)
**Unblocks:** TODO.up/12 (regenerate)
**Completed by:** `ee723cc feat: add req-class:symbols for ISO 8601-1 Clause 3.2` (wired `conf-class:symbols` into `iso-8601-1-complete` + `iso-8601-2-complete`) and follow-up regen commits. `conf-class:extended-date-forms` and `conf-class:explicit-duration-and-extensions` are wired into `iso-8601-2-complete`.

## Problem

Profiles reference conformance classes by ID. After TODOs 01–10:
- New class `req-class:symbols` exists but no profile includes it.
- New class `req-class:extended-date-forms` exists but no profile includes it.
- New class `req-class:explicit-duration-and-extensions` exists but no profile includes it.
- The `*-complete` profiles must include all new classes to remain authoritative "complete" declarations.

## Scope

### `profile:iso-8601-1-complete.yaml`

- Add `conf-class:symbols` to the traceability list (TODO.up/01).
- No other changes (Part 1 split work doesn't create new classes; just splits reqs within existing classes).

### `profile:iso-8601-2-complete.yaml`

- Add `conf-class:extended-date-forms` (TODO.up/09).
- Add `conf-class:explicit-duration-and-extensions` (TODO.up/09 + 10).
- No req-level changes needed at the profile level — profiles reference classes, not individual reqs. Class-level splits propagate automatically.

### `profile:iso-8601-1-basic-format.yaml`

- Verify all `additional_requirements:` entries still reference valid req IDs after the splits in TODOs 02–05.
- Profile-specific reqs like `req:basic-format-compact-calendar` should be unaffected, but verify each `req:` reference resolves.

### `profile:iso-8601-1-core.yaml`

- Likely unaffected (core profile doesn't include hours-only-shift or reduced-precision variants that split).
- Verify traceability after split.

### `profile:rfc-3339.yaml`

- RFC 3339 references specific atomic reqs (e.g., `req:rfc-3339-*` declared in profile's `additional_requirements:`).
- Verify no Part 1 req ID that RFC 3339 references has been split. If so, re-point at the new atomic ID.

### `profile:w3c-datetime.yaml`

- Same pattern as RFC 3339 — verify additional_requirements still resolve.

### `profile:edtf-level-0.yaml`, `-1.yaml`, `-2.yaml`

- EDTF profiles declare many profile-specific reqs in `additional_requirements:`. Verify each still resolves.
- Particular attention: EDTF Level 1 references qualification markers and season codes that may have moved during TODO.up/09.

## Verification commands

```bash
# Confirm every profile's references resolve
ruby scripts/validate

# Confirm profile membership counts are sensible
ruby -e '
  Dir.glob("profiles/*.yaml").each do |f|
    y = YAML.load_file(f)
    next unless y["profile"]
    classes = y.dig("profile", "profile_specification", "conformance_classes") || []
    puts "#{y["profile"]["id"]}: #{classes.length} classes"
  end
'
```

Expected: iso-8601-1-complete jumps from 9 → 10 classes (adds symbols). iso-8601-2-complete jumps from 22 → 24 classes (adds extended-date-forms and explicit-duration-and-extensions).

## Acceptance

- `ruby scripts/validate` passes.
- All 9 profiles have resolvable traceability references.
- New classes appear in the appropriate `-complete` profiles.
- Profile membership counts are stable for the subset profiles (basic-format, core, rfc-3339, w3c-datetime, edtf-*).

## Files

- MODIFIED: `profiles/iso-8601-1-complete.yaml`
- MODIFIED: `profiles/iso-8601-2-complete.yaml`
- MODIFIED (verify only): `profiles/iso-8601-1-basic-format.yaml`
- MODIFIED (verify only): `profiles/iso-8601-1-core.yaml`
- MODIFIED (verify only): `profiles/rfc-3339.yaml`
- MODIFIED (verify only): `profiles/w3c-datetime.yaml`
- MODIFIED (verify only): `profiles/edtf-level-0.yaml`
- MODIFIED (verify only): `profiles/edtf-level-1.yaml`
- MODIFIED (verify only): `profiles/edtf-level-2.yaml`

## Estimated size

~10 lines new (two -complete profiles), ≤5 lines modified if any profile-specific req references need re-pointing.
