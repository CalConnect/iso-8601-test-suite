# TODO.cleanup/28-fix-capability-matrix-default-output-path-comment

**Status:** DONE

The capability-matrix script header comment said default output was `site/src/matrix.json`
(stale path from before the stale file was removed), but the actual default was
`site/public/matrix.json`.

## Fix applied

Updated header comment to match actual default: `site/public/matrix.json`.
