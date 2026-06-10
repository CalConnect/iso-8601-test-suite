# TODO.cleanup/02-fix-adapter-results-counting

**Status:** DONE

`adapter_results` in `scripts/capability-matrix` mixes units: `pass`/`partial`/`fail` count requirements, but `total` counts individual test instances. This makes `profilePct()` (pass/total) meaningless — e.g. 33/298 = 11% when the real requirement pass rate or test pass rate would be different.

**Fix:** Change `adapter_results` to use consistent units. Add both `test_pass`/`test_total` (test instance counts) and `req_pass`/`req_total` (requirement counts). Update `profilePct()` and `profileAdapterPct()` to use test instance counts for the percentage bar.

**Files:**
- `scripts/capability-matrix` — adapter_results computation
- `site/src/composables/useStats.js` — profilePct, profileAdapterPct
