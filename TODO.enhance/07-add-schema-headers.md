**Status:** DONE


## Issue

Four of the five YAML Schema files in `schema/` lack the `# yaml-language-server: $schema=...`
header that enables editor-based validation. The schema files validate other YAML files, but
they themselves are not validated.

## Affected files

| File | Has `$schema` header |
|---|---|
| `schema/suite.yaml` | Missing |
| `schema/requirements-class.yaml` | Missing |
| `schema/conformance-class.yaml` | Missing |
| `schema/conformance-result.yaml` | Missing |
| `schema/profile.yaml` | Missing |

## Context

All data files in the repository already include this header:

```yaml
# yaml-language-server: $schema=../../schema/requirements-class.yaml
```

The schema files themselves are YAML Schema definitions. Since YAML Schema is defined
in YAML, the schema files are self-describing — a schema file can reference itself or
a meta-schema.

## Fix

1. Determine if a YAML Schema meta-schema exists (or if the schema files are self-validating)
2. If a meta-schema exists, add `# yaml-language-server: $schema=meta-schema.yaml` to each file
3. If not, add a comment header noting that these are YAML Schema definition files
4. Ensure `scripts/validate` handles schema files correctly (either validates them or skips them
   with a documented reason)
