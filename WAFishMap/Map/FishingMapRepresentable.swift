import MapKit
import SwiftUI

/// An `MKPolygon` that carries the colour it should be drawn in. The renderer is
/// a delegate callback with no access to the model, so the tint rides along.
final class RatedPolygon: MKPolygon {
    var color: Color = .gray
    /// Heat cells are a solid density fill; marine areas are a translucent fill
    /// with a hairline stroke. One flag keeps both in a single overlay class.
    var isHeat = false
}

/// A river reach. Lines, not fills, so it needs its own class and its own
/// renderer branch — everything else on this map is a polygon. Carries its tint
/// and weight for the same reason `RatedPolygon` does: the renderer is a
/// delegate callback with no model access.
final class RiverPolyline: MKPolyline {
    var color: Color = .gray
    var width: CGFloat = 1.0
}

/// A Marine Protected Area boundary. Geography, not a rating — its own class so
/// the renderer can draw it as a dashed outline rather than a rated fill. The
/// name rides on `MKShape.title`, which is what MapKit reads out.
final class ProtectedAreaPolygon: MKPolygon {}

/// Hosts `MKMapView` so MapKit can do collision-based clustering, which SwiftUI's
/// `Map` does not expose. Everything the `Map {}` block drew is reproduced here:
/// marine-area polygons, "MA n" labels, heat cells, site/pier pins, the user dot.
struct FishingMapRepresentable: UIViewRepresentable {
    let annotations: [SiteAnnotation]
    /// Every site, drawn or not. The opening camera frames these: at the far
    /// zoom the map starts at, the detail level hides all pins, so `annotations`
    /// is empty exactly when the fit is needed.
    let fitAnnotations: [SiteAnnotation]
    let areas: [MarineArea]
    /// Rating colour per `MarineArea.id`; the polygon fill/stroke.
    let areaColors: [String: Color]
    /// WDFW Marine Protected Area boundaries; drawn under the marine-area fills.
    let protectedAreas: [ProtectedArea]
    let heatZones: [HeatZone]
    let rivers: [River]
    /// Rating colour per `River.id`. Empty in the geometry-only build, so every
    /// river falls to neutral gray — the colour that already means "no rating
    /// available" on an inland launch, not a placeholder.
    let riverColors: [String: Color]
    let showRivers: Bool
    let showHeat: Bool
    let showAreaLabels: Bool
    let pointsOfInterest: [MKPointOfInterestCategory]
    @Binding var selectedID: String?
    /// The tapped river, by name. Overlays are not selectable the way
    /// annotations are, so this is driven by an explicit hit test.
    @Binding var selectedRiverName: String?
    @Binding var cameraDistance: Double
    @Binding var cameraCenter: LonLat
    @Binding var userMovedCamera: Bool
    /// A one-shot camera move requested by the view (the recentre-on-fix ease).
    /// The coordinator applies it and clears it.
    @Binding var focusRegion: MKCoordinateRegion?

    /// Washington's bounding box (45.5-49.1 N, 124.9-116.9 W), the same box
    /// `FishingMapView` uses to decide whether a location fix is in the state.
    static let washington = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 47.3, longitude: -120.9),
        span: MKCoordinateSpan(latitudeDelta: 3.6, longitudeDelta: 8.0))
    /// Camera altitude, in metres, at which the whole state still fits a phone
    /// held upright. Tuned by eye on an iPhone 17 Pro simulator.
    static let maxCameraDistance: CLLocationDistance = 3_200_000

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        mapView.showsCompass = true
        mapView.showsScale = false
        // The data is Washington only, so the camera is too: it cannot centre
        // outside the state or pull back past a statewide view. Zooming in is
        // unrestricted. The region is set first: MapKit's default world camera
        // sits outside the boundary and gets clamped to the box's corner, which
        // opened the app on the Idaho line.
        mapView.setRegion(Self.washington, animated: false)
        mapView.cameraBoundary = MKMapView.CameraBoundary(coordinateRegion: Self.washington)
        mapView.setCameraZoomRange(
            MKMapView.CameraZoomRange(maxCenterCoordinateDistance: Self.maxCameraDistance), animated: false)
        mapView.register(SiteMarkerView.self,
                         forAnnotationViewWithReuseIdentifier: MKMapViewDefaultAnnotationViewReuseIdentifier)
        mapView.register(SiteClusterView.self,
                         forAnnotationViewWithReuseIdentifier: MKMapViewDefaultClusterAnnotationViewReuseIdentifier)
        mapView.register(AreaLabelView.self,
                         forAnnotationViewWithReuseIdentifier: Coordinator.areaLabelReuseID)

        // A real touch is the only reliable "the user moved the camera" signal;
        // `regionDidChangeAnimated` cannot tell a gesture from a programmatic fit.
        // Double-tap (zoom in) and two-finger tap (zoom out) are camera moves too;
        // without them a user who zoomed by tapping was still yanked by a late fix.
        let doubleTap = UITapGestureRecognizer(target: context.coordinator,
                                               action: #selector(Coordinator.userGesture))
        doubleTap.numberOfTapsRequired = 2

        // A river is an overlay, and MapKit only selects annotations, so
        // tap-to-open is hand-rolled. Deliberately NOT wired to `userGesture`:
        // selecting a river is not a camera move, and marking it as one would
        // suppress the recentre-on-fix the user has not opted out of.
        let riverTap = UITapGestureRecognizer(target: context.coordinator,
                                              action: #selector(Coordinator.riverTap(_:)))
        riverTap.delegate = context.coordinator
        riverTap.require(toFail: doubleTap)
        mapView.addGestureRecognizer(riverTap)
        let twoFingerTap = UITapGestureRecognizer(target: context.coordinator,
                                                  action: #selector(Coordinator.userGesture))
        twoFingerTap.numberOfTouchesRequired = 2
        for recognizer in [UIPanGestureRecognizer(target: context.coordinator,
                                                  action: #selector(Coordinator.userGesture)),
                           UIPinchGestureRecognizer(target: context.coordinator,
                                                    action: #selector(Coordinator.userGesture)),
                           doubleTap,
                           twoFingerTap] as [UIGestureRecognizer] {
            // Recognize alongside MapKit's own so the zoom itself still happens.
            recognizer.delegate = context.coordinator
            mapView.addGestureRecognizer(recognizer)
        }
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.syncConfiguration(mapView)
        context.coordinator.syncOverlays(mapView)
        context.coordinator.syncRivers(mapView)
        context.coordinator.syncAnnotations(mapView)
        context.coordinator.syncSelection(mapView)
        context.coordinator.applyFocusRegionIfNeeded(mapView)
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, MKMapViewDelegate, UIGestureRecognizerDelegate {
        static let areaLabelReuseID = "areaLabel"
        var parent: FishingMapRepresentable
        private var areaSignature: String?
        private var heatSignature: String?
        private var areaOverlays: [MKOverlay] = []
        private var mpaSignature: String?
        private var mpaOverlays: [MKOverlay] = []
        private var heatOverlays: [MKOverlay] = []
        private var riverSignature: String?
        private var riverOverlays: [MKOverlay] = []
        private var annotationSignature: String?
        private var labelSignature: String?
        private var emphasisIsMuted: Bool?
        private var hasDoneInitialFit = false
        /// The selection id this coordinator last pushed into the map. Reading it
        /// back off `selectedAnnotations` does not work: a clustered member is not
        /// in that array, so the guard never held and every update churned.
        private var appliedSelectionID: String?
        /// Set once a requested camera move has been handed to MapKit. The initial
        /// auto-fit is skipped from then on.
        private(set) var hasAppliedFocusRegion = false
        /// Guards the selection round-trip: applying the binding to the map must
        /// not read back as a fresh user selection.
        private var isSyncingSelection = false

        init(_ parent: FishingMapRepresentable) { self.parent = parent }

        // MARK: Configuration

        func syncConfiguration(_ mapView: MKMapView) {
            // Two layers want the basemap drained, for two reasons. The heat cells
            // are translucent fills that took their apparent colour from whatever
            // sat under them — one density band read as three colours. Rivers want
            // it so fresh water is the brightest thing on screen rather than
            // competing with Apple's own blue.
            let muted = parent.showHeat || parent.showRivers
            guard emphasisIsMuted != muted else { return }
            emphasisIsMuted = muted
            let config = MKStandardMapConfiguration(
                emphasisStyle: muted ? .muted : .default
            )
            config.pointOfInterestFilter = MKPointOfInterestFilter(including: parent.pointsOfInterest)
            mapView.preferredConfiguration = config
        }

        // MARK: Overlays

        /// The pieces a ring group needs to build an `MKPolygon` with
        /// `interiorPolygons` wired in, so a genuine hole renders as a cutout
        /// rather than an opaque fill. `nil` when the outer ring is degenerate.
        /// Shared by the marine-area and protected-area overlay builders below —
        /// they differ only in the concrete `MKPolygon` subclass they construct.
        private static func overlayGeometry(
            for group: LonLat.RingGroup
        ) -> (outer: [CLLocationCoordinate2D], holes: [MKPolygon])? {
            guard group.outer.count > 2 else { return nil }
            let interior = group.holes.compactMap { hole -> MKPolygon? in
                guard hole.count > 2 else { return nil }
                let coords = hole.map(\.clLocationCoordinate)
                return MKPolygon(coordinates: coords, count: coords.count)
            }
            return (group.outer.map(\.clLocationCoordinate), interior)
        }

        /// Two independent overlay sets. They were one, and because the heat
        /// zones are recomputed at every camera-distance band, a zoom that
        /// crossed a band tore down and re-added the marine-area polygons too —
        /// a visible flash of the fills mid-zoom.
        func syncOverlays(_ mapView: MKMapView) {
            // Protected areas are geography and sit under the rated fills.
            let mpaKey = parent.protectedAreas.map(\.id).joined(separator: "|")
            var mpaRebuilt = false
            if mpaKey != mpaSignature {
                mpaSignature = mpaKey
                mpaRebuilt = true
                mapView.removeOverlays(mpaOverlays)
                // One polygon per outer ring, not just the largest, so a
                // multi-part protected area (islands, disjoint pieces) actually
                // all draws — with its holes cut out rather than filled solid.
                mpaOverlays = parent.protectedAreas.flatMap { mpa in
                    mpa.ringGroups.compactMap { group -> ProtectedAreaPolygon? in
                        guard let geometry = Self.overlayGeometry(for: group) else { return nil }
                        let polygon = ProtectedAreaPolygon(coordinates: geometry.outer, count: geometry.outer.count,
                                                            interiorPolygons: geometry.holes.isEmpty ? nil : geometry.holes)
                        polygon.title = mpa.name
                        return polygon
                    }
                }
                mapView.addOverlays(mpaOverlays, level: .aboveRoads)
            }

            let areaKey = parent.areas
                .map { "\($0.id):\(parent.areaColors[$0.id].map(String.init(describing:)) ?? "-")" }
                .joined(separator: "|")
            // Within a level MapKit draws in add order, so an MPA set that arrived
            // after the fills would cover them. Re-adding the fills restores the
            // stack without touching the heat cells (a level above).
            if areaKey != areaSignature || (mpaRebuilt && !areaOverlays.isEmpty) {
                if areaKey != areaSignature {
                    areaSignature = areaKey
                    mapView.removeOverlays(areaOverlays)
                    // One polygon per outer ring, not just the largest — a
                    // marine area packs every island and disjoint part into
                    // extra rings, with its holes cut out rather than filled solid.
                    areaOverlays = parent.areas.flatMap { area in
                        area.ringGroups.compactMap { group -> RatedPolygon? in
                            guard let geometry = Self.overlayGeometry(for: group) else { return nil }
                            let polygon = RatedPolygon(coordinates: geometry.outer, count: geometry.outer.count,
                                                       interiorPolygons: geometry.holes.isEmpty ? nil : geometry.holes)
                            polygon.color = parent.areaColors[area.id] ?? .gray
                            return polygon
                        }
                    }
                } else {
                    mapView.removeOverlays(areaOverlays)
                }
                mapView.addOverlays(areaOverlays, level: .aboveRoads)
            }

            let heatKey = parent.heatZones.map { "\($0.id):\($0.intensity)" }.joined(separator: ",")
            if heatKey != heatSignature {
                heatSignature = heatKey
                mapView.removeOverlays(heatOverlays)
                heatOverlays = parent.heatZones.map { zone in
                    let coords = zone.corners.map(\.clLocationCoordinate)
                    let polygon = RatedPolygon(coordinates: coords, count: coords.count)
                    polygon.color = ColorRamp.densityFill(zone.intensity)
                    polygon.isHeat = true
                    return polygon
                }
                // A level of its own: order inside a level is add order, so at the
                // same level a recolour of the fills re-added them over the heat.
                mapView.addOverlays(heatOverlays, level: .aboveLabels)
            }
        }

        /// Separate from `syncOverlays` for the same reason the heat cells are:
        /// rivers change only when the toggle or the colouring does, and folding
        /// them in would rebuild them on every camera-distance band change.
        /// Fingertip tolerance. Points, converted to metres at the current zoom
        /// so the target stays the same size on screen however far out the
        /// camera is — a fixed metre radius is untappable statewide and
        /// swallows the whole basin up close.
        private static let tapTolerancePoints: CGFloat = 22

        @objc func riverTap(_ recognizer: UITapGestureRecognizer) {
            guard parent.showRivers, !parent.rivers.isEmpty,
                  let mapView = recognizer.view as? MKMapView else { return }
            let point = recognizer.location(in: mapView)

            // A pin on top of a river belongs to the pin. MapKit's own selection
            // handles that, and stealing the tap would make pins unopenable
            // wherever they sit near water — which is everywhere here.
            if let hit = mapView.hitTest(point, with: nil),
               hit is MKAnnotationView || hit.superview is MKAnnotationView { return }

            let tapped = mapView.convert(point, toCoordinateFrom: mapView)
            let offset = mapView.convert(
                CGPoint(x: point.x + Self.tapTolerancePoints, y: point.y),
                toCoordinateFrom: mapView
            )
            let tolerance = MKMapPoint(tapped).distance(to: MKMapPoint(offset))
            let target = LonLat(longitude: tapped.longitude, latitude: tapped.latitude)

            let nearest = parent.rivers
                .compactMap { river -> (String, Double)? in
                    guard let distance = river.distanceMeters(to: target) else { return nil }
                    return (river.name, distance)
                }
                .min { $0.1 < $1.1 }

            guard let nearest, nearest.1 <= tolerance else { return }
            parent.selectedRiverName = nearest.0
        }

        func syncRivers(_ mapView: MKMapView) {
            let key = parent.showRivers
                ? parent.rivers
                    .map { "\($0.id):\(String(describing: parent.riverColors[$0.id] ?? .gray))" }
                    .joined(separator: "|")
                : ""
            guard key != riverSignature else { return }
            riverSignature = key
            mapView.removeOverlays(riverOverlays)
            guard parent.showRivers else {
                riverOverlays = []
                return
            }
            riverOverlays = parent.rivers.flatMap { river -> [MKOverlay] in
                river.mapLines.compactMap { coords in
                    guard coords.count >= 2 else { return nil }
                    let line = RiverPolyline(coordinates: coords, count: coords.count)
                    line.title = river.name
                    // An ungauged river recedes: same neutral, but lighter and
                    // thinner, so it reads as hydrography while the gauged
                    // mainstems carry the signal. 73% of drawn rivers have no
                    // gauge, and at full weight they drown out the 27% that do.
                    let rated = parent.riverColors[river.id]
                    line.color = rated ?? Color.gray.opacity(0.45)
                    line.width = rated == nil ? river.lineWidth * 0.6 : river.lineWidth
                    return line
                }
            }
            // Above the marine fills, below the heat cells at `.aboveLabels`.
            mapView.addOverlays(riverOverlays, level: .aboveRoads)
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let river = overlay as? RiverPolyline {
                let line = MKPolylineRenderer(overlay: river)
                line.strokeColor = UIColor(river.color)
                line.lineWidth = river.width
                line.lineCap = .round
                line.lineJoin = .round
                return line
            }
            let r = MKPolygonRenderer(overlay: overlay)
            if overlay is ProtectedAreaPolygon {
                // Deliberately unlike the rated fills: a hatched grey boundary
                // states where the area is, and claims nothing about fishing.
                r.fillColor = UIColor.systemGray.withAlphaComponent(0.10)
                r.strokeColor = UIColor.systemGray.withAlphaComponent(0.85)
                r.lineWidth = 1.2
                r.lineDashPattern = [4, 3]
            } else if let tagged = overlay as? RatedPolygon {
                if tagged.isHeat {
                    r.fillColor = UIColor(tagged.color)
                    r.strokeColor = .clear
                    r.lineWidth = 0
                } else {
                    r.fillColor = UIColor(tagged.color.opacity(0.12))
                    r.strokeColor = UIColor(tagged.color.opacity(0.35))
                    r.lineWidth = 0.75
                }
            }
            return r
        }

        // MARK: Annotations

        func syncAnnotations(_ mapView: MKMapView) {
            let signature = parent.annotations
                .map { "\($0.id):\($0.rating?.rawValue ?? -1)" }
                .joined(separator: ",")
            let labels = parent.showAreaLabels ? parent.areas.map(\.id).joined(separator: ",") : ""
            guard signature != annotationSignature || labels != labelSignature else { return }

            if signature != annotationSignature {
                annotationSignature = signature
                // Removing the selected annotation makes MapKit fire `didDeselect`,
                // which would nil `selectedSiteID` and dismiss an open sheet. Any
                // rating change rebuilds the whole list, so a month or species
                // change closed the sheet under the user. Suppress the round-trip
                // and put the selection back on the replacement annotation.
                let previouslySelected = parent.selectedID
                isSyncingSelection = true
                mapView.removeAnnotations(mapView.annotations.compactMap { $0 as? SiteAnnotation })
                mapView.addAnnotations(parent.annotations)
                if let id = previouslySelected,
                   let match = parent.annotations.first(where: { $0.id == id }) {
                    mapView.selectAnnotation(match, animated: false)
                }
                isSyncingSelection = false
            }
            if labels != labelSignature {
                labelSignature = labels
                mapView.removeAnnotations(mapView.annotations.compactMap { $0 as? AreaLabelAnnotation })
                if parent.showAreaLabels {
                    mapView.addAnnotations(parent.areas.map(AreaLabelAnnotation.init(area:)))
                }
            }

            // The camera opened statewide with `position = .automatic`; do that
            // once, as soon as there is anything to frame — but never over the
            // top of a camera the user or a location fix has already claimed.
            // CoreLocation regularly answers before the WDFW fetch, and the fit
            // used to erase the recentre with no second chance to reapply it.
            // Framed from coordinates rather than `showAnnotations`, which would
            // add every pin to a map zoomed out past the level that hides them.
            if !hasDoneInitialFit && !parent.fitAnnotations.isEmpty
                && !parent.userMovedCamera && parent.focusRegion == nil && !hasAppliedFocusRegion {
                hasDoneInitialFit = true
                let rect = parent.fitAnnotations
                    .map { MKMapRect(origin: MKMapPoint($0.coordinate), size: MKMapSize(width: 0, height: 0)) }
                    .reduce(MKMapRect.null) { $0.union($1) }
                mapView.setVisibleMapRect(rect, edgePadding: UIEdgeInsets(top: 40, left: 40, bottom: 40, right: 40),
                                          animated: false)
            }
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if annotation is MKUserLocation { return nil }
            if annotation is AreaLabelAnnotation {
                return mapView.dequeueReusableAnnotationView(
                    withIdentifier: Self.areaLabelReuseID, for: annotation)
            }
            return nil // the registered default/cluster classes handle the rest
        }

        // MARK: Selection

        func syncSelection(_ mapView: MKMapView) {
            guard appliedSelectionID != parent.selectedID else { return }
            appliedSelectionID = parent.selectedID
            isSyncingSelection = true
            defer { isSyncingSelection = false }
            for annotation in mapView.selectedAnnotations {
                mapView.deselectAnnotation(annotation, animated: false)
            }
            if let id = parent.selectedID,
               let match = mapView.annotations.compactMap({ $0 as? SiteAnnotation }).first(where: { $0.id == id }) {
                mapView.selectAnnotation(match, animated: false)
            }
        }

        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            if let cluster = view.annotation as? MKClusterAnnotation {
                mapView.deselectAnnotation(cluster, animated: false)
                mapView.setRegion(boundingRegion(of: cluster, padding: 1.4), animated: true)
                parent.userMovedCamera = true
                return
            }
            guard !isSyncingSelection else { return }
            if let site = view.annotation as? SiteAnnotation {
                appliedSelectionID = site.id
                parent.selectedID = site.id
            }
        }

        func mapView(_ mapView: MKMapView, didDeselect view: MKAnnotationView) {
            guard !isSyncingSelection, let site = view.annotation as? SiteAnnotation else { return }
            // MapKit also deselects when it recycles the view of a pin that has
            // scrolled off screen. Panning the selected pin out of frame is not
            // the user closing the sheet, so only an on-screen deselect counts.
            // MapKit has genuinely dropped the selection either way, so forget
            // that we applied it — otherwise syncSelection's guard holds and the
            // pin never re-highlights when it is panned back into view.
            appliedSelectionID = nil
            guard mapView.visibleMapRect.contains(MKMapPoint(site.coordinate)) else { return }
            parent.selectedID = nil
        }

        /// The cluster's real members frame the zoom, so it lands on the actual
        /// sites rather than on a grid cell.
        private func boundingRegion(of cluster: MKClusterAnnotation, padding: Double) -> MKCoordinateRegion {
            let coords = cluster.memberAnnotations.map(\.coordinate)
            let lats = coords.map(\.latitude), lons = coords.map(\.longitude)
            guard let minLat = lats.min(), let maxLat = lats.max(),
                  let minLon = lons.min(), let maxLon = lons.max() else {
                return MKCoordinateRegion(center: cluster.coordinate,
                                          span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1))
            }
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2,
                                               longitude: (minLon + maxLon) / 2),
                span: MKCoordinateSpan(latitudeDelta: max(maxLat - minLat, 0.01) * padding,
                                       longitudeDelta: max(maxLon - minLon, 0.01) * padding)
            )
        }

        // MARK: Camera

        func applyFocusRegionIfNeeded(_ mapView: MKMapView) {
            guard let region = parent.focusRegion else { return }
            hasAppliedFocusRegion = true
            DispatchQueue.main.async {
                self.parent.focusRegion = nil
                mapView.setRegion(region, animated: true)
            }
        }

        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            let center = mapView.centerCoordinate
            let distance = mapView.camera.centerCoordinateDistance
            DispatchQueue.main.async {
                self.parent.cameraDistance = distance
                self.parent.cameraCenter = LonLat(longitude: center.longitude, latitude: center.latitude)
            }
        }

        /// Pan and pinch are continuous and report `.began`/`.changed`; the tap
        /// recognizers are discrete and only ever reach `.ended`. A guard on the
        /// continuous states alone silently ignores every tap zoom, which is how
        /// double-tap stopped counting as a user camera move.
        static func isCameraMove(_ state: UIGestureRecognizer.State) -> Bool {
            switch state {
            case .began, .changed, .ended: true
            default: false
            }
        }

        /// Written synchronously, unlike `regionDidChangeAnimated` above. Every
        /// reader of this flag is synchronous — the `onChange` that eases to a
        /// location fix, and the initial fit — so deferring it by a runloop turn
        /// left a window where a fix delivered in the same turn as the touch read
        /// `false` and yanked a camera the user had just moved. UIKit dispatches a
        /// gesture action outside SwiftUI's update pass, so there is nothing here
        /// to hop off; the region callback needs the hop because MapKit can raise
        /// it from inside `updateUIView`'s own `setRegion`.
        @objc func userGesture(_ recognizer: UIGestureRecognizer) {
            guard Coordinator.isCameraMove(recognizer.state) else { return }
            guard !parent.userMovedCamera else { return }
            parent.userMovedCamera = true
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
            true
        }
    }
}
