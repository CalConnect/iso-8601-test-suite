# TODO.cleanup/26-generate-ruby-date-40-result-file

**Status:** DONE

The capability-matrix includes ruby-date-40 as a library, but no result YAML file existed
for it. All download links (`/results/ruby-date-40.yaml`) would 404. Also, the adapter's
info method returned `"Ruby Date/DateTime/Time (4.0.5)"` which produced a malformed result
ID with trailing hyphen: `result:ruby-date-datetime-time-4-0-5-`.

## Fixes applied

1. Changed ruby-date-40 adapter name from `"Ruby Date/DateTime/Time (4.0.5)"` to
   `"Ruby 4.0 Date/DateTime/Time"` — clean result ID: `result:ruby-4-0-date-datetime-time`.
2. Generated `results/ruby-date-40.yaml` (191/733 pass).
3. Copied to `site/public/results/ruby-date-40.yaml`.
4. Regenerated `matrix.json` with correct adapter name.
