# Browser checks (Playwright)

Not part of `node --test "Artifacts/salmon-rivers/test/*.test.js"`: these drive the page in Chromium, so they are named `*.pw.js` and need Playwright, which the repo does not install. Use a global install and point Node at it:

```bash
NODE_PATH=$(npm root -g) node Artifacts/salmon-rivers/test/browser/spawn.pw.js    # Spawning mode, tab bar, the four pages over HTTP
NODE_PATH=$(npm root -g) node Artifacts/salmon-rivers/test/browser/river.pw.js    # tappable rivers, My location, label clipping, missing-file fallback
NODE_PATH=$(npm root -g) node Artifacts/salmon-rivers/test/browser/labels.pw.js   # label clipping alone
NODE_PATH=$(npm root -g) node Artifacts/salmon-rivers/test/browser/perf.pw.js     # pan frame cost with and without the river tap paths (prints numbers, no verdict)
```

Each prints `ok` / `FAIL` per check and exits 1 on any failure; take the exit status from the command, not through a pipe.

`build-site.js` lays the app out the way the artifact is published (Map `index.html` wrapped in a publisher-style skeleton, its scripts beside it, and `year/`, `spots/`, `counts/` from `scripts/build_app_tabs.py`) in `site/`. `site/`, `shots/` (screenshots) and `nofiles/` are rebuilt on every run and gitignored. Run `scripts/build_app_tabs.py` first if a tab source changed.
