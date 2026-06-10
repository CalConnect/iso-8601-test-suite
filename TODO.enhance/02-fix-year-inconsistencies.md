**Status:** DONE


## Issue

Five profile files reference "2019" in their `source` fields, while all other files in the
repository consistently reference "2026" (the correct edition year for ISO 8601-1:2026 and
ISO 8601-2:2026).

## Affected files

| File | Current `source` | Expected |
|---|---|---|
| `profiles/edtf-level-0.yaml` | References 2019 | Should reference 2026 |
| `profiles/edtf-level-1.yaml` | References 2019 | Should reference 2026 |
| `profiles/edtf-level-2.yaml` | References 2019 | Should reference 2026 |
| `profiles/rfc-3339.yaml` | References 2019 | Should reference 2026 |
| `profiles/w3c-datetime.yaml` | References 2019 | Should reference 2026 |

## RFC 5141 URN context

RFC 5141 §2.1 defines the edition identifier (`ed-1`) in the URN namespace. The year
referenced in free-text `source` fields should match the edition year of the standard:

```
urn:iso:std:iso:8601:-1:ed-1:en  →  ISO 8601-1:2026 (first edition, published 2026)
urn:iso:std:iso:8601:-2:ed-1:en  →  ISO 8601-2:2026 (first edition, published 2026)
```

## Fix

1. Open each of the 5 profile files
2. Change any occurrence of "2019" to "2026" in `source` fields
3. Verify no other files reference the wrong year
