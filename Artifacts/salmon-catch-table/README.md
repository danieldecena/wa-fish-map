# SW Washington Creel Table

A mirror of `~/database/salmon-rivers/salmon.db`: WDFW's weekly Southwest Washington
Columbia River and tributary fishery reports (2019 to date), parsed into one row per
river, week and species. Counts only; nothing here feeds the rivers page.

- Terminal table: header `table` button (registry row `salmon` in `~/bin/data-tables.tsv`,
  config `visidata/salmon.visidatarc`).
- Published page: the URL in `artifact.json`. It is a snapshot of the database.

## Refreshing: manual only, nothing is scheduled

A weekly job was considered and declined (2026-10-18). To refresh:

```bash
/opt/homebrew/bin/python3 scripts/build_salmon_db.py --fetch   # new PDFs -> salmon.db
/opt/homebrew/bin/python3 scripts/export_salmon_page.py        # salmon.db -> data.js
```

Then republish `index.html` with `files={data.js}`, passing the URL from `artifact.json`
(omitting it mints a second artifact). The export refuses to write if a sheet's row
count differs from the database's.

Entries that cannot be parsed stay visible (`not_parsed` sheet, `(not parsed)` rows).
