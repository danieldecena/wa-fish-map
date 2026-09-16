# App Store listing — WA Fish Map

Paste into App Store Connect. Keep the guidance-vs-regulation sentence.

## Name (30 chars)

`WA Fish Map`

## Subtitle (30 chars)

`Launches & seasonal timing`

## Category

Primary: **Navigation**

## Age rating

Complete the questionnaire honestly. Expect roughly **4+** (no UGC, gambling, or mature themes).

## Privacy Policy URL

```
https://danieldecena.github.io/wa-fish-map/privacy.html
```

## Support URL

```
https://danieldecena.github.io/wa-fish-map/privacy.html
```

## Promotional text (170 chars, optional)

```
Statewide WA launches, piers, and rivers with clear seasonal timing — and a one-tap path to verify rules at WDFW before you go.
```

## Description

```
WA Fish Map helps you plan a fishing day in Washington.

See boat launches and piers statewide on a live map, color-coded by curated seasonal timing. Filter by species and plan date. Tap a spot for what’s biting now, best months, tides (marine), river flow where gauged, and plan-time wind and rain from Apple Weather.

Guidance is editorial timing — not regulations, bag limits, or open/closed seasons. Every guidance screen links to WDFW so you can verify before you go. The Fish Washington app remains the rulebook.

Features
• Statewide marine areas and access sites from WDFW
• Species filter and plan date that recolor the map
• Tides, buoys, and USGS river conditions where available
• Heat overlay for density of well-timed spots
• Offline curated guide when the network is down

Washington waters only. Always confirm seasons and limits with WDFW.
```

## Keywords (100 chars)

```
fishing,Washington,WDFW,boat launch,pier,salmon,Puget Sound,tides,river,map
```

## Review notes (for App Review)

```
WA Fish Map is a map of Washington fishing access with editorial seasonal timing.

• Location is optional (When In Use) to center the map; deny still shows statewide data.
• WeatherKit is used only for plan-time wind/precip on a selected site (coordinates sent to Apple for that forecast).
• No accounts, no tracking, no user-generated content.
• Ratings are guidance, not regulations; every detail sheet links to WDFW.
• To see guidance: launch the app, tap any colored launch pin (or use -uiTesting which opens Boston Harbor).
• Privacy policy: https://danieldecena.github.io/wa-fish-map/privacy.html
```

## App Privacy questionnaire (ASC) — fill exactly

| Question | Answer |
|---|---|
| Tracking? | **No** |
| Purchase history / contact / financial / health / sensitive info? | **No** |
| Location | **No** — the device location only moves the map on the phone; weather and directions send the launch's coordinates, never the user's |
| Diagnostics / usage / product interaction collected by you? | **No** (Apple may collect separately) |

Do **not** declare tracking domains. WeatherKit is Apple’s framework; you are not selling location.

## Screenshots

Generated under `docs/app-store/screenshots/` via `scripts/app_store_screenshots.sh`. Upload 6.7" and 6.1" sets in ASC (scale/crop in Preview if needed).

## Checklist

Paused 2026-09-16 — resume when the app build is ready for review (screenshots + Submit).

- [x] Privacy policy live at HTTPS
- [x] Listing copy ready to paste
- [x] App Privacy answers documented
- [x] Release archive uploaded to ASC (2026-09-16; build **2** / 1.0 attached)
- [x] ASC App Information: name, subtitle, category Navigation
- [x] ASC App Privacy: policy URL
- [x] ASC App Privacy: Data Not Collected, published 2026-09-16 (next upload must carry the matching manifest)
- [x] ASC Version: promo / description / keywords / support URL / copyright; review notes
- [ ] Attach screenshots (ASC still 0 of 10) — sized copies in `/tmp/asc-shots/` and `docs/app-store/screenshots/`
- [ ] Save → Add for Review → Submit for Review
