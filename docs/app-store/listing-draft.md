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
https://danieldecena.github.io/wa-fish-map/support.html
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
fishing,Washington,trout,lakes,boat launch,pier,salmon,Puget Sound,tides,river,map
```

## Review notes (for App Review)

```
WA Fish Map is a free map of public fishing access in Washington State (boat launches, piers, lakes, rivers) with editorial seasonal timing. No sign-in is needed.

How to review
1. Launch the app. Location is optional; declining still shows the whole state. Outside Washington the map opens statewide: zoom in on Puget Sound (Seattle/Tacoma) to see colored pins.
2. Tap any colored pin to open its detail sheet: what's biting now, best months, tides (marine sites), river flow (gauged rivers), sunrise/sunset, and Apple Weather wind and rain for the planned hour.
3. Tap "All species" at the top to filter, or the date and time pills to plan another day. Pins recolor.
4. In the bottom bar, "Rivers" draws river lines and "Heat" shows the density of well-timed spots.

Data and scope
- Access sites, marine areas and lakes come from public Washington Department of Fish and Wildlife (WDFW) map services; tides from NOAA; river flow from USGS; weather from WeatherKit. The app is not affiliated with or endorsed by WDFW.

WeatherKit (Guideline 5.2.5)
- WeatherKit is used in one place: the "Wind & rain" section of every site's detail sheet (tap any pin, scroll to "Wind & rain").
- Directly under the forecast the app shows the Apple Weather mark (served by WeatherAttribution, light/dark variant) and an "Other data sources" link that opens WeatherAttribution.legalPageURL. Tapping the mark opens the same page.
- A screen recording on a physical iPhone showing this is attached.
- Ratings are editorial timing guidance, not regulations. Every detail sheet shows a disclaimer and links to WDFW to confirm seasons and limits.
- Sites WDFW lists as closed are labeled "Closed".

Privacy
- No accounts, ads, analytics or tracking. Device location stays on the device and only centers the map. Weather and directions use the selected site's coordinates, not the user's. App Privacy: Data Not Collected.
- Privacy policy: https://danieldecena.github.io/wa-fish-map/privacy.html
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

ASC holds 6 on the iPhone 6.5" slot (1284x2778): Tacoma, Boston Harbor sheet, Seattle, San Juans, Spokane, Hood Canal. The four live regional maps were captured 2026-09-16 on the simulator with `simctl location` set per region, then resized with `sips -z 2778 1284`. iPhone-only, so no iPad set is required.

## Checklist

Submitted 2026-09-16 3:18 PM: iOS App 1.0 (6), Waiting for Review, manual release.

- [x] Privacy policy live at HTTPS
- [x] Listing copy ready to paste
- [x] App Privacy answers documented
- [x] Release archive uploaded to ASC (2026-09-16; build **6** / 1.0 attached, iPhone-only)
- [x] ASC App Information: name, subtitle, category Navigation
- [x] ASC App Privacy: policy URL
- [x] ASC App Privacy: Data Not Collected, published 2026-09-16 (next upload must carry the matching manifest)
- [x] ASC Version: promo / description / keywords / support URL / copyright; review notes
- [x] Attach screenshots (6 of 10, 6.5" slot)
- [x] Pricing, Content Rights, Age Rating
- [x] Save -> Add for Review -> Submit for Review (2026-09-16)
- [ ] Release after approval
