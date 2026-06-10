# TODO.enhance/01 — Fix source clause mismatches between requirements/ and tests/

**Status:** DONE

All four pairs of requirements/test files previously had conflicting clause numbers.
Verified that all now match:

| Requirements file | Tests file | Source (both) |
|---|---|---|
| `requirements/8601-1/duration.yaml` | `tests/8601-1/duration.yaml` | `urn:iso:std:iso:8601:-1:ed-1:en:clause:5.5.2` |
| `requirements/8601-1/time-interval.yaml` | `tests/8601-1/time-interval.yaml` | `urn:iso:std:iso:8601:-1:ed-1:en:clause:5.5` |
| `requirements/8601-1/recurring-time-interval.yaml` | `tests/8601-1/recurring-time-interval.yaml` | `urn:iso:std:iso:8601:-1:ed-1:en:clause:5.6` |
| `requirements/8601-2/seasons.yaml` | `tests/8601-2/seasons.yaml` | `urn:iso:std:iso:8601:-2:ed-1:en:clause:4.8` |

Enforced by the `phase_source_consistency` validation phase in `scripts/validate`.
