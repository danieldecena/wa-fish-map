# WAFishMap — Status

## Confirmed working

- `fisheries.json` now seeds all 16 statewide marine areas (1-8-2 + 9-13; only
  the "Oregon" polygon is unseeded) plus 11 freshwater counties. WDFW-checked
  2026-08-30.
- `fisheries.json` v1 Puget Sound seed cross-checked against WDFW; corrections
  applied (see decision log).
- Dawn/dusk comes from real sun times: `SolarTimes` (NOAA equations, pure, no
  network) at the map's camera center, with the fixed hour buckets kept as the
  fallback.
- Season/closure capping ships: a curated `seasonRisk` table in fisheries.json
  is matched to species by case-insensitive substring at load, stamping
  `riskMonths` that clamp a species to `.fair`, so a fishery whose season is set
  annually can never render as Prime. Capped species carry a "Season varies —
  verify" badge and their reason. 11 table rows cover the 42 entries whose notes
  already described a closure.
- Ratings run a thermal ramp — Slow azure, Fair amber, Good orange, Prime red —
  as four explicit stops. Above 150km altitude a site draws as an 11pt dot
  instead of a balloon pin.
- The heat overlay draws each grid cell as a tiling MapPolygon, ranked against
  the other cells rather than normalised to the densest one, in four violet
  bands over a muted basemap. Cell size follows the camera.
- The map opens on the user's location when a fix lands inside Washington and
  they have not moved the camera; a denied permission now says so and links to
  Settings.
- Marine launch and pier sheets show that day's NOAA high/low tides for the
  nearest bundled station (170 WA + Columbia-mouth). Follows the map date;
  next extreme after the plan time is highlighted.
- Pins cluster via MapKit's `clusteringIdentifier` (the hand-rolled grid
  clusterer was deleted in the MKMapView migration). Past 400km they are not
  drawn at all — `MapDetailLevel` — and the density overlay is forced on so the
  map is never blank; the legend follows what is drawn, not the toggle.
- Species-first picker recolours pins, clusters, heat, and area fills by an
  exact species name from the guide; missing listings stay gray. Date picker
  unchanged.
- `WAFishMapUITests` is a real target and the verify badge is **observed on
  screen**, not inferred. `-uiTesting` loads the bundled fixture and preselects a
  site so no tap injection is involved; `-planMonth n` pins the month.
- Piers are checked against Marine Protected Areas and answer the same
  three-way `inside / clear / unavailable` as launches, through a shared
  `ProtectedAreaSection`. Piers outside every marine polygon answer freshwater.
- `freshwater.byWaterbody` pins a claim to one lake or river, keyed by a curated
  facility list. Baker Lake sockeye is its first row.
- Marine sheets show the nearest NDBC buoy's latest wave height and water
  temperature, each with its own timestamp.
- WeatherKit works on device. `testWindReadsARealValueOnDevice` **passed** on a
  physical iPhone 16 Pro 2026-09-02, asserting a live `… mph` reading and the
  success-only footer on screen at once. It ran in 7.7s against 68-79s for every
  prior failing run, because the fetch now returns instead of grinding out.
  The test has both inputs: it was observed failing on the same device before the
  fix and passing after, so a green run means something.
- `./scripts/verify_weatherkit_device.sh` is the one command that proves it:
  device pre-flight, build, sign, install, run, then confirm from the device.
- The suite is 139 tests: 138 pass, 1 skips. The skip is
  `testWindReadsARealValueOnDevice`, gated to hardware on purpose.

## Known broken

- The camera guard has a disclosed residual: a genuine user gesture made BEFORE
  the WDFW load completes is misclassified as non-user, so a later location fix
  would still recentre. Narrower than the bug it replaced, and documented in the
  code. Narrower again as of the `isCameraMove` fix below: tap-driven zooms are
  now recognised at all, so only the pre-load window remains.

## Next Up

- Verify remaining default-covered counties if desired (Pierce, Mason, Kitsap,
  Thurston left on the statewide default by design — add only if distinct).

Everything else open lives in `TASKS.md`, which has no open items.

## Decision log

### 2026-09-02 (root cause: two WeatherKit capability type strings)

- **Fixed.** The App ID carried a legacy `WEATHERKIT` capability record. The
  portal minted profiles from it, so `codesign -d --entitlements` showed the
  entitlement present on the installed binary and every check we ran looked
  green, but `weatherkit.apple.com/v3/token` would not honour it. Re-registering
  the capability produced a second record, `WEATHER_KIT`, and the token issued on
  the first attempt. The device test went from failing in 68-79s to passing in
  7.7s.
- Corroboration, found only because the write failed: the App Store Connect API
  will *read* `WEATHERKIT` back but rejects it on `POST`, and its accepted enum
  does not contain it at all. That is a legacy value which can still exist on an
  identifier and can no longer be issued.
- Why this took four sessions: every individual check was green. Entitlement in
  the profile, capability visible in the portal, licence accepted, quota active,
  service reachable. The failure lived in the *disagreement* between two
  representations of the same capability, which no single check could see. What
  finally localised it was the REST control — same service, different credential
  path, returning 200 with real data while the device got 401 — which proved the
  fault was neither the app nor the service but the binding between them.
- Mistake worth keeping: the re-registration was run as DELETE-then-POST without
  first verifying the POST would be accepted. The DELETE succeeded, the POST was
  refused, and the capability sat removed until it was restored by hand in the
  portal. Read enum and write enum were not the same set. Verify the reverse
  operation before running the irreversible half.

### 2026-09-02 (the REST control: WeatherKit works, the device path does not)

- Finding: WeatherKit serves team 877MLS29T9. `GET /api/v1/availability` returned
  200 with `forecastHourly` among the datasets, and the weather endpoint returned
  25 real hours for Boston Harbor — 7 mph at 194 degrees, which is the `SSW 7 mph`
  the app's wind row would have drawn. The device path returned a bare 401 for the
  same coordinate minutes earlier.
- Decided: the control had to sit on the surface that failed. MapKit JS was
  considered and rejected — its auth is unrelated, so a green MapKit would have
  said nothing about WeatherKit. The REST API is the same host and the same
  service, differing only in credential path, which is what makes the contrast
  mean something.
- Refused to guess the Service ID. A token whose `sub` is not a registered
  Services ID is rejected with the same bare 401 as the bug, so trying candidates
  would have manufactured exactly the false confirmation the control exists to
  prevent. Same reason the pre-existing `AuthKey_5Z2966W5U2.p8` was not used: a
  `.p8` carries no record of which service it belongs to, and every Apple key is
  P-256, so the file cannot answer it.
- The signer was proved before it was aimed at Apple: signed with a throwaway
  P-256 key and the output decoded to check the documented header
  (`alg`/`kid`/`id`), the four claims, and a 64-byte raw r||s signature. A
  malformed token would also have produced a 401.

### 2026-09-02 (WeatherKit fault localised to token issuance)

- Tried and failed: the device-side entitlement cache reset. Rebooted the phone,
  deleted the app (absence confirmed via `devicectl device info apps`, not
  assumed), rebuilt and re-ran 2026-09-02. Identical result: the sheet renders
  "Wind and rain unavailable right now." and all three assertions fire. The
  documented remedy for a correct server side does not apply here.
- Noted: the run immediately after the delete proved nothing and was discarded.
  Its label dump held only map chrome — no sheet, no `Wind & rain` — because a
  fresh install re-prompts for location, so `PlanWeatherView` never rendered and
  no fetch was attempted. A failure count alone would have read as confirmation;
  the dump is what showed it was a different failure entirely.
- Finding: every layer below token issuance is green;
  `https://weatherkit.apple.com/v3/token` still returns a bare 401 for
  `com.danieldecena.WAFishMap`.

  **The capability is already enabled — do not re-do it, and do not wait on
  propagation.** The signed profile Apple issued and embedded in the device build
  carries the entitlement:

      $ security cms -D -i ~/Library/Developer/Xcode/DerivedData/WAFishMap-*/ \
          Build/Products/Debug-iphoneos/WAFishMap.app/embedded.mobileprovision \
        | plutil -extract Entitlements xml1 -o - -
      <key>com.apple.developer.weatherkit</key><true/>

  The portal cannot emit a profile containing that entitlement unless WeatherKit
  is enabled on the identifier, so that step is verified complete by artifact.
  The ~30-minute propagation window has therefore also already elapsed.

  **The licence agreement is not it either.** Checked in the portal 2026-09-02:
  Apple Developer Program License Agreement issued 2026-08-18, **accepted
  2026-09-01**. No banner, nothing pending. The Paid Apps Agreement does read
  "Pending User Info", but that gates *payouts* — it wants a bank account and a
  W-9 — and the Free Apps Agreement is Active. Do not submit banking details to
  test this; it does not gate service entitlements.

  **Every layer visible from a browser is green.** Certificates, Identifiers &
  Profiles → Services → WeatherKit shows an active plan: 500,000 calls/month,
  **0 used, 0 calls in the last 30 days**, "You don't have any calls within this
  period." A team without WeatherKit provisioned has no plan page at all. So the
  service is provisioned, the quota is untouched, the entitlement is in the
  signed profile, and the agreement is accepted.

  That localises the fault precisely: **the failure is at token issuance**, not at
  capability, quota, or agreement. Nothing has ever authenticated, which is why
  usage is zero — a 401 dies before it reaches the quota.

  Remaining hypothesis is propagation, and the dates support it: the membership
  renewed 2026-09-01 (renewal date 2027-09-01), the PLA was accepted 2026-09-01,
  and the failing device run was 2026-09-02. The account's current agreement is
  one day older than the bug. Forum thread 807586 describes this exact shape —
  entitlement present in the profile, key created, still 401s, survives clean
  builds and reinstalls.

  Next, in order:

  1. Device-side cache reset — reboot the iPhone, delete WAFishMap, rebuild to
     device, re-run `./scripts/verify_weatherkit_device.sh`. Entitlement data
     caches on the phone, and this is the documented fix when the server side is
     already correct. Five minutes.
  2. If it still returns a bare 401, this is Apple's to fix. File code-level
     support (included with the membership) with: Team ID `877MLS29T9`, bundle
     `com.danieldecena.WAFishMap`, entitlement present in the embedded profile,
     PLA accepted 2026-09-01, WeatherKit plan active with 0 calls, bare 401 from
     `https://weatherkit.apple.com/v3/token` on a signed device build. That is
     not a "did you enable it" ticket.

  Do not re-check the capability or the agreement. Both are verified, by artifact
  and by portal respectively, and re-checking them has already cost two rounds.
  A pass is also the first known-GOOD input this test has ever had.

Everything else open lives in `TASKS.md`.

### 2026-09-02 (WeatherKit narrowed to token issuance; two hypotheses killed)

- Corrected: "Authorise the App ID for WeatherKit" had sat in Next Up as work to
  do. It was already done, and a local artifact proved it — Apple's portal cannot
  emit a provisioning profile carrying `com.apple.developer.weatherkit` unless the
  capability is enabled, and that profile was already embedded in the device build
  on disk. One `security cms -D -i ... | plutil -extract Entitlements` closed the
  item and skipped a documented ~30-minute propagation wait. Rule added to
  CLAUDE.md: check what local artifact would already be different before filing an
  action item that lives in someone's browser.
- Killed: the licence-agreement hypothesis, which this file had named as the live
  branch. The Program License Agreement was accepted 2026-09-01. The Paid Apps
  Agreement reads "Pending User Info", but that gates payouts, not services, and
  chasing it would have meant submitting bank and tax details to test a guess.
- Narrowed: the WeatherKit service page shows an active 500,000-call plan with
  0 calls in 30 days. Service provisioned, quota untouched, entitlement in the
  signed profile, agreement accepted — so the fault is specifically at token
  issuance. Nothing has ever authenticated.
- Live hypothesis is now propagation since the 2026-09-01 renewal, the failing run
  being one day later. Next step is a device-side entitlement cache reset; after
  that it is a code-level support ticket, not local debugging.
- Method note: three rounds of this were spent re-checking things that were
  already verifiable. The evidence was on disk and in the portal the whole time.

### 2026-09-02 (WeatherKit answered: Apple returns 401)

- Finding: WeatherKit fails on hardware for the same reason it fails on the
  simulator, and neither reason is the one assumed. The simulator's ad-hoc
  signing was a real obstacle, but removing it changed nothing: the token
  endpoint returns 401 with an empty body on a correctly-entitled, correctly-
  signed device build. The question "does the live path work on a phone" is now
  answered — no — and the remaining work is an account-level authorisation, not
  code. Nine sessions of this being filed as "needs a device" ended in one run.
- Decided: keep the swallowed-error Logger permanently. It is what turned a mute
  "unavailable" into a 401 with a URL in under a minute, on a device where no
  debugger was attached. Reading the daemon's own subsystem out of the same
  archive gave the status code the app never sees.
- Corrected: the 2026-09-02 simulator control run proved less than first claimed.
  Two of its three assertions used `staticTexts.containing(predicate)`, which
  filters by *descendant*; a StaticText is a leaf, so those two could never have
  matched anything and would have "failed correctly" against any input at all.
  Sourced from the SDK, not from memory — `XCUIAutomation.framework/Headers/
  XCUIElementQuery.h`: `containingPredicate:` is "elements that contain a
  descendant matching the specification", `matchingPredicate:` "applies the
  specified attributes or predicate to the receiver".
  Only the third, an identifier lookup, was sound. Fixed to `matching(...)`, and
  the failure message now dumps every label on screen — which is the only reason
  the device run could be diagnosed from its output. The valid known-bad
  observation is now the device run itself, where all three fired and the dump
  showed "Wind and rain unavailable right now.".
- Noted: a device run that failed at 67s showed two failures and one at 79s
  showed three, because at 67s the section was still spinning. A fixed timeout
  around a live fetch makes the failure count itself unstable; the label dump,
  not the count, is what identifies the state.

### 2026-09-02 (device signing, WeatherKit diagnosability)

- Decided: scope `CODE_SIGN_ENTITLEMENTS` to the app target instead of the
  project. It sat on the two PBXProject-level configs, so all three targets
  inherited it and both test bundles claimed `com.apple.developer.weatherkit`
  under bundle ids whose App IDs have no such capability. Ad-hoc simulator
  signing hides this completely, which is why it survived every green run to
  date. `xcodebuild build-for-testing -destination 'generic/platform=iOS'`
  reproduces it with no hardware attached and was the whole diagnosis:
  `error: Entitlement com.apple.developer.weatherkit not found and could not be
  included in profile ... (in target 'WAFishMapUITests')`. A device
  `xcodebuild test` had therefore never been possible — the verification had no
  route that did not end in reading a screenshot.
- Decided: the success sentinel for the weather section is the "not an
  observation" footer, not the `planWeatherSection` identifier. That identifier
  is on the header `Text`, so it renders in every state including the spinner and
  the failure string; asserting on it would have passed while nothing had loaded.
  The footer renders only when a `PlanWeather` exists.
- Decided: log the error `PlanWeatherView.load()` was discarding. The `catch`
  bound `error` and threw it away, and the app had no logging at all, so a JWT
  refusal and a dropped network rendered the same single string and were
  indistinguishable afterwards. One `Logger` line now attributes the failure from
  the app's own subsystem rather than from WeatherDaemon's.
- Decided: `verify_weatherkit_device.sh` refuses ambiguity rather than picking a
  device. It filters `devicectl` to physical devices and exits if there are zero
  or more than one, then checks pairing and Developer Mode before building. The
  2026-09-01 attempt was lost precisely to an iPad silently standing in for the
  iPhone and then dropping out mid-build.
- Noted: `xcodebuild ... | tail -60` reports the exit status of `tail`, so the
  first device-signing run looked like a success (exit 0) while the log said
  `TEST BUILD FAILED`. Only the text was the observation. Later runs use
  `set -o pipefail`.

### 2026-09-01 (UI test target, zoom clamp, piers, waterbody tier)

- The verify badge is now **observed**, not inferred. `WAFishMapUITests` launches
  the app with `-uiTesting -planMonth 7`, which loads the bundled fixture and
  preselects Boston Harbor, and asserts the badge is on screen. That retires the
  Known-broken entry it had carried since it shipped. Injected taps are not
  involved: the seam preselects the site, which is why this finally worked after
  a session of unreliable tap injection.
- The UI assertions do not hardcode how many species a month flags. The first
  draft did, reimplementing `inSeason(month:)` in the test, and was wrong in both
  directions — 3 badges where it expected 2, 2 where it expected 1. A test that
  restates the rule it checks cannot catch that rule being wrong. It now asserts
  the badge is present and that badges are fewer than species listed: selective,
  not unconditional.
- `.accessibilityIdentifier` on a card *container* collapses it into one
  accessibility element and hides the badge inside. Marking the species name
  instead keeps both queryable. Cost one red run to find.
- Decided: pins stop being drawn past 400km (`MapDetailLevel`) and the density
  overlay is forced on there, because MapKit's clustering declutters collisions
  but has no notion of a badge being unreadable. The legend follows what is
  drawn, not the toggle — a rating legend over a heat map lies.
- Piers are indexed against MPAs where piers load, not in the MPA block: piers
  arrive after that layer, so an index built there would run against an empty
  list and every assertion would pass for the wrong reason.
- NDBC readings are per-field, not per-observation: station 46088's newest row
  carries a wave height and `MM` for water temperature, with the real
  temperature one row older. Each reading keeps its own timestamp. `MM` is
  absence — read as zero it would report flat calm water at freezing.
- Corrected twice on WeatherKit, both times by checking instead of reasoning.
  "Blocked on a paid account" was wrong (the membership is paid); "the
  capability must be enabled by hand in the portal" was also wrong
  (`-allowProvisioningUpdates` enabled it and minted the profile). The live
  fetch still fails on the simulator for an unrelated reason — ad-hoc signing,
  no profile, no JWT — so the feature ships verified at build and unverified at
  runtime, and says so.
- The graphify post-commit hook is installed in all 11 repos that have a graph,
  and new repos get a guarded template hook via `init.templateDir`. Deliberately
  not a global `core.hooksPath`: that overrides every repo's own `.git/hooks`
  and would silently disable the gitleaks and claude-dir-guard hooks in `~/`.
- The freshwater tier gained `byWaterbody` keyed by a curated facility list.
  Substring-matching facility names against waterbody names was rejected — it is
  the same prose-matching guess `NoteScopeTests` exists to prevent.

### 2026-09-01 (camera gestures, protected-area default)

- Decided: `SiteDetailSheet.protectedAreaCheck` defaults to `.unavailable`, not
  `.clear`. `.clear` renders "not in a protected area" for a check that never
  ran, which is a safety claim asserted from the absence of a result. An
  unavailable check must read as unknown.
- `userGesture` guarded on `.began`/`.changed`, states a discrete recognizer
  never enters, so the double-tap and two-finger-tap recognizers were attached
  but could not fire and tap zooms did not count as a user camera move. The
  guard is now `Coordinator.isCameraMove(_:)`, covered by
  `WAFishMapTests/CameraGestureTests.swift`.
- Corrected: that commit extracted the guard and wrote the test but never
  changed the predicate, which still accepted only `.began`/`.changed`. The
  refactor shipped and the fix did not, so tap zooms still went uncounted. The
  commit said in its own message that the suite was unfinished when it landed;
  the run that followed failed on `discreteTapStatesCountAsACameraMove()` and
  the failure sat unread until a stale background task reported it. `.ended` is
  now accepted (`.recognized` is `.ended`), 108 tests in 18 suites pass. A test
  written alongside a fix does not prove the fix is in the commit.
- `appliedSelectionID = nil` moved above the visibility guard in the deselect
  handler. MapKit drops the selection whether or not the pin is on screen, so
  leaving the applied id set meant `syncSelection`'s guard held forever and a
  pin panned back into view never re-highlighted.

### 2026-09-01 (MKMapView migration)

- Decided: migrate the SwiftUI `Map` to a `UIViewRepresentable`-hosted
  `MKMapView`. SwiftUI's Map exposes neither annotation clustering nor tile
  overlays; the hand-rolled grid clustering produced an unreadable badge
  pile-up statewide. Native `clusteringIdentifier` replaced it and the
  scaffolding was deleted (202 lines).
- Decided: no third-party basemap or chart tiles. Esri's ocean basemap is a
  full basemap, not an overlay, so drawing it means hiding Apple's and losing
  the road and ramp labels that get a user to the water. OpenSeaMap composites
  but adds little. Sticking with Apple; depth remains Navionics' job per the
  WA fishing split already in CLAUDE.md. The tile-overlay half of the
  migration's rationale is retired; clustering was the real motivation.
- Found: `anchor.fill` is not an SF Symbol, so every boat-launch pin has drawn
  as a default marker since the first commit (537a292) on both the SwiftUI and
  MapKit paths. Observed by calling `UIImage(systemName:)` on the simulator,
  not by reading docs. `SiteMarkerGlyphTests` now resolves every `Kind` case
  against the real symbol table.
- Found: WDFW layer 4 carries six `TypeOfMPA` values, not the three the plan
  sampled. "Fishing may be prohibited or limited here" is false for
  `Voluntary` (WDFW asks, prohibits nothing) and `Health Closure` (biotoxin,
  different authority), affecting 4 of 44 areas. Wording is now type-dependent
  with a neutral fallback that asserts no rule.


### 2026-09-01 (layered icon, hand-authored)
- The `.icon` bundle is generated by `scripts/make_icon.swift`, not by Icon
  Composer's GUI. Two things I reported earlier were wrong and are corrected
  here: Xcode *does* ship an `icon.json` template (per platform, e.g.
  `iPhoneOS.platform/.../Icon Composer Icon.xctemplate/`) - I had only searched
  inside Icon Composer.app - and there *is* a CLI. Neither the GUI handoff nor
  the schema guesswork was necessary.
- `ictool` renders a bundle to PNG in any appearance and is how to check one
  without a device. It is NOT the same-named shim in `Developer/usr/bin`, which
  rejects the arguments:
  `"/Applications/Xcode-beta.app/Contents/Applications/Icon Composer.app/Contents/Executables/ictool" WAFishMap/WAFishMap.icon --export-image --output-file /tmp/i.png --platform iOS --rendition Default --width 1024 --height 1024 --scale 1`
  Renditions: Default, Dark, TintedLight, TintedDark, ClearLight, ClearDark.
- It landed as **two** vector layers (tail, body) plus a document gradient
  `fill`, not the three SVG layers the task title assumed. The background has to
  be the document fill because only a document fill is substituted for the Dark,
  Tinted and Clear appearances; drawn as a foreground group it rendered the mark
  nearly invisible, which the first ictool render showed outright.
- The eye is a punch-out in `body.svg` (even-odd, eye as a subpath hole) rather
  than a dark layer, so it survives the recoloured appearances. Confirmed on all
  six renditions.
- `AppIcon.appiconset` retired: the `.icon` emits the legacy sizes too
  (`WAFishMap60x60@2x.png` etc.), and Info.plist now carries
  `CFBundleIconName = WAFishMap`. The flat raster moved to `icon/icon_1024.png`,
  outside the app target. `.ios-build/` added to `.gitignore` (2,419 untracked
  files that were never ignored).
- Observed: `Assets.car` in the device build carries the `IconImageStack`,
  both `IconGroup` rows and the Any/Dark/Tintable renditions; the app is
  installed on Daniel's iPhone (iOS 27.0), confirmed by
  `devicectl device info apps`, not by the install log. Still NOT observed: the
  icon on a home screen. Simulator springboard navigation needs injected
  gestures, which remain unreliable here, and DeviceHub exposes no accessibility
  window to drive "View Screen" from a script.

### 2026-09-01 (layered icon layers)
- `scripts/make_icon.swift` now also emits `icon/background.svg`,
  `icon/tail.svg` and `icon/body.svg` from the same constants and the same
  CGPaths as the flat PNG, so the layered icon and `icon_1024.png` cannot
  describe different shapes. The PNG is byte-identical across the change.
- The eye is a punch-out in `body.svg` (even-odd, eye as a subpath hole), not
  its own dark layer: the system recolours foreground layers for the tinted and
  clear appearances, where a dark dot would vanish but a hole still reads.
  Layers are background / tail / body so the system gives the tail its own
  depth instead of the flat icon faking it.
- The script reads the SVGs back, rasterises them through NSImage and asserts
  against the bitmap. First attempt was a check that could not fail: it sampled
  through `svgPlace`, the same transform that drew the file, so removing the
  y-flip moved drawing and sample together and passed. Rewritten to measure the
  drawn bboxes and the *enclosed* transparency, compared against `expectedX`/
  `expectedY` derived from `markBounds`/`scale` rather than the transform.
  Known-bad runs now fail as they should: no flip (eye centre y 520 vs 504),
  no eye subpath ("the eye is filled, not punched through"), swapped gradient
  stops.
- `icon.json` is NOT hand-authored. Its schema is Apple's, undocumented, absent
  from disk, and `icrtool` has no CLI; a guessed document can compile and still
  render wrong. The `.icon` bundle comes from Icon Composer.
- Open: `WAFishMap.icon` not yet assembled, so nothing is wired into the build
  and the app still ships the flat icon.

### 2026-09-01 (app icon)
- The icon had no vector source - only a hand-made PNG from 4edb1e1 - so the
  three known defects (tail meeting the body at a point, mark off-centre, eye
  half outside the head) were unfixable without redrawing it. Added
  `scripts/make_icon.swift`, which draws the mark with CoreGraphics and
  regenerates icon_1024.png. Swift over an SVG pipeline because this Mac has no
  rasterizer (rsvg/inkscape/magick/cairosvg all absent) while the Xcode
  toolchain is already required.
- Composition is derived, not nudged: one transform centres the union bbox of
  body+tail on the canvas at 62% width. The tail's apex sits 145pt *inside* the
  body, so the two white fills merge instead of touching.
- The script checks its own bitmap before writing and exits non-zero on
  failure: a ring outside the eye must be all body, a flood fill from the tail
  must reach the nose, and the mark's bbox must be centred at the intended
  width. Each check was exercised against a known-bad input (eye pushed out,
  overlap negative, transform offset, width 80%) and observed to fail, and
  against the good geometry and observed to pass.
- Still open: the layered OS27 icon (3 SVG layers, Icon Composer) is a separate
  item and needs vector layers this script does not emit.

### 2026-09-01 (waterbody-scoped notes)
- Executed the waterbody-scoped-notes plan: NoteScopeTests gate committed
  failing (b630fa7), data fixed (d26c4ca), rule recorded in CLAUDE.md
  (82ac5e7). The gate caught 16 offenders, not the 2 the plan expected - the
  whole 2026-08-30 county seed named its waterbodies.
- Reworded 14 county notes to county-true prose; removed 4 entries instead:
  Chelan/Snohomish/Whatcom Kokanee (duplicated the statewide default once the
  lake name was gone; the county merge inherits it) and Whatcom Sockeye (only
  true of Baker Lake - out of the file until a waterbody tier exists; the
  seasonRisk "Sockeye" row stays for its return).
- Widened the gate regex with "Woods" (Rufus Woods slipped it); "Potholes"
  cannot be prose-matched, fixed as data, noted in CLAUDE.md.
- Grant walleye rewording tripped the date-guard by reintroducing
  "(spawn is Apr-May)" from an older text - the guard works; date dropped.


### 2026-08-31 (species-first)
- Decided: recolor, do not hide. Exact name match. Reuse the date picker.

### 2026-08-31 (marker clustering)
- Decided: keep the heat toggle. Clusters replace overlapping pins, not the wash.
- Decided: same lon/lat grid as heat, tap zooms into the cell, color is the
  best rating in the cell. No MKMapView rewrite.

### 2026-08-31 (tide predictions)
- Decided: day's high/low table, not live stage. The map already has a plan date;
  live height fights a future Saturday.
- Decided: nearest bundled NOAA station (170 WA + Columbia-mouth), not a runtime
  catalog (`state=WA` is ignored and returns 3,500 US stations) and not one
  station per marine area (wrong at the edges).
- Decided: marine only, fail open, same "not a tide book" posture as WDFW.

### 2026-08-31 (season/closure + map design)
- Decided: cap, do not hide. A closure-prone species keeps its card and its
  place in "Biting now" but cannot reach Prime. Hiding it would cost the user
  the information that sends them to WDFW.
- Decided: cap only in flagged months, not blanket per species, so a fishery
  reliably open at its peak still reaches Prime.
- Decided: curate centrally by species name, not `verifyMonths` on all 134 rows.
  Substring matching knowingly over-flags (Lingcod, Crab, Coho, Sockeye,
  Chinook); over-flagging is the safe direction for a "verify" signal, and
  `"seasonRisk": "none"` is the per-row escape hatch.
- Decided: the rating ramp is thermal (blue → amber → orange → red) as four
  explicit stops. Sampling a blue-to-red line ran the midtones through magenta,
  which reads as a different scale and put Good and Prime adjacent in the
  reddest stretch.
- Decided: the heat overlay draws real grid cells, not circles. Circles 10-28km
  across in an 11.3km cell had to overlap, and translucent overlap composites
  rather than maxes, so two mediocre neighbours out-darkened one hot cell — the
  layer encoded how many cells held data. Diagnosis came from a peer session and
  its arithmetic was verified against the source here.
- Decided: rank each cell against the others instead of normalising to the
  densest. One outlier crushed every ordinary cell to the floor.
- Decided: mute the basemap while heat is on. A translucent fill takes its
  colour from what is under it, so one band read pink over city, brown over
  forest, violet over water. Hue-shifting the bands compensated and looked
  garish; draining the ground fixed the cause.
- Decided: the Stop-hook auto-commit is off. It swept unreviewed work into
  commits and pushed them three times in one session, each under a generic
  fallback message. `~/bin/auto-commit.sh` stays on disk; `auto-push.sh` still
  runs.

Older entries: [STATUS-ARCHIVE.md](STATUS-ARCHIVE.md).
