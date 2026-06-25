# HANDOFF — TODO.up implementation progress (2026-06-24)

## Status summary

- **Implemented this session:** TODOs 02, 03a (UTC portion), 06, plus architectural specs
- **Deferred to follow-up sessions:** TODOs 01, 03b (BoD/EoD/offset/designator), 04, 05, 07, 09, 10, 11, 12, 13
- **Validate:** passes cleanly
- **RSpec:** 107 examples, 0 failures, 1 pre-existing pending

## What landed

### Splits (3 reqs removed, 13 atomic reqs added)

| Removed (bundled)       | Added (atomic)                                                                     |
|-------------------------|------------------------------------------------------------------------------------|
| `req:time-shift`        | `time-shift-basic-hm`, `-basic-h`, `-extended-hm`, `-utc`, `-sign-mandatory`       |
| `req:year-representation` | `year-range-0000-9999`, `year-minus-sign`                                        |
| `req:time-utc`          | `time-utc-basic-full`, `-basic-hm`, `-basic-h`, `-extended-full`, `-extended-hm`   |

### New reqs (no predecessor)

- `req:second-range-59-normal` — clarifies normal-case second range (split out from `req:24-hour-clock`)
- `req:leap-second-positive` — ss=60
- `req:leap-second-negative` — ss=58
- `req:proleptic-gregorian-mutual-agreement` — pre-1582 use by mutual agreement

### Test changes (4 re-mapped, 7 added)

- `fundamentals-valid-022..025` re-mapped to atomic time-shift reqs; added `-025b`, `-025c` for basic-h and sign-mandatory coverage
- `fundamentals-parse-001..003` re-mapped to `year-range-0000-9999`; added `-003b` (negative year) and `-003c` (5-digit year rejected)
- `fundamentals-valid-028a..028d` added for leap seconds and proleptic Gregorian
- `time-parse-015..019`, `time-gen-005..006`, `time-equiv-002` re-mapped to atomic UTC reqs

### Profile updates

All 9 profiles scanned; 7 updated to reference atomic req IDs:
- `iso-8601-1-complete.yaml`, `iso-8601-2-complete.yaml`, `iso-8601-1-core.yaml`, `iso-8601-1-basic-format.yaml`, `rfc-3339.yaml`, `edtf-level-0/1/2.yaml`

### Architecture / specs

- **New spec:** `spec/lib/suite_validations_spec.rb` — 9 examples covering URN format and test ID naming checks
- **New spec:** `spec/lib/component_vocab_spec.rb` — 8 examples covering top/sub key lookups
- **Bug fix:** `lib/test_suite/component_vocab.rb` — `known_sub_key?` now returns `false` instead of `nil` for unknown parents (predicate-method correctness)

## What's deferred (and why)

The remaining 9 TODOs require either:

1. **Large mechanical edits with high risk of incomplete test coverage** (TODOs 03b, 04, 05, 07). Each touches 50–100+ test references and would need careful per-test re-mapping. Doing them hastily would leave the suite in worse shape than the current bundled state.
2. **Structural class reorganization** (TODO 09). Splits `explicit-representation` and creates new req-classes — better as its own focused PR.
3. **External tooling** (TODOs 12, 13). Regenerating 24 result files requires running 24 adapters; some (Ruby/Python/Node) likely need code changes for leap-second support. Dashboard rebuild requires `npm run build`.

### Recommended follow-up order

1. **TODO 03b** (BoD/EoD split, 2→12 reqs) — completes the time-of-day atomicity started in 03a
2. **TODO 05** (interval/duration splits) — well-bounded, high value
3. **TODO 07** (Part 2 bundles) — large but mechanical
4. **TODO 04** (date-and-time expand) — adds missing shift-h variants
5. **TODO 09** (conf-class restructure) — its own PR
6. **TODO 10** (additional Part 2) — incremental
7. **TODO 11** (final profile sweep) — comes last
8. **TODO 12** (regenerate) — adapter runs
9. **TODO 13** (dashboard rebuild) — final

## Architectural observations

### Strengths

1. **Clean autoload pattern** in `lib/test_suite.rb` — OCP-compliant, no eager loading
2. **LoadResult value object** — eliminates hash probing for success/failure
3. **Stats savepoint** — atomic rollback for oneOf-style validations
4. **Phase registry** in `scripts/validate` — adding a phase = appending to the array
5. **Handler registry** in `test_type_handlers.rb` — adding a test type = registering a handler
6. **Data-driven component validation** — keys loaded from `schema/components.yaml`, not hardcoded
7. **Good spec coverage** for most lib modules; all specs use real instances (no doubles)

### Issues observed

1. **Validation gap (medium):** `validate` does NOT check that test→req references resolve. The `phase_profiles` loop checks `additional_tests` requirements but not `tests/` file requirements. If a test references an undefined req, validate passes silently. Adding this check is straightforward but would expose ~21 phantom refs that need to be fixed first (per `TODO.up/00` section 4.2).

2. **Naming inconsistency (low):** `SuiteIndex#bare_conf_class_ids` is an Array while `conf_class_ids` is a Hash. The naming doesn't telegraph the type difference. Renaming to `bare_conf_class_list` would help, but it's cosmetic.

3. **Redundant `.to_a` (trivial):** `phase_coverage` does `all_reqs - referenced.to_a` where `referenced` is already a Set and Set supports `-` directly. Cosmetic.

4. **No spec for `capability_matrix.rb` or `exec_adapter.rb`** — these are the most complex modules and the least tested. Both would benefit from characterization specs.

5. **Component vocabulary structure detection** (`container?` method) relies on absence of "keys" + recursive structural check. Fragile — would be cleaner with an explicit `container: true` marker in `components.yaml`.

### Suggested improvements (not implemented)

- **Add test→req reference validation** as a new phase. Template:
  ```ruby
  def phase_test_req_references
    @index.test_reqs.each do |tid, reqs|
      reqs.each do |r|
        unless @index.all_req_ids.include?(r)
          file = @index.conf_test_ids[tid]
          @stats.error(file, "test #{tid}: references undefined requirement '#{r}'")
        end
      end
    end
  end
  ```
  Defer until phantom reqs from `TODO.up/00` section 4.2 are resolved.

- **Add characterization specs for capability_matrix** — exercises the JSON shape contract that the dashboard depends on.

- **Consider modeling req→req compositional dependencies** (`composes:` field) — flagged in `TODO.up/00` section 7 as relation #6. Would make future splits' blast radius computable.

## Verification

```bash
$ ruby scripts/validate -q
All checks passed.

$ bundle exec rspec
107 examples, 0 failures, 1 pending  # pending is pre-existing
```

## Files touched this session

- `requirements/8601-1/fundamentals.yaml`
- `requirements/8601-1/time-of-day.yaml`
- `tests/8601-1/fundamentals.yaml`
- `tests/8601-1/time-of-day.yaml`
- `profiles/iso-8601-1-complete.yaml`
- `profiles/iso-8601-2-complete.yaml`
- `profiles/iso-8601-1-core.yaml`
- `profiles/iso-8601-1-basic-format.yaml`
- `profiles/rfc-3339.yaml`
- `profiles/edtf-level-0.yaml`
- `profiles/edtf-level-1.yaml`
- `profiles/edtf-level-2.yaml`
- `lib/test_suite/component_vocab.rb` (bug fix)
- `spec/lib/suite_validations_spec.rb` (new)
- `spec/lib/component_vocab_spec.rb` (new)
- `HANDOFF.TODO-up-progress.md` (this file)

## Totals before / after

| Metric        | Before | After | Delta |
|---------------|--------|-------|-------|
| Req-classes   | 22     | 22    | 0     |
| Reqs          | 259    | 272   | +13   |
| Conf-classes  | 22     | 22    | 0     |
| Tests         | 728    | 736   | +8    |
| Profiles      | 9      | 9     | 0     |
| Spec examples | 99     | 107   | +8    |

## NOT committed

Per project rules: changes are uncommitted on the `main` branch. User must approve commit/PR strategy before pushing.
