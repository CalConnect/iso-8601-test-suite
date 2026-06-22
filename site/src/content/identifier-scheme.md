# Identifier scheme

This document defines how IDs are formed in the suite and how they resolve. The scheme has two layers: a CURIE-style local ID for entities defined *within this suite*, and RFC 5141 URNs for references *into the published ISO standard*.

## Local IDs (CURIE-style)

Every entity defined within the suite has an ID of the form `prefix:local-name`. The prefix identifies the entity type; the local name is a kebab-case slug.

### Prefixes

| Prefix | Entity
|---|---
| `suite:`       | The suite itself (e.g. `suite:iso-8601-test-suite`).
| `req-class:`   | A requirements class (e.g. `req-class:calendar-date`).
| `req:`         | A requirement (e.g. `req:cal-date-basic-full`).
| `conf-class:`  | A conformance class (e.g. `conf-class:calendar-date`).
| `conf-test:`   | A conformance test (e.g. `conf-test:cal-date-parse-001`).
| `profile:`     | A profile (e.g. `profile:rfc-3339`).
| `result:`      | A conformance result for one library (e.g. `result:ruby-date`).

### Cross-part references

Requirements in Part 1 referencing Part 2 (or vice versa) use the `8601-1:` or `8601-2:` prefix:

```yaml
dependencies:
  - 8601-1:conf-class:fundamentals
```

Within-part references omit the prefix:

```yaml
dependencies:
  - req-class:fundamentals
```

### Naming conventions

- **Requirements classes** (`req-class:`) use the feature name: `calendar-date`, `time-of-day`, `date-and-time`, `duration`, `time-interval`, `recurring`, `week-date`, `ordinal-date`, `expanded-rep`.
- **Requirements** (`req:`) use a short prefix matching the class, followed by the format and form: `cal-date-basic-full`, `cal-date-extended-full`, `cal-date-reduced-month-ext`.
- **Conformance tests** (`conf-test:`) follow `{prefix}-{type}-{NNN}`: `conf-test:cal-date-parse-001`, `conf-test:dur-gen-003`. The `type` token is one of `parse`, `gen`, `valid`, `equiv`, `arith`, `rt` (round-trip).

The validate script enforces these patterns. Run `ruby scripts/validate` after any ID change.

### ID normalization

The `SuiteIndex` module centralizes ID handling:

- `bare_id(id)` strips the prefix and returns just the local name.
- `resolve_class(id)` returns the conformance class for any test, requirement, or class ID. This is how the dashboard maps a test to its parent class without hardcoded prefix logic.

If you write code that needs to compare or map IDs, use these helpers rather than re-implementing string parsing.

## Clause URNs (RFC 5141)

References into ISO 8601 use RFC 5141 URNs. Each requirement carries a `clause:` field with the URN of the paragraph it codifies.

### Format

```
urn:iso:std:iso:8601:-{part}:ed-1:en:clause:{number}
```

Parts:

- `iso:std:iso:8601` — the ISO 8601 standard family.
- `-{part}` — `1` for Part 1, `2` for Part 2.
- `ed-1` — edition 1 (the 2026 edition).
- `en` — language (English).
- `clause:{number}` — the clause number from the standard, with sub-clauses separated by dots (e.g. `5.2.2.1`).

Examples:

```
urn:iso:std:iso:8601:-1:ed-1:en:clause:5.2.2.1       # calendar date, complete
urn:iso:std:iso:8601:-1:ed-1:en:clause:5.3.1.1       # time of day, basic
urn:iso:std:iso:8601:-2:ed-1:en:clause:6.2           # EDTF level 0
```

### Tech suffixes

Some requirements append a `:tech:{slug}` suffix to disambiguate multiple technical requirements derived from the same clause:

```
urn:iso:std:iso:8601:-1:ed-1:en:clause:5.2.2.1:tech:cal-date-basic-full
urn:iso:std:iso:8601:-1:ed-1:en:clause:5.2.2.1:tech:cal-date-extended-full
```

Both requirements cite the same clause but encode different format variants. The `:tech:` suffix is opaque to URN resolvers but meaningful within this suite.

### Resolving clause URNs

RFC 5141 URNs are not directly resolvable to URLs in the general case. To map a URN to the clause text:

1. Read the URN's clause number (`clause:5.2.2.1` → 5.2.2.1).
2. Open the corresponding published standard (ISO 8601-1:2026 or -2:2026).
3. Navigate to that clause.

The suite does not embed clause text because ISO 8601 is a copyrighted document. The URN is a precise pointer; the text lives in your copy of the standard.

### Finding requirements by clause

To find every requirement that targets a specific clause:

```bash
grep -rn "clause:5.2.2.1" requirements/
```

This works because the URN format is stable and the `clause:` field is on every requirement.

## Source URIs

Some entities also carry a `source:` field with one or more public URIs. This is used for profiles (linking to the RFC or W3C NOTE they codify) and requirements classes (linking to the standard's TOC).

```yaml
source:
  - https://www.rfc-editor.org/rfc/rfc3339.html
  - urn:iso:std:iso:8601:-1:ed-1:en:clause:5.2.2
```

The `source:` field is informational. It is not used for ID resolution.

## Common confusions

### "What's the difference between `req-class:` and `conf-class:`?"

They are paired: each requirements class (`req-class:`) has exactly one conformance class (`conf-class:`) with the same local name. The requirements class defines *what* must be true; the conformance class defines *how it is tested*. The 1:1 mapping is enforced by `SuiteIndex`.

### "Can I use a CURIE in a clause URN field?"

No. The `clause:` field always takes an RFC 5141 URN. CURIEs are for suite-internal entities only. Mixing the two will fail validation.

### "Why do some requirements have a clause but others don't?"

A requirement without a `clause:` field is a *suite-internal* requirement — typically a profile-specific `additional_requirement` that does not correspond to a clause in the published standard. These have `req:` IDs namespaced under the profile name (e.g. `req:rfc-3339-lowercase-tz`).

## Where to go next

- [The conformance model](/docs/conformance-model) — how IDs map to conformance classes and profiles.
- [For contributors](/docs/contributors) — conventions for naming new entities.
- [README: Identifier scheme](https://github.com/CalConnect/iso-8601-test-suite/blob/main/README.adoc#identifier-scheme) — the concise reference.
