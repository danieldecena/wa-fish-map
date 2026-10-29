# Apple developer docs survey: mapping, weather, design, behavior (2026-10-29)

Research only. Nothing was built and no app or web code changed. Daniel asked: "look at apple dev docs for mapping, weather, etc to integrate even designs", then added "and behavior".

## How this was read, and what it cannot say

- Symbols, availability and quoted statements come from the `apple-docs` tool (`get_apple_doc`), read 2026-10-29. HIG pages were read in full through the same tool (Maps, Sheets, Gestures, Playing haptics, Motion, Loading, Feedback, Privacy, VoiceOver, Materials, Accessibility).
- The tool returns declarations, topic lists and availability, but for many MapKit/WeatherKit classes it returns no property-level prose. Where a behavior is not on a page I read, the row says "unconfirmed".
- Two figures come from developer.apple.com marketing pages, not the docs tree, fetched with WebFetch: MapKit JS limits (`/maps/mapkitjs/`) and WeatherKit quota (`/weatherkit/get-started/`).
- SF Symbol names and their first-release years come from this Mac's `CoreGlyphs.bundle/name_availability.plist`, not from the docs. Release year to iOS: 2019=13, 2020=14, 2021=15, 2022=16.0, 2022.1=16.1, 2023=17, 2024=18, 2025=26.
- Project facts come from reading the code on `origin/main` (2026-10-29). App deploys to iOS 18.0 on the iOS 26 SDK.
- Effort: S under a day, M one to three days, L more. Risk: what could go wrong in the app or page, not schedule.
- No doc page gave numeric spring or duration advice. The HIG Motion page has none; see F4.

## A. MapKit (the app is an MKMapView)

| Feature | Apple symbol or page | Availability | What it would add here | Effort | Risk |
| --- | --- | --- | --- | --- | --- |
| Baked depth-shading raster | `MKTileOverlay`, `MKTileOverlayRenderer`; `canReplaceMapContent`, `minimumZ/maximumZ`, `loadTile(at:result:)` | iOS 7.0 | The spike's raster as a layer. Docs: tiles "can supplement the underlying map content or replace it completely"; subclass `loadTile(at:result:)` to supply your own tiles | M | Med: tiles must be baked per zoom; bundle-file loading unconfirmed (docs show URL templates and `url(forTilePath:)`) |
| Bathymetry from MapKit itself | search "bathymetry depth water ocean" in MapKit | none found | Nothing: no depth/seafloor symbol exists in MapKit. `ElevationStyle.realistic` is described as "realistic ground contours", so land only (seafloor unconfirmed) | n/a | Do not assume it |
| Muted basemap | `MKStandardMapConfiguration(emphasisStyle:)`, `.muted` | iOS 16.0 | Already used when Rivers or Heat is on (`FishingMapRepresentable`). HIG: muted is "great if you have a lot of information-rich content" | done | none |
| Elevation style | `MKMapConfiguration.ElevationStyle` `.flat`/`.realistic` | iOS 16.0 | Terrain relief behind river and bank sites | S | Low; looks heavier, untested here |
| Satellite / hybrid | `MKImageryMapConfiguration`, `MKHybridMapConfiguration` | iOS 16.0 | A basemap toggle to see ramps and bank cover | S | Muting and the violet heat tuning assume the standard map (`DS.Overlay.density` comment) |
| POI filter | `MKPointOfInterestFilter(including:)`; categories include `.fishing`, `.marina`, `.kayaking`, `.beach`, `.restroom`, `.parking` | filter iOS 13.0; category availability not shown | App's list is marina, park, campground, nationalPark, parking, publicTransport, gasStation. `.fishing` ("fishing areas") is absent | S | Low; Apple data in Washington unconfirmed, may duplicate WDFW pins |
| Shareable site card | `MKMapSnapshotter`, `.Options` (`region`, `camera`, `preferredConfiguration`, `size`, `scale`) | iOS 7.0 | An image of a site for sharing. Docs: snapshots do not include app overlays or annotations; you draw them | M | Med: must redraw pin and rating by hand |
| Look Around | `MKLookAroundSceneRequest`, `MKLookAroundSnapshotter` | iOS 16.0 | Street view of a launch or pier | S | Coverage of Washington piers and ramps unconfirmed |
| Directions | `MKDirections` (throttles with `loadingThrottled`), `MKMapItem.openInMaps(launchOptions:)`, `MKLaunchOptionsDirectionsModeKey` | iOS 7.0 / 6.0 | Hand off to Maps; do not compute routes in-app | S | Low |
| Unified Maps URLs | `maps.apple.com/directions?destination=lat,lon&mode=driving`, `/place`, `/frame?map=satellite` | iOS 18.4 and later | Web Directions that start navigation, not just drop a pin (page uses `maps.apple.com/?ll=&q=` today) | S | Low; behavior on older iOS unconfirmed |
| GeoJSON | `MKGeoJSONDecoder.decode(_:)` | iOS 13.0 | Little: the app already decodes WDFW `f=geojson` with `Codable` | skip | none |
| Clustering | `MKClusterAnnotation` | iOS 11.0 | Already used, custom title | done | none |
| Camera limits | `MKMapView.CameraBoundary`, `setCameraZoomRange` | iOS 13.0 | Already used (Washington box, 3,200 km cap) | done | none |
| Map-feature taps | `selectableMapFeatures`; `mapView(_:selectionAccessoryFor:)`, `MKSelectionAccessory` | iOS 16.0 / 18.0 | Tapping Apple's own marinas or ramps with a place card. HIG Maps covers place cards | M | Competes with the app's own sheet (HIG: "avoid duplicating information") |
| Reverse geocode | `MKReverseGeocodingRequest`, `MKGeocodingRequest` | iOS 26.0 | Name a dropped pin or a trip start | S | Needs `#available(iOS 26)`; below deployment target |
| SwiftUI `Map` | `MapStyle`, `MapCameraBounds`, `MapCameraPosition` | MapStyle iOS 17.0 | Same styles as `MKMapView`. App needs hand-rolled river taps, custom annotation views and clusters | L | High; no `MKTileOverlay` equivalent turned up in search (not proven absent). Skip |

## B. MapKit JS (Apple's web map)

| Feature | Apple symbol or page | Availability | What it would add here | Effort | Risk |
| --- | --- | --- | --- | --- | --- |
| Interactive web map | MapKit JS (`mapkit`), loaded from `https://cdn.apple-mapkit.com/mk/x/mapkit.core.js` with `data-token` | docs index lists 5.0 and a v6 migration | Real Apple basemap on the page | L | Cannot run in the published frame; see below |
| Maps token | "Creating a Maps token": ADP account, types Embed API / MapKit JS / Server API / Web Snapshots; restriction Domain or None; domain list | n/a | Needed before any call | S | Domain-restricted token needs the page's real origin |
| Usage limits | developer.apple.com/maps/mapkitjs | n/a | Page states 250,000 map views and 25,000 service calls per day, 25,000 snapshots per day, per membership | n/a | Over-limit behavior not stated |
| CSP needs | docs example CSP | n/a | `connect-src`, `img-src`, `worker-src` to `https://*.apple-mapkit.com`, `blob:`, `wasm-unsafe-eval` | n/a | Confirms it is network-heavy |
| Web Snapshots | token type "Web Snapshots" | listed | A static basemap image fetched at build time, baked into the page | M | Terms on storing or redistributing snapshots not read; unconfirmed |

Plain answer: **MapKit JS cannot run in the published page.** It loads a script from a CDN, opens network connections and web workers to `*.apple-mapkit.com`, and needs a token. The page runs in a frame that blocks all network requests. The docs describe only normal hosting (a site with a script tag and a domain-restricted token); they say nothing about sandboxed frames, and how a domain-restricted token behaves from one is unconfirmed. It would only work if the map moved to a page on a real domain, which is a different project. The page's own SVG map with baked data (`depth-data.js`, `geo.js`) stays the right design.

## C. WeatherKit

| Feature | Apple symbol or page | Availability | What it would add here | Effort | Risk |
| --- | --- | --- | --- | --- | --- |
| Service | `WeatherService.shared.weather(for:including:)`; queries `.current`, `.hourly` (25 h), `.daily` (10 d), `.minute`, `.alerts`, `.availability`, `.changes`, `.historicalComparisons` | iOS 16.0 | App uses only `.hourly` (wind speed, direction, rain chance, temperature) | n/a | Whether each data set counts as a separate "call" for quota: unconfirmed |
| Wind and gusts | `Wind`: `speed`, `direction`, `gust?`, `compassDirection` | iOS 16.0 | Gusts, which matter for small boats and pier casting. Not shown today | S | Low; `gust` is optional |
| Pressure | `HourWeather`/`CurrentWeather`: `pressure`, `pressureTrend` (`rising`, `falling`, `steady`, with `accessibilityDescription`) | iOS 16.0 | A "pressure falling" line; fishing value is folklore, label it as such | S | Low; do not rate on it |
| Sky | `cloudCover`, `cloudCoverByAltitude`, `visibility`, `uvIndex`, `precipitationAmount`, `symbolName` (an SF Symbol) | iOS 16.0 | Visibility for fog on the water; cloud cover for low-light bite windows | S | Low |
| Sun and moon | `DayWeather.sun: SunEvents` (sunrise, sunset, civil/nautical/astronomical dawn and dusk); `DayWeather.moon: MoonEvents` (`moonrise`, `moonset`, `phase`); `MoonPhase.symbolName` | iOS 16.0 | Moon phase and moonrise for the plan date. App's `DaylightView` computes its own sun times | S | Low; two sources for sun would disagree by minutes |
| Alerts | `.alerts` -> `[WeatherAlert]?` (`summary`, `severity`, `region`, `source`, `detailsURL`) | iOS 16.0 | Government advisories (small craft, wind) in the "Before you go" block. Docs: "Due to data source restrictions, information contained is served raw" | M | Med: wording is raw; `WeatherAvailability.alertAvailability` says it may be unsupported or down, show unknown, not none |
| Minute forecast | `.minute` -> `Forecast<MinuteWeather>?` | iOS 16.0 | "Rain starts in 12 min" for a day trip | S | Low; availability by region |
| Climate stats | `dailyStatistics`, `hourlyStatistics`, `monthlyStatistics`, `dailySummary` | iOS 16.0 (per-symbol availability not shown) | Typical wind or rain for a month | M | Not needed; the app's seasons are curated |
| Tides, water temp, waves | search "tide wave water temperature ocean marine" in WeatherKit | none found | **Nothing.** Only air-temperature statistics matched. The app keeps NOAA (`NOAATideLoader`, `NDBCLoader`) | n/a | Do not wait on Apple for these |
| Attribution | `WeatherService.attribution`: `combinedMarkLightURL`, `combinedMarkDarkURL`, `legalPageURL`, `legalAttributionText`. Docs: "Attribution is required for publishing software using WeatherKit." | iOS 16.0 | Already drawn in every state of `PlanWeatherView` | done | App Review rejected 1.0 (6) and (8) under 5.2.5 on attribution (code comment); keep the mark visible in every state |
| REST API | `GET /api/v1/weather/{language}/{latitude}/{longitude}`, `/availability/...`, `/weatherAlert/...`, `/attribution/{language}` | web service | Weather for non-Apple platforms | L | Needs ES256 JWT from a WeatherKit key and a Service ID; docs: "Never distribute your private key" and make "an authenticated service" to sign tokens. The page has no network and no server, so no |
| Quota | developer.apple.com/weatherkit/get-started | n/a | Page states 500,000 calls a month included with membership; 1M is US$49.99 | n/a | Beyond current use |
| Simulator | not in the docs I read | n/a | CLAUDE.md records that provisioning is unsupported there; verify with `scripts/verify_weatherkit_device.sh` | n/a | Docs tool cannot confirm or deny |

## D. Design (HIG, SF Symbols, materials)

| Feature | Apple symbol or page | Availability | What it would add here (app / page) | Effort | Risk |
| --- | --- | --- | --- | --- | --- |
| Map emphasis, selection, clusters | HIG Maps: muted vs default; "Clearly identify elements that people select"; cluster overlapping points | n/a | App: muted + clusters done. Page: selected row has an outline; confirm a selected pin gets the same outline | S | Low |
| Apple logo and legal link | HIG Maps: 7 pt padding at the sides, 10 pt above and below; "don't cover these elements all the time"; with a bottom card, 10 pt above its lowest resting position | n/a | App: the permanent bottom `statusBar` may sit over the logo; not checked on a device | S | Low; check before changing |
| Control contrast on the map | HIG Maps: "enough contrast between custom controls and the map"; thin stroke or drop shadow | n/a | App's chrome is Liquid Glass; page's `.glass` bar. Both already separate from the map | done | none |
| Overlay level | HIG Maps: above roads (default) vs above labels | `MKOverlayLevel` | Rivers and heat could sit above labels to avoid label clutter; unconfirmed what the app sets | S | Low |
| Sheets, detents, grabber | HIG Sheets: medium and large; "Include a grabber in a resizable sheet"; tap it to cycle detents; swipe to dismiss | `presentationDetents` iOS 16.0; `presentationBackgroundInteraction` iOS 16.4; `presentationDragIndicator` iOS 16.0 | App: medium+large, map live up to medium, `.thickMaterial`. Page: grabber is decorative; see F2 | S | Low |
| Liquid Glass | HIG Materials: "Don't use Liquid Glass in the content layer"; use sparingly; regular variant for text-heavy; clear only over rich media | `glassEffect` iOS 26 | App follows it (chrome on glass, sheet on thick material). Page: keep glass to the bar and popovers, sheets stay solid | done | none |
| SF Symbols for this domain | `fish`, `fish.fill`, `figure.fishing` (iOS 16.0); `water.waves`, `water.waves.and.arrow.up/down` (16.0), `water.waves.and.arrow.trianglehead.up/down` (18.0); `wind` (13.0); `thermometer.medium` (16.0), `thermometer.variable` (18.0); `humidity` (15.0); `barometer` (14.0); `moonphase.*` (16.0); `sunrise`, `sunset` (13.0); `binoculars` (14.0) | per name | Weather rows: wind, thermometer, barometer, `MoonPhase.symbolName`. Tide direction: `water.waves.and.arrow.up/down`, name-only match, meaning not verified. **No `tide`, `anchor`, `boat`, `wave` symbol exists** (confirms the code comment on `anchor.fill`) | S | Low; web symbol use outside Apple platforms: license not read, so the page keeps its own SVGs |
| Dynamic Type | HIG Accessibility: let people enlarge text "by at least 200 percent"; iOS default 17 pt, minimum 11 pt | n/a | App uses text styles (`DS.TypeScale`, mostly `caption2` = 11 pt default) so it scales; check the control bar at the largest accessibility size. Page: mostly 12 px fixed, above the 11 pt floor | S | Low |
| Color and contrast | HIG Accessibility: 4.5:1 up to 17 pt, 3:1 for bold or 18 pt and up; "Convey information with more than color alone"; provide a higher-contrast scheme for Increase Contrast | n/a | App: ratings also carry badges and labels; no `colorSchemeContrast` handling found. Page: `prefers-contrast` not handled | M | Low |
| Control size | HIG Accessibility: iOS default 44x44 pt, minimum 28x28 pt | n/a | Both already draw small and touch at 44 (`MarkerMetrics`, `.bar ... ::after`) | done | none |

## E. Other docs worth a look

| Feature | Apple symbol or page | Availability | What it would add here | Effort | Risk |
| --- | --- | --- | --- | --- | --- |
| Live trip tracking | `CLBackgroundActivitySession`; `allowsBackgroundLocationUpdates`; `CLServiceSession` | iOS 17.0; iOS 18.0 (macOS "-") | Record a fishing trip track with a when-in-use grant and the visible indicator | L | Reverses the "location stays on this device" promise's simplicity; privacy label and purpose string change |
| Live Activity | `ActivityKit.Activity` (`request`, `update`, `end`) | iOS 16.1 | "Tide turns in 20 min" on the Lock Screen. Docs: can start only in the foreground (or via a `LiveActivityIntent`); update and end in the background | L | Med: no tide data source inside the activity without background work; budget unconfirmed |
| Widget | `Widget` (timeline provider) | iOS 14.0 | "Best time today": Prime sites from `fisheries.json` plus computed tides | M | Low-med; needs shared data between app and extension |
| App Shortcuts | `AppShortcutsProvider` | iOS 16.0 | "What's biting near me?" by voice | M | Low; answer must carry the guidance-not-regulation line |
| Precise vs approximate | `accuracyAuthorization` (`.reducedAccuracy`), `requestTemporaryFullAccuracyAuthorization(withPurposeKey:)` | iOS 14.0 | See F6 | S | Low |
| Location button | `CLLocationButton` | iOS 15.0 | One-time grant without a standing permission | S | Low |
| Privacy manifest | `PrivacyInfo.xcprivacy` | n/a | Already present in the target; nothing to add | done | none |
| Swift Charts, SwiftData | not read | n/a | Not surveyed | n/a | n/a |

## F. Behavior

For each topic: what the HIG says, what the app and the page do now (read in code), the gap, the change.

| Topic | HIG / docs say | App today | Page today | Gap and concrete change | Effort | Risk |
| --- | --- | --- | --- | --- | --- | --- |
| F1 Gestures | Gestures: tap activates or selects; double tap zooms in, "zoom out if already zoomed in"; pinch zooms; two-finger rotate; touch and hold "reveal additional controls"; "give people more than one way"; "Indicate when a gesture isn't available" | `MKMapView` supplies all of them. Extra recognizers only mark `userMovedCamera`. A hand-rolled river tap `require(toFail:)` the double-tap, so a river tap probably waits out the double-tap window (my inference, not a doc) | Pointer events: drag, pinch, wheel, keys, +/- buttons. 6 px tap threshold. **No double-tap or double-click zoom** | Page: add double-tap on empty map = `zoomAt(..., 2)` via `animateTo(~250 ms)`, only when the target is not a marker so pin taps are not delayed. App: none needed. Long-press: skip | S | Low; must not add latency to pin taps |
| F2 Sheets | Sheets: detents medium/large; grabber works with VoiceOver; "Support swiping to dismiss"; iOS sheets can be nonmodal; a lone Done button implies completing a task is the only exit | `[.medium,.large]`, map interactive up to medium, system swipe-to-dismiss, no text fields so no keyboard issue; iPad uses `.inspector`. Drag indicator not set explicitly (docs: show it "when it isn't apparent that a sheet can resize") | Bottom sheet on narrow screens with a **decorative grabber** (hidden at 760 px+), Done button, Escape closes, focus moves in and returns, other popovers hide | App: add `.presentationDragIndicator(.visible)` (XS). Page: make the grabber real: drag on `.sbar` down to dismiss (threshold or velocity), tap to switch between half and full; keep Done. Drag only on `.sbar` so scrolling the body is untouched | S app / M page | App low; page med (pointer conflicts with body scroll) |
| F3 Haptics | Playing haptics: use system patterns by documented meaning (notification = outcome, impact = collision/snap, selection = "values are changing"); "Avoid overusing"; "Make haptics optional"; complement visuals | **None** (no `sensoryFeedback` or `UIFeedbackGenerator` found). Pickers already give system haptics | None; `navigator.vibrate` is not an Apple doc and was not checked | Almost nothing fits. A pin tap is not a value change. Candidate only: `.sensoryFeedback(.warning, trigger:)` when Recenter has no fix. `sensoryFeedback` is iOS 17.0. Revisit if a trip log adds a "saved" outcome | S | Low; **skip for now** |
| F4 Motion | Motion: "Add motion purposefully"; brief and precise; "avoid adding motion to UI interactions that occur frequently"; "Let people cancel motion"; make it optional. Accessibility: with Reduce Motion, tighten springs, track gestures, replace x/y/z transitions with fades, avoid blur transitions. **No durations or spring values in the HIG.** `Animation.spring(duration:bounce:)` defaults 0.5 s, bounce 0 (critically damped) | Camera moves use `setRegion(animated: true)` (cluster tap, recentre, focus). Never reads `isReduceMotionEnabled`. Duration is not settable through those calls (docs say only "animates"); whether MapKit honors Reduce Motion: unconfirmed | `animateTo` 320-350 ms ease-out cubic; sheet slide 0.28 s `cubic-bezier(.2,.8,.2,1)`; `prefers-reduced-motion` turns both off; pointer-down cancels a move (meets "let people cancel") | App: when `UIAccessibility.isReduceMotionEnabled`, pass `animated: false` for cluster expand and recentre. Page: `reduce` is read once at load; listen to the media query's `change` event | S | Low |
| F5 Loading, errors, uncertainty | Loading: "Show something as soon as possible", placeholders, let people keep working. Feedback: status "integrated into your interface", "Show people when a command can't be carried out and help them understand why". I found **no HIG text on showing uncertainty**; Charting data not read | Status bar with a mini `ProgressView` and text (" · piers unavailable"); weather says three different things (spinner, "doesn't reach that date yet", "unavailable right now"); "Forecast ..., not an observation"; protected-area check has an explicit unavailable state; no retry button on failures | Data is baked, so no loading state. Uncertainty is stated in words: "+ estimate" on depth, "A guess at the best piers right now", age chip | App: add a Retry button to the weather failed state and to a failed layer fetch. Page: nothing to load; keep the wording. Both: keep failures rendered as errors, never as zero | S | Low |
| F6 Location permission | Privacy: ask "only when your app clearly needs access", avoid launch-time requests unless required; purpose string a brief active sentence; a pre-alert screen has one "Continue" button and no Cancel; `CLLocationButton` for one-time use. `.reducedAccuracy` disables region monitoring and ignores finer `desiredAccuracy` | `requestIfNeeded()` runs in the map's launch `.task`. Purpose string is a clear active sentence. Denied or restricted: a status line "Location is off — turn it on in Settings" opens Settings. `accuracyAuthorization` never read; `desiredAccuracy` is 100 m | No geolocation by design: "Near me" asks the user to tap the map, so no permission exists | App: (a) move the prompt to the first Recenter tap, keep the statewide opening (product call, loses the open-near-you first launch); (b) read `accuracyAuthorization`; if reduced, label the dot "approximate" and offer `requestTemporaryFullAccuracyAuthorization(withPurposeKey:)` only from Recenter (needs `NSLocationTemporaryUsageDescriptionDictionary`). Page: none | S-M | Med for (a), a first-run behavior change; low for (b) |
| F7 Undo, destructive | Feedback: warn only for "unexpected and irreversible" loss, not expected loss | No destructive actions | Star toggles saved places in `localStorage`; un-star is instant and reversible | Not relevant today. Revisit with a trip log | n/a | n/a |
| F8 VoiceOver rotor and custom actions | VoiceOver: label key elements, group and order, announce layout changes, "Support the VoiceOver rotor when possible" (`UIAccessibilityCustomRotor` iOS 10.0; SwiftUI `AccessibilityRotorEntry` iOS 15.0); `UIAccessibilityCustomAction` iOS 8.0 shows in the Actions rotor | Pins are accessibility elements with a spoken summary ("Edmonds Pier, Fishing pier, rated Fair") and button trait; clusters read "N fishing spots, best ..."; `PinVoiceOverProbe` covers it. **No custom rotor, no custom actions** | `role="application"` map with a label; pins are focusable with Enter/Space; arrow keys pan, +/- zoom; `aria-live` summaries; the Rivers list is a non-map route | App: add custom actions to `SiteMarkerView` (Open details, Directions via `MKMapItem.openInMaps`) and a rotor "Prime and Good spots" over visible annotations. Whether a custom rotor can attach to an `MKMapView`'s own accessibility container: unconfirmed, test with the probe. Page: keep the list; no rotor API on the web | M app | Med: map container behavior |

## Ranked recommendations

Each line: why. "Now" means cheap and low risk; "later" is gated on something named.

### iOS app

Adopt now
1. WeatherKit daily and alerts: one `weather(for:including: .hourly, .daily, .alerts)` adds gusts, pressure trend, moon phase and government advisories. Attribution already exists; show alerts as unknown when `alertAvailability` says so.
2. Location prompt (F6): read `accuracyAuthorization` and label an approximate dot; moving the prompt off launch is Daniel's call.
3. Reduce Motion on camera moves (F4) and `.presentationDragIndicator(.visible)` (F2): tiny, HIG-backed.
4. VoiceOver custom actions on pins (F8): the map's accessibility is already tested; this adds the missing shortcut to details and directions.
5. Add `.fishing` to the POI filter and Retry buttons on failed fetches (A, F5): one-line and small.

Later
6. `MKTileOverlay` for the depth raster, after the `spike/depth-shading` branch reports. Docs confirm the class; per-zoom tile baking is the cost.
7. `MKMapSnapshotter` share card, widget for "best time today", Live Activity for tide turns: real features, each needs a product decision.
8. Satellite toggle, elevation style: cheap, but the muted-basemap tuning assumes the standard map.

Skip
9. SwiftUI `Map` rewrite, GeoJSON decoder swap, `MKDirections` in-app routing, Look Around (coverage unconfirmed), map-feature place cards (duplicates the app's sheet), haptics (F3), background trip tracking (privacy cost), WeatherKit climate statistics.

### Web page

Adopt now
1. Directions links to unified Maps URLs (`/directions?destination=lat,lon&mode=driving`): starts navigation instead of dropping a pin; needs iOS 18.4 for the new form, older fallback unconfirmed. Replace the four `maps.apple.com/?ll=&q=` builders.
2. Real sheet grabber with swipe-down dismiss (F2): HIG says a grabber should work and swiping should dismiss; today it is decorative.
3. Double-tap zoom on empty map (F1): the standard iOS gesture the page lacks.
4. Live Reduce Motion listener (F4): one event listener.

Later
5. Selected-pin outline parity with the app (HIG Maps "Clearly identify elements that people select").
6. `prefers-contrast` styles (D): the HIG asks for a higher-contrast scheme.
7. Baked static basemap image from Apple Web Snapshots, only after reading its terms.

Skip
8. MapKit JS and the WeatherKit REST API: both need network and (for REST) a secret key the page cannot hold.
9. SF Symbols on the web (license unread), haptics, geolocation, WeatherKit-derived data of any kind.

## Not confirmed in the docs

- Whether `MKTileOverlay` loads bundled files or a `file://` URL template; tile size default.
- Any seafloor rendering in `ElevationStyle.realistic`; availability of `.fishing` POI data in Washington.
- Whether SwiftUI `Map` can host tile overlays; Look Around coverage for Washington piers.
- MapKit JS behavior from a sandboxed frame and with a Domain-restricted token; over-limit behavior; Web Snapshots storage terms.
- WeatherKit quota counting per data set; simulator limitation (project knowledge only); per-symbol availability of the statistics queries.
- HIG text on uncertainty display; any numeric spring or duration advice (none on the Motion page).
- Whether MapKit honors Reduce Motion for `setRegion(animated:)`; whether a custom rotor attaches to `MKMapView`.
- Fallback of unified Maps URLs on iOS older than 18.4.
- Whether Apple's logo and legal link are covered by the app's bottom bar.
