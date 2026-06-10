**Status:** DONE


## Issue

`scripts/validate` currently performs 9 validation phases but does not check several
important consistency properties that the audit identified. The following checks are missing:

## Missing validation checks

### 10a. Source consistency check
Verify that corresponding requirements class and conformance class files reference the same
clause(s). Currently, `requirements/8601-1/duration.yaml` can say "Clause 5.5.2" while
`tests/8601-1/duration.yaml` says "Clause 5.5" without triggering a warning.

### 10b. Statistics accuracy check
Compare the counts in `suite.yaml` against actual file contents. The script already computes
these counts (as shown in validation output) but does not fail when they differ.

### 10c. Orphaned identifier check
Verify that every `req:` ID referenced in test files exists either in a requirements class
file or in a profile's `additional_requirements` section. Currently, profile-specific
requirements are orphaned.

### 10d. Component validity check
Validate that `expect.components` in test files use only known component keys and valid value
types. Requires the component vocabulary from TODO 04.

### 10e. Source URN format check (after TODO 03)
Validate that all `source` fields conform to RFC 5141 URN syntax.

### 10f. Pattern field coverage check (after TODO 05)
Report requirements that define a syntactic format (have a `statement` with format keywords)
but lack a `pattern` field.

### 10g. Test ID naming convention check (after TODO 06)
Validate that all test IDs follow the chosen naming convention.

## Implementation approach

Add these checks as new phases in `scripts/validate`. Each phase should:

1. Print a header (e.g., `=== 10. Source consistency ===`)
2. Check the relevant property across all files
3. Report mismatches with file paths and expected vs actual values
4. Increment error count for failures
5. Return non-zero exit code if any errors found

## RFC 5141 context

The validation script ensures conformance of the test suite data model itself. The checks
validate that RFC 5141 URN references are syntactically correct and semantically consistent:

```
urn:iso:std:iso:8601:-{part}:ed-1:en:clause:{number}  — clause references
urn:iso:std:iso:8601:-{part}:ed-1:en:tech:tc154.wg5:req:{name}  — requirement IDs
urn:iso:std:iso:8601:-{part}:ed-1:en:tech:tc154.wg5:conf-test:{name}  — test IDs
```

## Priority

Some checks depend on other TODOs being completed first:
- 10e depends on TODO 03 (source URN conversion)
- 10d depends on TODO 04 (component vocabulary)
- 10f depends on TODO 05 (pattern field audit)
- 10g depends on TODO 06 (naming convention decision)

Checks 10a, 10b, and 10c can be implemented immediately.
