# App Store listing draft — WAFishMap

Paste into App Store Connect. Adjust tone if needed; keep the guidance-vs-regulation sentence.

## Name (30 chars)

`WAFishMap`

## Subtitle (30 chars)

`WA launches & seasonal timing`

## Category

Primary: **Navigation** (or **Sports** if you prefer lifestyle; Navigation matches map + location).

## Age rating

Complete the questionnaire honestly. Expect roughly **4+** unless you mark unrestricted web content; there is no user-generated content, no gambling, no mature themes in-app.

## Promotional text (170 chars, optional)

```
Statewide WA launches, piers, and rivers with clear seasonal timing — and a one-tap path to verify rules at WDFW before you go.
```

## Description

```
WAFishMap helps you plan a fishing day in Washington.

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

## Keywords (100 chars, comma-separated, no spaces after commas if you prefer ASC style)

```
fishing,Washington,WDFW,boat launch,pier,salmon,Puget Sound,tides,river,map
```

## Support URL

Use your privacy-policy host or a simple page with contact email.

## Marketing URL (optional)

Same host or leave blank for 1.0.

## Review notes (for App Review)

```
WAFishMap is a map of Washington fishing access with editorial seasonal timing.

• Location is optional (When In Use) to center the map; deny still shows statewide data.
• WeatherKit is used only for plan-time wind/precip on a selected site.
• No accounts, no tracking, no user-generated content.
• Ratings are guidance, not regulations; every detail sheet links to WDFW.
• To see guidance: launch the app, tap any colored launch pin (or use -uiTesting on a simulator build which opens Boston Harbor).
• Privacy policy: <PASTE HTTPS URL AFTER HOSTING docs/app-store/privacy-policy.md>
```

## App Privacy questionnaire (ASC)

| Question | Answer |
|---|---|
| Tracking? | No |
| Purchase history / contact / financial / health / sensitive? | No |
| Location | Yes — Precise Location, **App Functionality**, Linked to User: No, Used for Tracking: No |
| Diagnostics / usage data collected by you? | No (Apple may collect separately) |
| Product interaction collected by you? | No |

## Screenshots (6.7" / 6.1")

Use `scripts/app_store_screenshots.sh` after a Debug or Release build is installed on the simulator. Capture at least:

1. Statewide / regional map with colored pins + legend  
2. Species filter active  
3. Site detail sheet (Boston Harbor via `-uiTesting`) with Before you go  
4. Heat overlay on  
5. River sheet or flow coloring (optional 5th)

## Checklist before Archive

- [ ] Privacy policy live at HTTPS; URL in ASC  
- [ ] This listing pasted into ASC  
- [ ] App Privacy answers match the table above  
- [ ] Merge `test/guidance-on-every-sheet` (disclaimer UI test) if still open  
- [ ] Archive from Xcode / `xcodebuild -destination generic/platform=iOS archive`  
- [ ] Upload → Submit for Review  
