# TODO.cleanup/03-fix-dashboard-stats

**Status:** DONE

Dashboard stats row and library cards had several issues.

**Fixes applied:**
1. "Test Cases" now shows unique test count (not sum across libraries). Computed via `uniqueTestCount` using Set of test_ids.
2. "Passed" replaced with "Best Pass Rate" — shows best library's capability group pass count.
3. Library card progress bars use `pctBarColor()` (green/amber/red thresholds) matching text color.
4. `libStats` called once per library via `libStatsMap` computed property (was 6× per card).
5. Library grid changed to 4 columns to match 4 libraries.
