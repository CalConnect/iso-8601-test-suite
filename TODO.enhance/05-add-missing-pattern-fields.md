**Status:** DONE


## Issue

Approximately 82 requirements (~32% of all 257 requirements) are missing a `pattern` field.
The `pattern` field provides a machine-readable syntax pattern (e.g., `YYYYMMDD`, `YYYY-MM-DD`)
that documents the expected expression format. Without it, the requirement's syntax constraint
is only available as free-text in the `statement` field.

## Scope

Audit all 257 requirements across:

- `requirements/8601-1/` (99 requirements in 9 files)
- `requirements/8601-2/` (158 requirements in 13 files)

For each requirement missing a `pattern` field:

1. Check if the requirement defines a syntactic format (many do)
2. If so, add the `pattern` field using the standard placeholder notation:
   - `YYYY` — 4-digit year
   - `MM` — 2-digit month
   - `DD` — 2-digit day
   - `DDD` — 3-digit day of year
   - `Www` — week number
   - `D` — day of week
   - `hh` — hour
   - `mm` — minute
   - `ss` — second
   - `±hhmm` — UTC offset
   - `P[n]Y[n]M[n]DT[n]H[n]M[n]S` — duration

3. If the requirement does not define a format (e.g., a semantic constraint), leave `pattern` absent

## RFC 5141 context

Requirements are committee-defined resources identified via RFC 5141 `techdefined`:

```
urn:iso:std:iso:8601:-1:ed-1:en:tech:tc154.wg5:req:cal-date-basic-full
urn:iso:std:iso:8601:-2:ed-1:en:tech:tc154.wg5:req:explicit-calendar-date-parsing
```

The `pattern` field supplements the RFC 5141 clause reference to provide a machine-readable
syntax specification at the requirement level.

## Example fix

Before:
```yaml
- id: req:cal-date-reduced-ymd
  clause: iso:8601:-1:ed-1:en:clause:5.2.2.2
  statement: >
    A calendar date may be represented with reduced precision as YYYY-MM.
```

After:
```yaml
- id: req:cal-date-reduced-ymd
  clause: iso:8601:-1:ed-1:en:clause:5.2.2.2
  statement: >
    A calendar date may be represented with reduced precision as YYYY-MM.
  pattern: "YYYY-MM"
```
