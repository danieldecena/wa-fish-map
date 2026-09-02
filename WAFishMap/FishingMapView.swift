import MapKit
import SwiftUI

struct FishingMapView: View {
    @State private var model = FishingMapModel()
    @Environment(\.openURL) private var openURL
    @State private var location = LocationProvider()
    @State private var position: MapCameraPosition = .automatic
    /// Date/time the user is planning for. Defaults to now; the month drives ratings.
    @State private var planDate = Date()
    /// `nil` is All species (best in the area). Exact name from the guide otherwise.
    @State private var selectedSpecies: String?
    @State private var showHeat = false
    @State private var showDisclaimer = false
    @State private var heatZones: [HeatZone] = []
    /// Camera altitude in meters; starts far out so area labels stay hidden until the
    /// first camera event. Below the threshold the "MA n" capsules stop overlapping.
    @State private var cameraDistance: Double = .greatestFiniteMagnitude
    private static let areaLabelMaxDistance: Double = 600_000
    /// Above this altitude a site is a bare colored dot. Balloon pins carry a
    /// glyph and a shadow that are unreadable at range and mat together.
    private static let pinDetailMaxDistance: Double = 150_000

    /// Grid cell size, in degrees, for the density overlay. A fixed size cannot
    /// work at every zoom: 0.15 was a chessboard up close, and 0.06 was specks
    /// from statewide. Coarser as the camera pulls back keeps the cell roughly
    /// the same size on screen.
    private static func heatCellDegrees(_ distance: Double) -> Double {
        switch distance {
        case ..<120_000: 0.05
        case ..<400_000: 0.10
        default: 0.20
        }
    }
    /// Where the user is looking; drives the sun-time math. Statewide the east-west
    /// sunrise spread is ~10 minutes, so camera-center precision is plenty.
    @State private var cameraCenter = MapScope.cameraCenter
    /// Set once the user pans or zooms. A fix that lands afterwards must not yank
    /// the camera out from under them.
    @State private var userMovedCamera = false
    /// With `position = .automatic`, MapKit fires a genuine `.onEnd` camera-change
    /// event of its own once before any data exists, and fires a SECOND one when
    /// `accessSites` populates from the network and the camera re-fits to it.
    /// Exempting only the first such event (an ordinal count) let that second,
    /// still-programmatic re-fit set `userMovedCamera` before CoreLocation had
    /// even answered — the recentre-on-fix animation then never ran.
    ///
    /// `MapCameraUpdateContext` has no "gesture vs. programmatic" reason in the
    /// SwiftUI Map API, so instead of counting events this keys off the data load
    /// itself: `.beforeLoad` events are MapKit's own initial fit, `load()` flips
    /// the phase to `.awaitingPostLoadRefit` the instant `accessSites` is set
    /// (synchronously, before SwiftUI's next render can trigger the re-fit's
    /// `.onEnd`), that one re-fit event is consumed to reach `.settled`, and only
    /// an event in `.settled` is a real user gesture.
    private enum CameraGuardPhase { case beforeLoad, awaitingPostLoadRefit, settled }
    @State private var cameraGuardPhase: CameraGuardPhase = .beforeLoad
    /// Washington's bounding box. A fix outside it belongs to someone travelling,
    /// and centring there would show an empty map — the data is statewide only.
    private static let stateBounds = (
        minLat: 45.5, maxLat: 49.1, minLon: -124.9, maxLon: -116.9
    )
    private static func isInWashington(_ c: CLLocationCoordinate2D) -> Bool {
        (stateBounds.minLat...stateBounds.maxLat).contains(c.latitude)
            && (stateBounds.minLon...stateBounds.maxLon).contains(c.longitude)
    }
    @Environment(\.horizontalSizeClass) private var sizeClass

    /// POIs worth showing an angler (instead of hiding all landmarks).
    private let landmarkCategories: [MKPointOfInterestCategory] = [
        .marina, .park, .campground, .nationalPark, .parking, .publicTransport, .gasStation
    ]

    /// Month from the selected plan date drives every rating on the map.
    private var currentMonth: Int {
        Calendar.current.component(.month, from: planDate)
    }

    private var timeOfDay: TimeOfDay {
        if let solar = SolarTimes.compute(on: planDate, at: cameraCenter) {
            return TimeOfDay(date: planDate, solar: solar)
        }
        return TimeOfDay(hour: Calendar.current.component(.hour, from: planDate))
    }

    var body: some View {
        Map(position: $position, selection: $model.selectedSiteID) {
            ForEach(model.marineAreas) { area in
                MapPolygon(coordinates: area.mapCoordinates)
                    .foregroundStyle(color(forArea: area).opacity(0.12))
                    .stroke(color(forArea: area).opacity(0.35), lineWidth: 0.75)
                if cameraDistance < Self.areaLabelMaxDistance {
                    Annotation("Area \(area.areaName)", coordinate: area.center) {
                        Text("MA \(area.areaName)")
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .background(.ultraThinMaterial, in: Capsule())
                    }
                    .annotationTitles(.hidden)
                }
            }
            ForEach(heatZones) { zone in
                // The real grid cell, tiled. Circles wider than their own cell
                // overlapped, and translucent overlap composites rather than
                // maxes, so mediocre neighbours out-darkened a genuinely hot cell.
                MapPolygon(coordinates: zone.corners.map(\.clLocationCoordinate))
                    .foregroundStyle(ColorRamp.densityFill(zone.intensity))
            }
            if cameraDistance > Self.pinDetailMaxDistance {
                ForEach(pinClusters) { cluster in
                    clusterAnnotation(cluster)
                }
            } else {
                ForEach(model.accessSites) { site in
                    Marker(site.facilityName,
                           systemImage: site.hasLaunch ? "anchor.fill" : "figure.fishing",
                           coordinate: site.mapCoordinate)
                        .tint(color(forSite: site))
                        .tag(site.id)
                }
                ForEach(model.piers) { pier in
                    Marker(pier.name, systemImage: "fish.fill", coordinate: pier.mapCoordinate)
                        .tint(rating(for: pier)?.color ?? .gray)
                        .tag(pier.id)
                }
            }
            UserAnnotation()
        }
        // Drain the basemap while the overlay is on. A translucent fill takes its
        // apparent colour from what is under it, so over the full-colour map one
        // density band read as three different colours depending on land, water
        // or city. A neutral ground is what makes the bands mean one thing.
        .mapStyle(.standard(
            emphasis: showHeat ? .muted : .automatic,
            pointsOfInterest: .including(landmarkCategories)
        ))
        .mapControls {
            MapUserLocationButton()
            MapCompass()
        }
        .safeAreaInset(edge: .top) { dateControl }
        .safeAreaInset(edge: .bottom) { statusBar }
        .modifier(AdaptiveDetail(item: selectedSiteBinding) { site in
            SiteDetailSheet(
                site: site,
                fishery: model.fishery(for: site),
                isMarine: model.isMarine(site),
                guide: model.guide,
                planDate: planDate
            )
        })
        .modifier(AdaptiveDetail(item: selectedPierBinding) { pier in
            PierDetailSheet(
                pier: pier,
                fishery: model.fishery(for: pier),
                isMarine: model.isMarine(pier),
                guide: model.guide,
                planDate: planDate
            )
        })
        .overlay {
            // Total load failure (no live data, no bundled sample): the kit's
            // empty-state pattern instead of a bare caption in the status bar.
            if !model.isLoading && model.accessSites.isEmpty {
                ContentUnavailableView {
                    Label("No fishing data", systemImage: "wifi.slash")
                } description: {
                    Text(model.statusMessage)
                } actions: {
                    Button("Try Again") {
                        Task {
                            model.isLoading = true
                            await model.load()
                            recomputeHeatZones()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20))
                .padding(40)
            }
        }
        .task {
            location.requestIfNeeded()
            await model.load()
            recomputeHeatZones()
            // accessSites is now populated, so MapKit's .automatic camera is about
            // to re-fit to it — that re-fit is the event this phase exists to catch.
            cameraGuardPhase = .awaitingPostLoadRefit
        }
        .onChange(of: showHeat) { recomputeHeatZones() }
        .onChange(of: Self.heatCellDegrees(cameraDistance)) { recomputeHeatZones() }
        .onChange(of: currentMonth) { recomputeHeatZones() }
        .onChange(of: selectedSpecies) { recomputeHeatZones() }
        .onChange(of: location.fix?.latitude) { recenterOnFixIfAppropriate() }
        .onMapCameraChange(frequency: .onEnd) { context in
            switch cameraGuardPhase {
            case .beforeLoad:
                break // MapKit's own pre-data fit; not the user
            case .awaitingPostLoadRefit:
                cameraGuardPhase = .settled // consume the data-triggered re-fit; still not the user
            case .settled:
                userMovedCamera = true
            }
            cameraDistance = context.camera.distance
            cameraCenter = LonLat(
                longitude: context.camera.centerCoordinate.longitude,
                latitude: context.camera.centerCoordinate.latitude
            )
        }
    }

    // MARK: Rating → color (nil rating renders neutral gray)

    private func color(forArea area: MarineArea) -> Color {
        (model.guide?.area(named: area.areaName)?.rating(inMonth: currentMonth, species: selectedSpecies)?.color) ?? .gray
    }

    private func color(forSite site: AccessSite) -> Color {
        rating(for: site)?.color ?? .gray
    }

    /// Sites and piers bucketed on the same grid as the heat overlay.
    private var pinClusters: [MapCluster] {
        var points: [(id: String, coord: LonLat, rating: FishingRating?)] = []
        points.reserveCapacity(model.accessSites.count + model.piers.count)
        for site in model.accessSites {
            points.append((site.id, site.coordinate, rating(for: site)))
        }
        for pier in model.piers {
            points.append((pier.id, pier.coordinate, rating(for: pier)))
        }
        return HeatMap.clusters(points: points, cellDegrees: Self.heatCellDegrees(cameraDistance))
    }

    @MapContentBuilder
    private func clusterAnnotation(_ cluster: MapCluster) -> some MapContent {
        if cluster.count == 1, let site = model.accessSites.first(where: { $0.id == cluster.memberIDs[0] }) {
            Annotation(site.facilityName, coordinate: site.mapCoordinate) {
                RatingDot(color: color(forSite: site))
            }
            .annotationTitles(.hidden)
            .tag(site.id)
        } else if cluster.count == 1, let pier = model.piers.first(where: { $0.id == cluster.memberIDs[0] }) {
            Annotation(pier.name, coordinate: pier.mapCoordinate) {
                RatingDot(color: rating(for: pier)?.color ?? .gray)
            }
            .annotationTitles(.hidden)
            .tag(pier.id)
        } else {
            Annotation("", coordinate: cluster.center.clLocationCoordinate) {
                ClusterMark(count: cluster.count, color: cluster.bestRating?.color ?? .gray)
                    .onTapGesture { zoomToCluster(cluster) }
            }
            .annotationTitles(.hidden)
        }
    }

    private func zoomToCluster(_ cluster: MapCluster) {
        userMovedCamera = true
        cameraGuardPhase = .settled
        let span = cluster.cellDegrees * 2.5
        withAnimation(.easeInOut(duration: 0.4)) {
            position = .region(MKCoordinateRegion(
                center: cluster.center.clLocationCoordinate,
                span: MKCoordinateSpan(latitudeDelta: span, longitudeDelta: span)
            ))
        }
    }

    // MARK: Heat zones (density of good-rated spots, cold→hot)

    /// Cached in state; zones only change with the toggle, the plan month, the
    /// species filter, a data load, or the camera-distance band.
    private func recomputeHeatZones() {
        guard showHeat else {
            heatZones = []
            return
        }
        var points: [(coord: LonLat, weight: Double)] = []
        for site in model.accessSites {
            points.append((site.coordinate, heatWeight(rating(for: site))))
        }
        for pier in model.piers {
            points.append((pier.coordinate, heatWeight(rating(for: pier))))
        }
        heatZones = HeatMap.zones(points: points, cellDegrees: Self.heatCellDegrees(cameraDistance))
    }

    /// Density counts every spot; better-rated spots weigh more so hot zones favor quality.
    private func heatWeight(_ rating: FishingRating?) -> Double {
        switch rating {
        case .excellent: 2.0
        case .good: 1.6
        case .fair: 1.2
        default: 1.0
        }
    }

    /// Ease to the user once, and only when it helps: a fix outside Washington
    /// would frame an empty map, and a user who has already moved the camera has
    /// said where they want to be.
    private func recenterOnFixIfAppropriate() {
        guard !userMovedCamera, let fix = location.fix, Self.isInWashington(fix) else { return }
        withAnimation(.easeInOut(duration: 0.6)) {
            position = .region(MKCoordinateRegion(
                center: fix,
                span: MKCoordinateSpan(latitudeDelta: 0.9, longitudeDelta: 0.9)
            ))
        }
    }

    private var selectedSiteBinding: Binding<AccessSite?> {
        Binding(
            get: { model.selectedSite },
            set: { model.selectedSiteID = $0?.id }
        )
    }

    /// Piers share the map's single selection; resolve it back to a pier when the
    /// selected id is a pier's.
    private var selectedPierBinding: Binding<FishingPier?> {
        Binding(
            get: { model.piers.first { $0.id == model.selectedSiteID } },
            set: { model.selectedSiteID = $0?.id }
        )
    }

    private func rating(for site: AccessSite) -> FishingRating? {
        model.rating(for: site, month: currentMonth, species: selectedSpecies)
    }

    private func rating(for pier: FishingPier) -> FishingRating? {
        model.rating(for: pier, month: currentMonth, species: selectedSpecies)
    }

    private var dateControl: some View {
        HStack(spacing: 10) {
            Image(systemName: timeOfDay.symbol)
                .foregroundStyle(timeOfDay.isPrimeLight ? .green : .secondary)
            DatePicker("Plan for", selection: $planDate)
                .labelsHidden()
            speciesMenu
            Spacer(minLength: 4)
            // Measured against actual width, not size class: narrow regular contexts
            // (iPad split view, Mac windows) crushed the hint and wrapped the button.
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) {
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(timeOfDay.label).font(.caption2.weight(.semibold))
                        Text(timeOfDay.lightHint)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    nowButton
                }
                HStack(spacing: 10) {
                    Text(timeOfDay.label)
                        .font(.caption2.weight(.semibold))
                        .fixedSize()
                    nowButton
                }
            }
        }
        .font(.caption2)
        .controlSize(.small)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .frame(maxWidth: sizeClass == .regular ? 560 : .infinity, alignment: .leading)
        .modifier(GlassCard())
        .padding(sizeClass == .regular ? 12 : 8)
    }

    private var nowButton: some View {
        Button("Now") { planDate = Date() }
            .font(.caption2.weight(.semibold))
            .buttonStyle(.bordered)
            .fixedSize()
    }

    private var speciesMenu: some View {
        Menu {
            Button("All species") { selectedSpecies = nil }
            Divider()
            ForEach(model.guide?.speciesNames ?? [], id: \.self) { name in
                Button(name) { selectedSpecies = name }
            }
        } label: {
            Label(selectedSpecies ?? "All species", systemImage: "fish")
                .font(.caption2.weight(.semibold))
                .lineLimit(1)
        }
        .fixedSize()
    }

    private var statusBar: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                if model.isLoading {
                    ProgressView()
                        .controlSize(.mini)
                }
                Text(model.statusMessage)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                Button { showHeat.toggle() } label: {
                    Label("Heat", systemImage: showHeat ? "flame.fill" : "flame")
                        .font(.caption2.weight(.semibold))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(showHeat ? .orange : .secondary)
                Button { showDisclaimer.toggle() } label: {
                    Image(systemName: "info.circle")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("About this guidance")
                .popover(isPresented: $showDisclaimer, arrowEdge: .bottom) {
                    Text("Tap a launch for what's biting. Guidance only — verify seasons in the Fish Washington app.")
                        .font(.caption)
                        .padding()
                        .frame(maxWidth: 280)
                        .presentationCompactAdaptation(.popover)
                }
            }
            if location.isDenied {
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        openURL(url)
                    }
                } label: {
                    Label("Location is off — turn it on in Settings", systemImage: "location.slash")
                        .font(.caption2)
                }
                .buttonStyle(.borderless)
            }
            if showHeat {
                HeatLegend()
            } else {
                RatingLegend()
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .frame(maxWidth: sizeClass == .regular ? 460 : .infinity, alignment: .leading)
        .modifier(GlassCard())
        .padding(sizeClass == .regular ? 12 : 8)
    }
}

/// Floating chrome card: Liquid Glass where available, material fallback earlier.
/// Rounded on both size classes so the bars float over the map instead of
/// spanning edge-to-edge on iPhone.
private struct GlassCard: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(.regular, in: .rect(cornerRadius: 14))
        } else {
            content.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
        }
    }
}

/// Cold-to-hot key shown while the heat overlay is on; mirrors ColorRamp.densityFill's ramp.
private struct HeatLegend: View {
    var body: some View {
        HStack(spacing: 6) {
            Text("Fewer").font(.caption2).foregroundStyle(.secondary)
            // Discrete swatches, one per band, because that is exactly what the
            // map draws — a continuous gradient promised a precision the banded
            // fills do not have.
            HStack(spacing: 2) {
                ForEach(0..<ColorRamp.densityBandCount, id: \.self) { band in
                    Rectangle()
                        .fill(ColorRamp.densityFill(band: band))
                        .frame(width: 20, height: 8)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 2))
            Text("More").font(.caption2).foregroundStyle(.secondary)
            Text("· density of well-rated spots").font(.caption2).foregroundStyle(.tertiary)
        }
    }
}

/// Compact color key for the marker ratings.
private struct RatingLegend: View {
    var body: some View {
        HStack(spacing: 10) {
            ForEach([FishingRating.excellent, .good, .fair, .poor], id: \.rawValue) { r in
                HStack(spacing: 3) {
                    Circle().fill(r.color).frame(width: 8, height: 8)
                    Text(r.label).font(.caption2).foregroundStyle(.secondary)
                }
            }
            HStack(spacing: 3) {
                Circle().fill(.gray).frame(width: 8, height: 8)
                Text("No data").font(.caption2).foregroundStyle(.secondary)
            }
        }
    }
}

/// Presents launch detail as a bottom sheet on iPhone (compact) and a trailing
/// inspector on iPad (regular), so it isn't a stretched phone sheet on the larger screen.
private struct AdaptiveDetail<Item: Identifiable, Detail: View>: ViewModifier {
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Binding var item: Item?
    @ViewBuilder let detail: (Item) -> Detail

    private var isPresented: Binding<Bool> {
        Binding(get: { item != nil }, set: { if !$0 { item = nil } })
    }

    @ViewBuilder func body(content: Content) -> some View {
        if sizeClass == .regular {
            content.inspector(isPresented: isPresented) {
                if let item { detail(item) } else { EmptyView() }
            }
        } else {
            content.sheet(item: $item) { site in
                detail(site)
                    .presentationDetents([.medium, .large])
                    .presentationBackgroundInteraction(.enabled(upThrough: .medium))
            }
        }
    }
}
