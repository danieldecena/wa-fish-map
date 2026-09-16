# MKMapView Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development
> (recommended) or superpowers:executing-plans to implement this plan task-by-task.
> Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Host `MKMapView` in a `UIViewRepresentable` so the app can use MapKit's
own collision-based annotation clustering, and so a chart tile overlay becomes
possible at all.

**Architecture:** `FishingMapView` keeps its chrome, state and sheets exactly as
they are; only the `Map { }` block is replaced by a `FishingMapRepresentable`.
Every annotation becomes an `MKAnnotation` class, every polygon an `MKOverlay`,
and a `Coordinator` implements `MKMapViewDelegate`. Migration is strangler-style:
the representable lands behind a flag, is proven equivalent, then the SwiftUI
`Map` is deleted.

**Tech Stack:** Swift 5, SwiftUI, MapKit (`MKMapView`, `MKAnnotationView`,
`MKClusterAnnotation`, `MKPolygonRenderer`, `MKTileOverlay`), swift-testing.
Xcode 27, iOS 27 simulator, deployment target 18.0.

**Spec:** none. Derived from `docs/superpowers/plans/2026-09-01-post-icon-improvements.md`,
`STATUS.md`, and observations recorded 2026-09-01.

## Global Constraints

- `IPHONEOS_DEPLOYMENT_TARGET = 18.0`.
- Guidance stays editorial: disclaimer plus `wdfwURL` on every screen showing it.
- **An auto-commit hook is active on this repo.** It committed and pushed working
  tree changes mid-session on 2026-09-01 (`a5a6561`, `e99b97e`). Commit early and
  deliberately; do not leave a slice dirty.
- Drive the simulator without gestures — injected taps have repeatedly failed
  here and twice opened menus over the user's own windows:
  ```bash
  SIM=2575FFC9-DAEA-407E-ADEF-810F39558E3C
  xcrun simctl privacy $SIM grant location com.danieldecena.WAFishMap
  xcrun simctl location $SIM set 47.6062,-122.3321
  xcrun simctl launch $SIM com.danieldecena.WAFishMap
  xcrun simctl io $SIM screenshot /tmp/shot.png
  ```
  Pass the destination by **id**, not by name — `name=iPhone 17 Pro` stopped
  resolving mid-session and xcodebuild fell back to My Mac.

## Why this migration, and what is NOT established

**Established by observation:** SwiftUI's `Map` exposes neither annotation
clustering nor tile overlays (`home-domain-reference`, and no such API exists on
`Map`). The cluster badges hand-rolled to work around this quantised onto a grid
lattice, and after that was fixed (`e99b97e`) they pile into an unreadable mass
at continental zoom — screenshotted 2026-09-01.

**NOT established:** that NOAA chart tiles are reachable. Probed 2026-09-01:

```
apple.com                      200
WDFW ArcGIS                    200
NOAA tides API                 200
tileservice.charts.noaa.gov    000  (timeout)
gis.charts.noaa.gov            000  (timeout)
```

Network is fine; those two hosts do not answer from this machine. Whether the
service moved, was retired, or is blocked locally is unknown. **Task 6 must
resolve a working tile URL before any tile code is written.** If no URL
resolves, this migration delivers clustering only — which is still worth it, but
say so rather than shipping an overlay pointed at a dead host.

## File structure

| File | Responsibility |
|---|---|
| `WAFishMap/Map/SiteAnnotation.swift` | `MKAnnotation` classes for sites, piers, area labels |
| `WAFishMap/Map/FishingMapRepresentable.swift` | `UIViewRepresentable` + `Coordinator: MKMapViewDelegate` |
| `WAFishMap/Map/AnnotationViews.swift` | `MKAnnotationView` subclasses, incl. the cluster view |
| `WAFishMap/FishingMapView.swift` | unchanged chrome, state, sheets; `Map {}` swapped for the representable |

Four new files rather than one, because `FishingMapView.swift` is already 530
lines and absorbing the delegate would push it past what can be held in context.

---

### Task 1: Annotation model

**Files:**
- Create: `WAFishMap/Map/SiteAnnotation.swift`
- Test: `WAFishMapTests/SiteAnnotationTests.swift`

**Interfaces:**
- Consumes: `AccessSite`, `FishingPier`, `MarineArea`, `FishingRating`, `LonLat`.
- Produces:
  ```swift
  final class SiteAnnotation: NSObject, MKAnnotation {
      let id: String                       // matches model.selectedSiteID
      let coordinate: CLLocationCoordinate2D
      let title: String?
      let rating: FishingRating?
      let kind: Kind                       // .launch, .shore, .pier
      enum Kind { case launch, shore, pier }
  }
  ```

`MKAnnotation` requires `NSObject` and a `coordinate` property; it cannot be a
struct. `id` is what the delegate hands back to `model.selectedSiteID`, so it
must equal `AccessSite.id` / `FishingPier.id` exactly.

- [ ] **Step 1: Write the failing test**

```swift
import MapKit
import Testing
@testable import WAFishMap

struct SiteAnnotationTests {
    @Test func anAnnotationCarriesItsSiteIdentityUnchanged() {
        let site = AccessSite(
            facilityName: "Boston Harbor", countyName: "Thurston",
            hasLaunch: true, launchSurface: .concrete, hasRestrooms: true,
            hasCamping: false, ada: .unknown, openDates: "", publicNotes: "",
            directions: "", coordinate: LonLat(longitude: -122.90, latitude: 47.10)
        )
        let a = SiteAnnotation(site: site, rating: .excellent)
        #expect(a.id == site.id)
        #expect(a.title == "Boston Harbor")
        #expect(a.kind == .launch)
        #expect(abs(a.coordinate.latitude - 47.10) < 0.0001)
    }
}
```

- [ ] **Step 2: Run it**

```bash
xcodebuild test -project WAFishMap.xcodeproj -scheme WAFishMap \
  -destination 'platform=iOS Simulator,id=2575FFC9-DAEA-407E-ADEF-810F39558E3C' \
  -derivedDataPath .ios-build -only-testing:WAFishMapTests/SiteAnnotationTests
```
Expected: compile failure, `SiteAnnotation` undefined. If the `AccessSite`
initialiser above does not match, read `WAFishMap/Models/AccessSite.swift:25-39`
and fix the test's call before touching production code.

- [ ] **Step 3: Implement `SiteAnnotation`**

- [ ] **Step 4: Run, expect PASS**

- [ ] **Step 5: Commit**

```bash
git commit -- WAFishMap/Map/SiteAnnotation.swift WAFishMapTests/SiteAnnotationTests.swift \
  -m "feat: MKAnnotation model for sites and piers"
```

---

### Task 2: The representable, with clustering

This is the task the whole migration exists for. `clusteringIdentifier` is what
SwiftUI's `Map` cannot do: MapKit groups annotations that visually collide and
places the cluster at its members' mean, which is why Apple Maps never shows a
lattice.

**Files:**
- Create: `WAFishMap/Map/FishingMapRepresentable.swift`
- Create: `WAFishMap/Map/AnnotationViews.swift`
- Modify: `WAFishMap/FishingMapView.swift:86-127` (replace the `Map {}` block)

**Interfaces:**
- Consumes: `SiteAnnotation` (Task 1), and from `FishingMapView`:
  `model.accessSites`, `model.piers`, `model.marineAreas`, `heatZones`,
  `$model.selectedSiteID`, `$cameraDistance`, `$cameraCenter`,
  `$userMovedCamera`, `showHeat`.
- Produces:
  ```swift
  struct FishingMapRepresentable: UIViewRepresentable {
      let annotations: [SiteAnnotation]
      let areas: [MarineArea]
      let heatZones: [HeatZone]
      let showHeat: Bool
      @Binding var selectedID: String?
      @Binding var cameraDistance: Double
      @Binding var cameraCenter: LonLat
      @Binding var userMovedCamera: Bool
  }
  ```

- [ ] **Step 1: Register the cluster identifier**

In `makeUIView`, register both view classes and set the identifier on each
annotation view. MapKit clusters only annotations whose views share it:

```swift
mapView.register(SiteMarkerView.self,
                 forAnnotationViewWithReuseIdentifier: MKMapViewDefaultAnnotationViewReuseIdentifier)
mapView.register(SiteClusterView.self,
                 forAnnotationViewWithReuseIdentifier: MKMapViewDefaultClusterAnnotationViewReuseIdentifier)
```

```swift
final class SiteMarkerView: MKMarkerAnnotationView {
    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        clusteringIdentifier = "site"   // the whole point of the migration
        displayPriority = .defaultLow   // let MapKit declutter rather than overdraw
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}
```

- [ ] **Step 2: Draw the polygons**

Marine areas and heat cells become `MKPolygon` overlays rendered by the
coordinator. Keep the existing colours so the diff is behavioural, not visual:

```swift
func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
    let r = MKPolygonRenderer(overlay: overlay)
    if let tagged = overlay as? RatedPolygon {
        r.fillColor = UIColor(tagged.color.opacity(0.12))
        r.strokeColor = UIColor(tagged.color.opacity(0.35))
        r.lineWidth = 0.75
    }
    return r
}
```

- [ ] **Step 3: Wire selection back to `selectedSiteID`**

The existing sheets key off `model.selectedSiteID`, so the delegate must set
exactly that and nothing else:

```swift
func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
    if let cluster = view.annotation as? MKClusterAnnotation {
        mapView.setRegion(cluster.boundingRegion(padding: 1.4), animated: true)
        parent.userMovedCamera = true
        return
    }
    parent.selectedID = (view.annotation as? SiteAnnotation)?.id
}

func mapView(_ mapView: MKMapView, didDeselect view: MKAnnotationView) {
    parent.selectedID = nil
}
```

Tapping a cluster zooms in, replacing `zoomToCluster` at
`FishingMapView.swift:258-266`. `boundingRegion` comes from the cluster's real
members, so the zoom frames the actual sites rather than a grid cell.

- [ ] **Step 4: Port the camera guard, and simplify it**

`regionDidChangeAnimated` reports `animated`, and `mapView.subviews.first?
.gestureRecognizers` can be inspected, but the reliable signal is simpler: attach
a `UIPanGestureRecognizer` and a `UIPinchGestureRecognizer` with
`delegate.gestureRecognizer(_:shouldRecognizeSimultaneouslyWith:)` returning
true, and set `userMovedCamera = true` from their handlers. That is a real touch,
so the three-phase `CameraGuardPhase` machine at `FishingMapView.swift:38-56` and
its disclosed residual can both be deleted. Delete them in this step, not later.

- [ ] **Step 5: Swap it in**

Replace the `Map {}` block. Leave `.safeAreaInset`, `.overlay`, `.task`,
`.onChange` and both `AdaptiveDetail` modifiers untouched — they attach to
whatever view is there.

- [ ] **Step 6: Prove equivalence before deleting anything else**

Run the full suite (85 tests, 14 suites), then screenshot at three zooms using
the gesture-free recipe: continental, regional, and metro. Compare against the
2026-09-01 captures. Required: no lattice, no continental pile-up, tapping a pin
still opens the right sheet, marine-area fills unchanged.

- [ ] **Step 7: Commit**

```bash
git commit -- WAFishMap/Map WAFishMap/FishingMapView.swift \
  -m "feat: host MKMapView so MapKit does the clustering"
```

---

### Task 3: Delete the hand-rolled clustering

Only after Task 2 is observed working. `HeatMap.clusters`, `MapCluster`,
`ClusterMark`, `pinClusters` and `MapClusterTests` all exist to work around an
API gap that no longer applies.

**Files:**
- Modify: `WAFishMap/Models/HeatZone.swift` (remove `MapCluster` and `HeatMap.clusters`)
- Modify: `WAFishMap/FishingMapView.swift` (remove `pinClusters`, `clusterAnnotation`, `zoomToCluster`, `pinDetailMaxDistance`)
- Delete: `WAFishMapTests/MapClusterTests.swift`

Keep `HeatMap.zones` and `HeatMapTests` — the heat overlay is unrelated and still
uses the grid.

- [ ] **Step 1: Delete, then run the suite**

Expected: green, minus the 7 `MapClusterTests` cases. If anything else fails, the
migration is not equivalent and Task 2 is not done.

- [ ] **Step 2: Commit**

```bash
git commit -m "refactor: drop hand-rolled clustering, MapKit does it now"
```

---

### Task 4: WDFW Marine Protected Areas overlay

**This does not need the migration and is worth more than it.** Verified live
2026-09-01: the MapServer the app already queries exposes 7 layers and the app
uses 3. Layer 4 is 44 Marine Protected Areas with WAC citations.

```
GET .../MajorFishingArea/MapServer/4/query?where=1=1&returnCountOnly=true  → {"count":44}
Admiralty Head        | Marine Preserve    | WAC 220-302-010
Bracketts Landing     | Conservation Area  | WAC 220-303-010
Golden Gardens        | Marine Preserve    | WAC 220-302-060
City of Des Moines Park | Conservation Area | WAC 220-303-020
```

WDFW's own description: *"Areas where WDFW may prohibit (Conservation Areas) or
limit (Marine Preserves) fishing and/or shellfishing activity."* Today the app
will happily rate a launch inside one of these **Prime** with no indication. That
is a correctness gap the disclaimer does not cover.

This stays inside `CLAUDE.md`'s "Not this app" boundary: an MPA polygon is
**geography**, which is what this app is, not a season or a bag limit. Render the
polygon and the name, cite the WAC, link `DetailedInfoURL`, and let WDFW state
the rule.

**Files:**
- Create: `WAFishMap/Models/ProtectedArea.swift`
- Modify: `WAFishMap/Models/MapScope.swift` (add the layer-4 URL beside the existing three)
- Modify: `WAFishMap/Services/FishingMapModel.swift` (load and index, mirroring `indexSitesToAreas`)
- Modify: `WAFishMap/SiteDetailSheet.swift` (a warning row when a site falls inside one)
- Test: `WAFishMapTests/ProtectedAreaTests.swift`
- Modify: `scripts/verify_wdfw_live.py` (assert the layer and its count, as it already does for layers 0, 1 and 6)

**Interfaces:**
- Produces:
  ```swift
  struct ProtectedArea: Identifiable, Equatable, Sendable {
      let id: String          // MPA_Name
      let name: String        // MPA_Name
      let type: String        // TypeOfMPA: "Marine Preserve" | "Conservation Area" | "Octopus Preserve"
      let wac: String         // "WAC 220-302-010"
      let detailURL: URL?     // DetailedInfoURL
      let polygon: [LonLat]
      func contains(_ point: LonLat) -> Bool   // same ray-cast as MarineArea.contains
  }
  ```

- [ ] **Step 1: Write the failing test**

```swift
@Test func aPointInsideAProtectedAreaIsFlagged() {
    let square = [
        LonLat(longitude: -122.40, latitude: 47.60),
        LonLat(longitude: -122.30, latitude: 47.60),
        LonLat(longitude: -122.30, latitude: 47.70),
        LonLat(longitude: -122.40, latitude: 47.70),
    ]
    let mpa = ProtectedArea(id: "Golden Gardens", name: "Golden Gardens",
                            type: "Marine Preserve", wac: "WAC 220-302-060",
                            detailURL: nil, polygon: square)
    #expect(mpa.contains(LonLat(longitude: -122.35, latitude: 47.65)))
    #expect(!mpa.contains(LonLat(longitude: -122.00, latitude: 47.65)))
}
```

- [ ] **Step 2: Run it, expect a compile failure**

- [ ] **Step 3: Implement `ProtectedArea`**

Reuse the ray-casting in `WAFishMap/Models/MarineArea.swift:26-41` rather than
writing a second point-in-polygon. If that means extracting it to a shared free
function, do that — two copies of this is how they drift.

- [ ] **Step 4: Load layer 4 and index sites against it**

Mirror `FishingMapModel.indexSitesToAreas` exactly, including the truncation
guard the app already applies to ArcGIS responses.

- [ ] **Step 5: Show it in the sheet**

Above "What's biting", so it is read before the guidance it qualifies:

```swift
if let mpa = protectedArea {
    VStack(alignment: .leading, spacing: 4) {
        Label("Inside \(mpa.name)", systemImage: "exclamationmark.shield")
            .font(.subheadline.weight(.semibold))
        Text("\(mpa.type) — \(mpa.wac). Fishing or shellfishing may be prohibited or limited here.")
            .font(.caption)
        if let url = mpa.detailURL {
            Link("WDFW details", destination: url).font(.caption)
        }
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.orange.opacity(0.14), in: RoundedRectangle(cornerRadius: 10))
}
```

- [ ] **Step 6: Run the suite, then observe on the simulator**

Set the location to Golden Gardens (`47.6899,-122.4030`) with the gesture-free
recipe and confirm the warning renders on a site inside it.

- [ ] **Step 7: Commit**

```bash
git commit -m "feat: flag sites inside WDFW Marine Protected Areas"
```

---

### Task 5: Chart tiles — probe first, build only if a URL resolves

- [ ] **Step 1: Find a working tile endpoint, or stop**

```bash
for u in \
  "https://tileservice.charts.noaa.gov/tiles/50000_1/12/655/1430.png" \
  "https://gis.charts.noaa.gov/arcgis/rest/services/MCS/NOAAChartDisplay/MapServer?f=json" \
  "https://services.arcgisonline.com/ArcGIS/rest/services/Ocean/World_Ocean_Base/MapServer?f=json" ; do
  printf "%-72s " "$u"; curl -s -o /dev/null -w "%{http_code}\n" "$u" --max-time 15
done
```

A 200 with real bytes is the only thing that authorises Step 2. **If every
candidate fails, stop here, write the result into `STATUS.md`, and close the
task.** Do not write `MKTileOverlay` code against a host that has not answered —
a tile overlay pointed at a dead endpoint renders as a blank map with no error,
which is indistinguishable from a bug in your own code.

- [ ] **Step 2 (only on a 200): add the overlay**

```swift
let overlay = MKTileOverlay(urlTemplate: RESOLVED_URL)
overlay.canReplaceMapContent = false          // chart over Apple's basemap, not instead of it
mapView.addOverlay(overlay, level: .aboveRoads)
```
Return an `MKTileOverlayRenderer` from the existing `rendererFor` delegate method,
before the `MKPolygonRenderer` branch.

- [ ] **Step 3: Attribute it and mark it not-for-navigation**

Required, and not optional politeness: chart data carries attribution terms, and
a chart shown without "not for navigation" invites exactly the misuse the depth
discussion ruled out.

- [ ] **Step 4: Commit**

## Verification

1. `xcodebuild test -project WAFishMap.xcodeproj -scheme WAFishMap -destination 'platform=iOS Simulator,id=2575FFC9-DAEA-407E-ADEF-810F39558E3C' -derivedDataPath .ios-build` — 85 tests in 14 suites today; must stay green minus the 7 deliberately deleted in Task 3.
2. `python3 scripts/verify_wdfw_live.py` after Task 4 — it must assert layer 4 the way it already asserts 0, 1 and 6.
3. Screenshots at continental, regional and metro zoom via the gesture-free recipe. A green build says nothing about whether the map looks right; that was true of the icon and it is true here.
4. **The migration's success criterion is the continental screenshot**: badges that declutter instead of piling up. If that is not visibly better than the 2026-09-01 capture, the migration failed and should be reverted rather than tuned.
