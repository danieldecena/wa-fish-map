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

/// Hosts `MKMapView` so MapKit can do collision-based clustering, which SwiftUI's
/// `Map` does not expose. Everything the `Map {}` block drew is reproduced here:
/// marine-area polygons, "MA n" labels, heat cells, site/pier pins, the user dot.
struct FishingMapRepresentable: UIViewRepresentable {
    let annotations: [SiteAnnotation]
    let areas: [MarineArea]
    /// Rating colour per `MarineArea.id`; the polygon fill/stroke.
    let areaColors: [String: Color]
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
        for recognizer in [UIPanGestureRecognizer(target: context.coordinator,
                                                  action: #selector(Coordinator.userGesture)),
                           UIPinchGestureRecognizer(target: context.coordinator,
                                                    action: #selector(Coordinator.userGesture))] as [UIGestureRecognizer] {
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
        private var overlaySignature: String?
        private var annotationSignature: String?
        private var labelSignature: String?
        private var emphasisIsMuted: Bool?
        private var hasDoneInitialFit = false
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
                elevationStyle: .flat,
                emphasisStyle: parent.showHeat ? .muted : .default
            )
            config.pointOfInterestFilter = MKPointOfInterestFilter(including: parent.pointsOfInterest)
            mapView.preferredConfiguration = config
        }

        // MARK: Overlays

        func syncOverlays(_ mapView: MKMapView) {
            let signature = parent.areas.map { "\($0.id):\(parent.areaColors[$0.id].map(String.init(describing:)) ?? "-")" }
                .joined(separator: "|")
                + "#" + parent.heatZones.map { "\($0.id):\($0.intensity)" }.joined(separator: ",")
            guard signature != overlaySignature else { return }
            overlaySignature = signature

            mapView.removeOverlays(mapView.overlays)
            var overlays: [MKOverlay] = []
            for area in parent.areas {
                let coords = area.mapCoordinates
                guard coords.count > 2 else { continue }
                let polygon = RatedPolygon(coordinates: coords, count: coords.count)
                polygon.color = parent.areaColors[area.id] ?? .gray
                overlays.append(polygon)
            }
            for zone in parent.heatZones {
                let coords = zone.corners.map(\.clLocationCoordinate)
                let polygon = RatedPolygon(coordinates: coords, count: coords.count)
                polygon.color = ColorRamp.densityFill(zone.intensity)
                polygon.isHeat = true
                overlays.append(polygon)
            }
            mapView.addOverlays(overlays)
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            let r = MKPolygonRenderer(overlay: overlay)
            if let tagged = overlay as? RatedPolygon {
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
                mapView.removeAnnotations(mapView.annotations.compactMap { $0 as? SiteAnnotation })
                mapView.addAnnotations(parent.annotations)
            }
            if labels != labelSignature {
                labelSignature = labels
                mapView.removeAnnotations(mapView.annotations.compactMap { $0 as? AreaLabelAnnotation })
                if parent.showAreaLabels {
                    mapView.addAnnotations(parent.areas.map(AreaLabelAnnotation.init(area:)))
                }
            }

            // The camera opened statewide with `position = .automatic`; do that
            // once, as soon as there is anything to frame.
            if !hasDoneInitialFit && !parent.annotations.isEmpty {
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
            let current = (mapView.selectedAnnotations.first as? SiteAnnotation)?.id
            guard current != parent.selectedID else { return }
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
                parent.selectedID = site.id
            }
        }

        func mapView(_ mapView: MKMapView, didDeselect view: MKAnnotationView) {
            guard !isSyncingSelection, view.annotation is SiteAnnotation else { return }
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

        @objc func userGesture(_ recognizer: UIGestureRecognizer) {
            guard recognizer.state == .began || recognizer.state == .changed else { return }
            guard !parent.userMovedCamera else { return }
            DispatchQueue.main.async { self.parent.userMovedCamera = true }
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
            true
        }
    }
}
