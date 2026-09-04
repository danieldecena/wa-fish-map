import MapKit
import SwiftUI
import Testing
@testable import WAFishMap

/// The `MKMapView` coordinator's own bookkeeping: what it is allowed to do to
/// the camera, and how it stacks its overlays.
@MainActor
struct MapCoordinatorTests {
    private static func area(_ name: String, lon: Double, lat: Double) -> MarineArea {
        MarineArea(areaName: name, areaTitle: name, wac: "", coordinates: [
            LonLat(longitude: lon, latitude: lat),
            LonLat(longitude: lon + 0.1, latitude: lat),
            LonLat(longitude: lon + 0.1, latitude: lat + 0.1),
            LonLat(longitude: lon, latitude: lat + 0.1)
        ])
    }

    private static func site(_ name: String, lon: Double, lat: Double) -> AccessSite {
        AccessSite(facilityName: name, countyName: "King", hasLaunch: true,
                   launchSurface: .gravel, hasRestrooms: false, directions: "",
                   coordinate: LonLat(longitude: lon, latitude: lat))
    }

    private static func representable(
        annotations: [SiteAnnotation] = [],
        areas: [MarineArea] = [],
        areaColors: [String: Color] = [:],
        protectedAreas: [ProtectedArea] = [],
        heatZones: [HeatZone] = [],
        rivers: [River] = [],
        riverColors: [String: Color] = [:],
        userMovedCamera: Bool = false,
        focusRegion: MKCoordinateRegion? = nil
    ) -> FishingMapRepresentable {
        FishingMapRepresentable(
            annotations: annotations,
            areas: areas,
            areaColors: areaColors,
            protectedAreas: protectedAreas,
            heatZones: heatZones,
            rivers: rivers,
            riverColors: riverColors,
            showRivers: !rivers.isEmpty,
            showHeat: !heatZones.isEmpty,
            showAreaLabels: false,
            pointsOfInterest: [],
            selectedID: .constant(nil),
            cameraDistance: .constant(0),
            cameraCenter: .constant(LonLat(longitude: -122.5, latitude: 47.5)),
            userMovedCamera: .constant(userMovedCamera),
            focusRegion: .constant(focusRegion)
        )
    }

    private static func river(_ name: String, order: Int, lon: Double, lat: Double) -> River {
        River(name: name, streamOrder: order, lengthKm: 40, lines: [[
            LonLat(longitude: lon, latitude: lat),
            LonLat(longitude: lon + 0.2, latitude: lat + 0.2)
        ]])
    }

    private static let parked = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 47.60, longitude: -122.33),
        span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
    )

    /// Far from `parked`, so an initial fit that runs is unmistakable.
    private static var farAnnotations: [SiteAnnotation] {
        [SiteAnnotation(site: site("Far", lon: -117.4, lat: 46.0), rating: nil)]
    }

    // MARK: Finding 1 — the initial fit must not clobber a claimed camera

    @Test func theInitialFitRunsWhenNobodyHasClaimedTheCamera() {
        let mapView = MKMapView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        mapView.setRegion(Self.parked, animated: false)
        let coordinator = FishingMapRepresentable.Coordinator(
            Self.representable(annotations: Self.farAnnotations))
        coordinator.syncAnnotations(mapView)
        // Control: without this the two tests below could pass by never fitting.
        #expect(abs(mapView.centerCoordinate.longitude - Self.parked.center.longitude) > 1.0)
    }

    @Test func theInitialFitIsSkippedAfterTheUserMovedTheCamera() {
        let mapView = MKMapView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        mapView.setRegion(Self.parked, animated: false)
        let coordinator = FishingMapRepresentable.Coordinator(
            Self.representable(annotations: Self.farAnnotations, userMovedCamera: true))
        coordinator.syncAnnotations(mapView)
        #expect(abs(mapView.centerCoordinate.longitude - Self.parked.center.longitude) < 0.05)
    }

    /// The regression: CoreLocation answers first, the coordinator eases to the
    /// fix, then the WDFW annotations land. The fit must not re-frame statewide.
    @Test func aRecentreThatAlreadyLandedSurvivesTheAnnotationsArriving() {
        let mapView = MKMapView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        let withFocus = FishingMapRepresentable.Coordinator(
            Self.representable(focusRegion: Self.parked))
        withFocus.applyFocusRegionIfNeeded(mapView)
        #expect(withFocus.hasAppliedFocusRegion)

        withFocus.parent = Self.representable(annotations: Self.farAnnotations)
        mapView.setRegion(Self.parked, animated: false)
        withFocus.syncAnnotations(mapView)
        #expect(abs(mapView.centerCoordinate.longitude - Self.parked.center.longitude) < 0.05)
    }

    // MARK: Finding 4 — overlay z-order

    @Test func heatSitsAboveTheAreaFillsEvenAfterARecolour() {
        let mapView = MKMapView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        let areas = [Self.area("10", lon: -122.5, lat: 47.5)]
        let heat = [HeatZone(id: 1, center: LonLat(longitude: -122.5, latitude: 47.5),
                             cellDegrees: 0.1, intensity: 0.8)]
        let coordinator = FishingMapRepresentable.Coordinator(
            Self.representable(areas: areas, areaColors: ["10": .blue], heatZones: heat))
        coordinator.syncOverlays(mapView)

        // A month scrub recolours the areas and re-adds them.
        coordinator.parent = Self.representable(areas: areas, areaColors: ["10": .red], heatZones: heat)
        coordinator.syncOverlays(mapView)

        #expect(mapView.overlays(in: .aboveRoads).count == 1)
        #expect(mapView.overlays(in: .aboveLabels).count == 1)
        #expect(mapView.overlays(in: .aboveLabels).first is RatedPolygon)
        #expect((mapView.overlays(in: .aboveLabels).first as? RatedPolygon)?.isHeat == true)
    }

    /// Rivers share `.aboveRoads` with the fills and must not disturb the heat
    /// cells a level up. Asserted rather than trusted: order inside a level is
    /// add order, which is exactly what bit the fills when the MPAs arrived.
    @Test func riversDrawOverTheFillsAndUnderTheHeat() {
        let mapView = MKMapView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        let areas = [Self.area("10", lon: -122.5, lat: 47.5)]
        let heat = [HeatZone(id: 1, center: LonLat(longitude: -122.5, latitude: 47.5),
                             cellDegrees: 0.1, intensity: 0.8)]
        let rivers = [Self.river("Skagit River", order: 6, lon: -121.8, lat: 48.4)]
        let coordinator = FishingMapRepresentable.Coordinator(
            Self.representable(areas: areas, areaColors: ["10": .blue],
                               heatZones: heat, rivers: rivers))
        coordinator.syncOverlays(mapView)
        coordinator.syncRivers(mapView)

        let low = mapView.overlays(in: .aboveRoads)
        #expect(low.count == 2)
        #expect(low.last is RiverPolyline)
        #expect(mapView.overlays(in: .aboveLabels).count == 1)
        #expect(mapView.overlays(in: .aboveLabels).first is RatedPolygon)
    }

    /// The toggle is what removes them; a stale signature would leave the lines
    /// on the map after the user switched the layer off.
    @Test func turningRiversOffRemovesTheirOverlays() {
        let mapView = MKMapView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        let rivers = [Self.river("Skagit River", order: 6, lon: -121.8, lat: 48.4)]
        let coordinator = FishingMapRepresentable.Coordinator(Self.representable(rivers: rivers))
        coordinator.syncRivers(mapView)
        #expect(mapView.overlays(in: .aboveRoads).count == 1)

        coordinator.parent = Self.representable(rivers: [])
        coordinator.syncRivers(mapView)
        #expect(mapView.overlays(in: .aboveRoads).isEmpty)
    }

    /// A river with no gauge reading recedes: same neutral hue, but lighter and
    /// thinner, so the gauged mainstems carry the signal.
    @Test func aRatedRiverTakesItsColourAndAnUnratedOneStaysNeutral() {
        let mapView = MKMapView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        let rivers = [Self.river("Skagit River", order: 6, lon: -121.8, lat: 48.4),
                      Self.river("Sauk River", order: 4, lon: -121.5, lat: 48.2)]
        let coordinator = FishingMapRepresentable.Coordinator(
            Self.representable(rivers: rivers, riverColors: ["Skagit River": .red]))
        coordinator.syncRivers(mapView)

        let lines = mapView.overlays(in: .aboveRoads).compactMap { $0 as? RiverPolyline }
        #expect(lines.count == 2)
        let skagit = try? #require(lines.first { $0.title == "Skagit River" })
        let sauk = try? #require(lines.first { $0.title == "Sauk River" })
        #expect(skagit?.color == .red)
        #expect(sauk?.color == Color.gray.opacity(0.45))
        // The recessive treatment is a width change too, not just a tint.
        #expect((sauk?.width ?? 0) < (skagit?.width ?? 0))
    }

    /// MPAs load after the marine areas, and within one level MapKit draws in add
    /// order — so the fills have to be lifted back on top.
    @Test func protectedAreasStayUnderTheMarineAreaFills() {
        let mapView = MKMapView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        let areas = [Self.area("10", lon: -122.5, lat: 47.5)]
        let coordinator = FishingMapRepresentable.Coordinator(
            Self.representable(areas: areas, areaColors: ["10": .blue]))
        coordinator.syncOverlays(mapView)

        let mpa = ProtectedArea(name: "Golden Gardens", type: "Marine Preserve", wac: "",
                                detailURL: nil, polygon: [
                                    LonLat(longitude: -122.5, latitude: 47.5),
                                    LonLat(longitude: -122.4, latitude: 47.5),
                                    LonLat(longitude: -122.4, latitude: 47.6)
                                ])
        coordinator.parent = Self.representable(areas: areas, areaColors: ["10": .blue],
                                                protectedAreas: [mpa])
        coordinator.syncOverlays(mapView)

        let stack = mapView.overlays(in: .aboveRoads)
        #expect(stack.count == 2)
        #expect(stack.first is ProtectedAreaPolygon)
        #expect(stack.last is RatedPolygon)
    }
}
