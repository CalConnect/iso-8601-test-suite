# TODO.cleanup/06-fix-exec-adapter-options

**Status:** DONE

`python-datetime.py` and `node-datetime.js` exec adapters didn't handle `options` in `try_parse`.

## Fixes applied

1. **`adapters/python-datetime.py`** — `try_parse` now reads `params["options"]["parse_mode"]`:
   - `dedicated` (default): tries strptime first, then fromisoformat fallback
   - `undifferentiated`: skips strptime, goes straight to fromisoformat

2. **`adapters/node-datetime.js`** — `tryParse` now accepts options but JS Date.parse is inherently undifferentiated (no format-specific parser in stdlib). Added comment documenting this.

3. **`README.adoc`** — JSON protocol `try_parse` params updated to document `options` field.
