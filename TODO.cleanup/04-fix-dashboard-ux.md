# TODO.cleanup/04-fix-dashboard-ux

**Status:** DONE

Dashboard UX issues fixed.

**Fixes applied:**
1. Profile cards: replaced raw ID (`profile:edtf-level-0`) with description snippet.
2. Profile progress bars: use `pctBarColor()` with threshold-based coloring (green ≥60%, amber ≥30%, red <30%).
3. Profile percentage text: also color-coded with thresholds.
4. Hero subtitle: now dynamic from library data (`heroSubtitle` computed property).
5. Removed target_profiles from library cards (all identical, not informative).
6. Reduced quick links to 2 (Matrix + Methodology), removed redundant Profile/Implementation links.
7. Library grid: 4 columns on lg to match 4 libraries.
