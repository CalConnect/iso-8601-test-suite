**Status:** DONE


## Issue

All `source` fields across the test suite are free-text strings (e.g., `"ISO 8601-1:2026 Clause 5.2.2"`)
that are not machine-readable or linkable. The repository already uses RFC 5141 partial URNs for
individual requirement `clause` fields (e.g., `iso:8601:-1:ed-1:en:clause:5.2.2.1`), but the `source`
fields at the requirements class and conformance class level remain free-text.

## RFC 5141 reference

RFC 5141 defines the URN namespace `urn:iso:std:` for ISO documents. The relevant ABNF productions
(RFC 5141 §2.1–2.2):

```
ISO-NSS       = docidentifier [ docelement ] [ techdefined ] [ addition ]
docidentifier = orgidentifier ":" docnumber [ ":" correction ]
orgidentifier = "iso" [ ":" subpublisher ]
docelement    = ":" ( "clause" / "figure" / "table" / "term" ) ":" elementnumber
techdefined   = ":tech" *techelement
techelement   = ":" orgidentifier ":" identifier
```

## Current state

```yaml
# requirements/8601-1/calendar-date.yaml
source: ISO 8601-1:2026 Clause 5.2.2  # ← free-text, not machine-readable
```

## Target state

```yaml
# requirements/8601-1/calendar-date.yaml
source:
  - urn:iso:std:iso:8601:-1:ed-1:en:clause:5.2.2
```

For multi-clause sources:

```yaml
# requirements/8601-1/fundamentals.yaml
source:
  - urn:iso:std:iso:8601:-1:ed-1:en:clause:4
  - urn:iso:std:iso:8601:-1:ed-1:en:clause:5.1
```

## Scope

This change affects:

- 9 requirements class files in `requirements/8601-1/`
- 13 requirements class files in `requirements/8601-2/`
- 9 conformance class files in `tests/8601-1/`
- 13 conformance class files in `tests/8601-2/`
- 7 profile files in `profiles/`
- `suite.yaml` (if it has source references)

Total: ~52 `source` field conversions.

## Implementation steps

1. **Update YAML Schema** — change `source` field type from `string` to `array of strings` (URN values)
   in `schema/requirements-class.yaml`, `schema/conformance-class.yaml`, and `schema/profile.yaml`
2. **Convert each file** — replace free-text `source` with RFC 5141 URN array
3. **Keep human-readable description** — the `description` field already serves this purpose;
   `source` becomes purely machine-readable
4. **Update `scripts/validate`** — add a validation phase that checks `source` URNs conform to
   the RFC 5141 ABNF and resolve to valid clause numbers
5. **Update README.adoc** — document that `source` fields use RFC 5141 URNs

## URN examples

| Standard | Clause | RFC 5141 URN |
|---|---|---|
| ISO 8601-1 | 5.2.2 | `urn:iso:std:iso:8601:-1:ed-1:en:clause:5.2.2` |
| ISO 8601-1 | 5.3 | `urn:iso:std:iso:8601:-1:ed-1:en:clause:5.3` |
| ISO 8601-2 | 7 | `urn:iso:std:iso:8601:-2:ed-1:en:clause:7` |
| ISO 8601-2 | 4.4.1 | `urn:iso:std:iso:8601:-2:ed-1:en:clause:4.4.1` |
