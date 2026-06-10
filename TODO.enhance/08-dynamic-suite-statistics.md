**Status:** DONE


## Issue

`suite.yaml` contains hardcoded statistics (requirement counts, test counts) that are not
verified by `scripts/validate`. If files are added, removed, or modified, these numbers can
drift out of sync with reality.

## Current state

From the validation output, the suite already tracks:
```
Requirements: actual=257 suite.yaml=257
Tests (base): actual=638 suite.yaml=638
Profile tests: actual=75 suite.yaml=75
Total tests: actual=713 suite.yaml=713
```

These counts match now, but there is no enforcement.

## Options

**Option A — Remove statistics from suite.yaml**:
- `suite.yaml` becomes purely structural (manifest, dependencies, conformance classes)
- Statistics are computed on demand by `scripts/validate` or `scripts/run-tests`
- Pros: no drift possible, single source of truth
- Cons: consumers can't get a quick count without running a script

**Option B — Add validation check**:
- Keep statistics in `suite.yaml`
- Add a validation phase in `scripts/validate` that counts actual requirements/tests and
  compares against the declared values
- Fail validation if counts don't match
- Pros: statistics remain available as metadata
- Cons: requires maintenance on every change

**Option C — Generate statistics automatically**:
- Remove manual statistics from `suite.yaml`
- Add a `scripts/stats` or extend `scripts/validate --stats` that computes and optionally
  writes statistics back to `suite.yaml`
- Pros: best of both worlds
- Cons: more complex automation

## RFC 5141 context

The suite manifest itself is a committee-defined resource:

```
urn:iso:std:iso:8601:-1:ed-1:en:tech:tc154.wg5:suite:iso-8601
```

Statistics within the manifest are metadata about the resource, not normative content.

## Recommended approach

Option B is the minimal viable fix — add a validation phase that warns when statistics are
stale. Option A is the cleanest long-term solution.
