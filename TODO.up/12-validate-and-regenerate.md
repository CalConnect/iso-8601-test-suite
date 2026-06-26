# TODO.up/12 — Validate, regenerate results, regenerate site JSON

**Status:** DONE
**Depends on:** TODO.up/01 through 11 (all source changes must land first)
**Unblocks:** TODO.up/13 (dashboard rebuild)
**Completed by:** `a7e2500 chore: regenerate all adapter results and dashboard JSON` — `ruby scripts/validate` clean (92 files, 0 errors, 0 warnings); 25 result YAMLs present; `summary.json` + `detail.json` regenerated.

## Problem

After the requirements/tests/profiles restructuring, three artifacts must be regenerated and verified:

1. The validate script must pass — confirms schema-level correctness.
2. All 24 `results/*.yaml` files must be regenerated — adapters must re-run against the new test set. Some adapters will crash against new tests (e.g., leap-second `ss=60`); those need adapter updates.
3. The dashboard JSON (`summary.json`, `detail.json`) must be regenerated from the new results.

Per the **Regen Script False Success** rule (see memory): `regenerate-all-results` masks adapter crashes by swallowing non-zero exits. **Verify per-adapter mtime instead of trusting the script's exit line.**

## Scope

### Phase 1 — Validate

```bash
ruby scripts/validate
```

Expected: 0 errors, 0 warnings. If errors appear, fix at source — do NOT bypass with `--no-verify` or skip phases.

Common issues at this stage:
- "references undefined requirement" → test ref wasn't updated (TODO.up/08 work missed).
- "duplicate requirement ID" → two splits collided on naming.
- "cycle detected" → req-class dependency introduced a loop.

### Phase 2 — Per-adapter regeneration

For each of the 24 adapters, in dependency order:

```bash
ruby scripts/run-tests adapters/{name}.{ext} > results/{name}.yaml
```

Run per-adapter (NOT `regenerate-all-results`), so failures surface individually.

Verify each `results/{name}.yaml` mtime is more recent than the run-tests invocation:

```bash
ls -la results/*.yaml | awk '{print $6, $7, $8, $9}'
```

**Adapters likely to need source updates** before regeneration succeeds:
- `ruby-date.rb`, `ruby-date-40.rb` — leap second `ss=60` parse likely fails (Ruby `Time` rejects `:60`). Either accept the failure (record as fail) or extend adapter to special-case it.
- `python-datetime.py` — same issue with Python `datetime`.
- `node-datetime.js` — same issue with JS `Date`.
- `JavaDateTime.java` — same issue.
- `cpp-chrono.cpp`, `c-stdio.c`, `rust-chrono/` — verify they accept `ss=60`.

**Decision needed**: do adapters mark leap-second tests as `fail` (correct: the library genuinely doesn't support them), or do we add a `Qualification note` to the adapter saying "supports leap seconds via X mechanism"?

Per the **Adapter Purity Rule** (see memory): if the library genuinely doesn't support `ss=60`, the result is `fail`. Do NOT add a workaround in the adapter that fabricates support. The test result is the ground truth.

### Phase 3 — Capability matrix JSON regeneration

```bash
ruby scripts/capability-matrix
```

This regenerates `site/public/summary.json` (~274 KB) and `site/public/detail.json` (~1.6 MB).

Verify the new files contain:
- `family` field on every library entry (per the in-flight dashboard work — see plan `peaceful-jumping-gadget.md`).
- Updated req counts (should be ~340 reqs total, up from 259 — accounting for all splits + new reqs).
- Updated test counts (should be ~810 tests total, up from 728).

### Phase 4 — Spot checks

Confirm specific test outcomes are sensible post-regeneration:

| Spot check | Expected |
|---|---|
| `ruby-date.yaml` leap-second test | Likely `fail` (Ruby Date doesn't parse `:60`) |
| `python-datetime.yaml` proleptic-Gregorian test | Likely `pass` (Python datetime is proleptic by default) |
| `cpp-chrono.yaml` explicit-duration test | Likely `fail` (chrono has no ISO duration type) |
| All adapters — `symbols` class tests | Mostly `pass` (most parsers handle designators implicitly) |

## Acceptance

- `ruby scripts/validate` exits 0.
- All 24 `results/*.yaml` files have mtime within the regen window.
- `site/public/summary.json` and `site/public/detail.json` exist and contain expected req/test counts.
- `bundle exec rspec` passes (lib specs unchanged but verify nothing regressed).

## Files

- MODIFIED (regenerated): all 24 `results/*.yaml`
- MODIFIED (regenerated): `site/public/summary.json`
- MODIFIED (regenerated): `site/public/detail.json`
- POSSIBLY MODIFIED: 1–4 adapter source files if leap-second handling needs to be added (per adapter purity rule, only if the underlying library genuinely supports it)

## Estimated size

~24 regenerated YAML files, 2 regenerated JSON files. ≤100 lines of adapter source changes if needed.

## Risk

If adapter re-runs reveal 5+ unexpected failures, stop and triage before regenerating the dashboard. A spurious-failure run that ships to the dashboard will mislead readers about library conformance.
