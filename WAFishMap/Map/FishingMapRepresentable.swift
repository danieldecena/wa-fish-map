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

/// A Marine Protected Area boundary. Geography, not a rating — its own class so
/// the renderer can draw it as a dashed outline rather than a rated fill. The
/// name rides on `MKShape.title`, which is what MapKit reads out.
final class ProtectedAreaPolygon: MKPolygon {}

/// Hosts `MKMapView` so MapKit can do collision-based clustering, which SwiftUI's
/// `Map` does not expose. Everything the `Map {}` block drew is reproduced here:
/// marine-area polygons, "MA n" labels, heat cells, site/pier pins, the user dot.
struct FishingMapRepresentable: UIViewRepresentable {
    let annotations: [SiteAnnotation]
    let areas: [MarineArea]
    /// Rating colour per `MarineArea.id`; the polygon fill/stroke.
    let areaColors: [String: Color]
    /// WDFW Marine Protected Area boundaries; drawn under the marine-area fills.
    let protectedAreas: [ProtectedArea]
    let heatZones: [HeatZone]
    let showHeat: Bool
    let showAreaLabels: Bool
    let pointsOfInterest: [MKPointOfInterestCategory]
    @Binding var selectedID: String?
    @Binding var cameraDistance: Double
    @Binding var cameraCenter: LonLat
    @Binding var userMovedCamera: Bool
    /// A one-shot camera move requested by the view (the recentre-on-fix ease).
    /// The coordinator applies it and clears it.
    @Binding var focusRegion: MKCoordinateRegion?

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        mapView.showsCompass = true
        mapView.showsScale = false
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
            guard emphasisIsMuted != parent.showHeat else { return }
            emphasisIsMuted = parent.showHeat
            // Drain the basemap while the overlay is on: a translucent fill takes
            // its apparent colour from what is under it, so over the full-colour
            // map one density band read as three different colours.
            let config = MKStandardMapConfiguration(
                emphasisStyle: parent.showHeat ? .muted : .default
            )
            config.pointOfInterestFilter = MKPointOfInterestFilter(including: parent.pointsOfInterest)
            mapView.preferredConfiguration = config
        }

        // MARK: Overlays

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
                mpaOverlays = parent.protectedAreas.compactMap { mpa in
                    let coords = mpa.mapCoordinates
                    guard coords.count > 2 else { return nil }
                    let polygon = ProtectedAreaPolygon(coordinates: coords, count: coords.count)
                    polygon.title = mpa.name
                    return polygon
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
                    areaOverlays = parent.areas.compactMap { area in
                        let coords = area.mapCoordinates
                        guard coords.count > 2 else { return nil }
                        let polygon = RatedPolygon(coordinates: coords, count: coords.count)
                        polygon.color = parent.areaColors[area.id] ?? .gray
                        return polygon
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

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
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
            if !hasDoneInitialFit && !parent.annotations.isEmpty
                && !parent.userMovedCamera && parent.focusRegion == nil && !hasAppliedFocusRegion {
                hasDoneInitialFit = true
                mapView.showAnnotations(parent.annotations, animated: false)
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
            case .began, .changed: true
            default: false
            }
        }

        @objc func userGesture(_ recognizer: UIGestureRecognizer) {
            guard Coordinator.isCameraMove(recognizer.state) else { return }
            guard !parent.userMovedCamera else { return }
            DispatchQueue.main.async { self.parent.userMovedCamera = true }
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
            true
        }
    }
}
