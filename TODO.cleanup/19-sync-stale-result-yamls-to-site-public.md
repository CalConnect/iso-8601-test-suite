# TODO.cleanup/19-sync-stale-result-yamls-to-site-public

**Status:** DONE

`site/public/results/` contained stale YAML files from May 27 (before the profile_results
schema changes, before $schema headers). The regenerated results in `results/` from May 31
have the correct structure but were never copied to the site's public directory.

Download YAML links in ImplementationDetailView and ReportsView point to `/results/{id}.yaml`
which is served from `site/public/results/`.

## Fixes applied

1. Copied updated `results/node-datetime.yaml`, `results/python-datetime.yaml`,
   `results/ruby-date.yaml` to `site/public/results/`.
2. Removed `site/public/results/TEMPLATE.yaml` — users downloading a template file
   from the reports page is confusing. TEMPLATE.yaml belongs in `results/` only.
