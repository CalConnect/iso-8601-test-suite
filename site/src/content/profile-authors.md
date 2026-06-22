# For profile authors

**Audience:** you're writing or maintaining a profile that subsets ISO 8601 — RFC 3339, W3C NOTE-datetime, EDTF Level 0/1/2, FHIR, XFS, ODRL, or your own internal format. You want to know:

1. How do I formalize my subset as an ISO 8601 Profile in this suite?
2. Is my subset implementable by mainstream libraries?
3. How is profile-level conformance computed?

This document assumes you understand the basics from [the conformance model](/docs/conformance-model).

## What is an ISO 8601 Profile?

In everyday speech, a "profile" is a subset of a standard. In the ModSpec terminology this suite uses, a **Profile** is a formal artifact that selects:

1. A set of conformance classes from one or more standards (here: ISO 8601-1:2026 and ISO 8601-2:2026).
2. A specific subset of requirements within those classes (the *traceability*).
3. Optionally, additional requirements unique to the profile (e.g. RFC 3339's rule that lowercase `t`/`z` are permitted even though ISO 8601-1 mandates uppercase).

A profile is itself a unit of conformance: a library "conforms to RFC 3339" if it passes all the requirements RFC 3339 selects *plus* the additional requirements RFC 3339 adds.

## Profiles already defined

The suite ships eight profiles in `profiles/`:

| Profile ID | Description | Source | Profile-specific reqs
|---|---|---|---
| `profile:iso-8601-1-complete`  | All ISO 8601-1:2026 requirements (9 classes) | ISO 8601-1 | —
| `profile:iso-8601-1-core`      | ISO 8601-1 core subset                       | ISO 8601-1 | —
| `profile:iso-8601-1-basic-format` | Basic-format representations only         | ISO 8601-1 | —
| `profile:iso-8601-2-complete`  | All ISO 8601-1 + ISO 8601-2 requirements (22 classes) | ISO 8601-1 + -2 | —
| `profile:rfc-3339`             | RFC 3339 (Internet date/time format)         | RFC 3339 | 9
| `profile:w3c-datetime`         | W3C Date and Time Formats (NOTE-datetime)    | W3C | 13
| `profile:edtf-level-0`         | EDTF Level 0 (LOC)                           | ISO 8601-2 Annex A | 10
| `profile:edtf-level-1`         | EDTF Level 1 (uncertain, approximate, unspecified) | ISO 8601-2 Annex A | 19
| `profile:edtf-level-2`         | EDTF Level 2 (structured date/time expressions) | ISO 8601-2 Annex A | 24

Read any of these files for a worked example. `rfc-3339.yaml` is the cleanest reference because RFC 3339 has tight, unambiguous rules.

## Authoring a profile

### Step 1: Copy the template

```
cp profiles/TEMPLATE.yaml profiles/<your-name>.yaml
```

Set the header fields:

```yaml
id: profile:<your-name>
name: <Human-readable name>
description: >-
  <One-paragraph description. This is shown on the dashboard.>
source:
  - https://example.org/your-spec       # public URL or RFC 5141 URN
standardization_target_type: iso-8601-date-time-processor
```

### Step 2: Define traceability

Traceability is the heart of a profile. It says: "from each conformance class, which specific requirement IDs does this profile select?"

```yaml
traceability:
  - conformance_class: 8601-1:conf-class:calendar-date
    requirements:
      - req:cal-date-extended-full
      - req:cal-date-reduced-month-ext
      - req:cal-date-reduced-year

  - conformance_class: 8601-1:conf-class:time-of-day
    requirements:
      - req:time-extended-full
      - req:time-utc
      - req:time-offset-extended

  - conformance_class: 8601-1:conf-class:date-and-time
    requirements:
      - req:date-time-cal-extended-utc
      - req:date-time-cal-extended-offset
```

Cross-part references use the `8601-1:` / `8601-2:` prefix. Within-part references omit the prefix.

**How to find requirement IDs**: read the corresponding `requirements/8601-1/*.yaml` or `requirements/8601-2/*.yaml` file. Each requirements class lists its requirements with `req:` IDs.

If you omit `requirements:` for a class, the profile selects *all* requirements of that class — useful for "complete" profiles but rare for narrow profiles.

### Step 3: Add profile-specific requirements (optional)

Most real-world profiles have rules that go beyond selecting a subset. Examples from existing profiles:

- RFC 3339 disallows hour 24, requires UTC offset, allows lowercase `t`/`z`.
- W3C Datetime restricts to four decimal places in fractional seconds.
- EDTF Level 1 adds uncertain (`1985?`), approximate (`1985~`), and unspecified (`1985-XX`) markers.

Add these under `additional_requirements`:

```yaml
additional_requirements:
  - id: req:<your-name>-extended-format-only
    statement: >-
      Only extended format representations shall be used. Basic format
      representations are not permitted.
  - id: req:<your-name>-utc-offset-required
    statement: >-
      Every date-time representation shall include either "Z" or a numeric
      UTC offset.
```

Each additional requirement gets a `req:` ID namespaced under your profile name.

### Step 4: Add profile-specific tests (optional)

If your additional requirements are testable, add conformance tests under a matching conformance class block in the profile YAML:

```yaml
additional_tests:
  - id: conf-test:<your-name>-001
    description: "Rejects basic format"
    test_type: validity
    requirements:
      - req:<your-name>-extended-format-only
    given:
      expression: "19850412"
    expect:
      result: invalid
```

The test type can be `parsing`, `generation`, `validity`, `equivalence`, `arithmetic`, or `round_trip`. See [test types](/docs/test-types) for the semantics.

### Step 5: Validate

```
ruby scripts/validate
```

This catches: missing requirement IDs, broken traceability references, malformed test definitions, schema violations.

### Step 6: Run against an adapter

```
ruby scripts/run-tests --profile <your-name>
ruby scripts/run-tests --profile <your-name> --adapter ruby-date
```

This runs every test selected by the profile plus every additional test.

## How profile conformance is computed

This is the algorithm the dashboard uses to assign full / partial / none to each library for each profile. Understand it before publishing your profile.

1. **Build the requirement set**: every requirement ID selected by the profile's traceability, plus every additional requirement the profile adds.
2. **For each conformance class the profile selects**:
   1. For each library, run every test in that class that targets a selected requirement.
   2. Determine the per-library status for the class: `pass` (all tests pass), `fail` (all tests fail), `not-supported` (library declared but returned not-supported for all), `partial` (mixed).
3. **Aggregate per library across the profile**:
   1. `full`: every selected class passes.
   2. `partial`: at least one class passes or is partial, none solely failing that weren't already not-supported.
   3. `none`: no class passes.
4. **Profile-specific requirements**: tested as their own virtual class, included in the aggregate.

The result file's `profiles_tested` field on each library result determines which profiles the library claims to target. Untargeted profiles are still computed for informational purposes but don't count toward the library's declared conformance.

## Interoperability report

Once your profile is defined and run against the corpus, read the `/profile/<your-name>` page on the dashboard. It shows:

- Per-library determination (full / partial / none).
- Per-conformance-class breakdown.
- Per-requirement pass/fail status across every library.

The key signal for profile authors is *requirements that no library passes*. If three or more independent implementations all fail the same requirement, the most likely explanations are:

1. **The requirement is correct but the standard's wording is ambiguous.** File feedback with the standards body.
2. **The requirement is correct and the standard is clear, but libraries are buggy.** This is a call to action for library maintainers; link to your profile's results in their issue tracker.
3. **The requirement is wrong or your profile is over-specified.** Reconsider.

Patterns observed across the existing profiles:

- **Basic format requirements** fail in most libraries — most stdlibs only handle extended format.
- **24-hour-clock** (`24:00:00`) fails in Node.js, Rust, Java.
- **Week date basic** fails almost everywhere.
- **EDTF-specific requirements** (uncertain, approximate, unspecified markers) fail in every stdlib in the suite — EDTF requires a dedicated library.

If your profile relies on any of these features, expect low interoperability today. Document this for your users.

## Best practices

1. **Be explicit in traceability.** Selecting entire classes via "no requirements key" is convenient but couples your profile to future additions to that class. Listing specific requirement IDs is more future-proof.
2. **Test every additional requirement.** An untested additional requirement is just a wish. Add at least one `additional_tests` entry per additional requirement.
3. **Document rationale.** Use the profile's `description` field to explain *why* your profile restricts what it does. This helps implementers and downstream profile authors.
4. **Version your profile.** If your profile is published outside this suite, track its version separately from the suite's version. Bump the version when you add or relax requirements.

## Where to go next

- [The conformance model](/docs/conformance-model) — declared vs. not-declared semantics, end-to-end.
- [For standards authors](/docs/standards-authors) — if you also have a feedback loop with the standards body.
- [README: Creating a new profile](https://github.com/CalConnect/iso-8601-test-suite/blob/main/README.adoc#creating-a-new-profile) — CLI reference and additional examples.
- Existing profile YAMLs: `profiles/rfc-3339.yaml` (tightest), `profiles/w3c-datetime.yaml`, `profiles/edtf-level-*.yaml`.
