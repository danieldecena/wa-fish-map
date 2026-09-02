import MapKit
import SwiftUI

struct FishingMapView: View {
    @State private var model = FishingMapModel()
    @Environment(\.openURL) private var openURL
    @State private var location = LocationProvider()
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
    /// A one-shot camera move handed to the representable (the recentre-on-fix
    /// ease). MapKit's own delegate reports real pan/pinch touches, so the
    /// three-phase `CameraGuardPhase` machine this replaced is gone.
    @State private var focusRegion: MKCoordinateRegion?
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
        UITestSeam.planMonth ?? Calendar.current.component(.month, from: planDate)
    }

    private var timeOfDay: TimeOfDay {
        if let solar = SolarTimes.compute(on: planDate, at: cameraCenter) {
            return TimeOfDay(date: planDate, solar: solar)
        }
        return TimeOfDay(hour: Calendar.current.component(.hour, from: planDate))
    }

    var body: some View {
        FishingMapRepresentable(
            annotations: showsPins ? siteAnnotations : [],
            areas: model.marineAreas,
            areaColors: areaColors,
            protectedAreas: model.protectedAreas,
            heatZones: heatZones,
            showHeat: heatVisible,
            showAreaLabels: cameraDistance < Self.areaLabelMaxDistance,
            pointsOfInterest: landmarkCategories,
            selectedID: $model.selectedSiteID,
            cameraDistance: $cameraDistance,
            cameraCenter: $cameraCenter,
            userMovedCamera: $userMovedCamera,
            focusRegion: $focusRegion
        )
        .ignoresSafeArea()
        // `MKMapView` has no built-in recentre control, so `MapUserLocationButton`
        // is rebuilt by hand. The compass is native (`showsCompass`).
        .overlay(alignment: .topTrailing) { recenterButton }
        .safeAreaInset(edge: .top) { dateControl }
        .safeAreaInset(edge: .bottom) { statusBar }
        .modifier(AdaptiveDetail(item: selectedSiteBinding) { site in
            SiteDetailSheet(
                site: site,
                fishery: model.fishery(for: site),
                isMarine: model.isMarine(site),
                guide: model.guide,
                planDate: planDate,
                protectedAreaCheck: model.protectedAreaCheck(for: site)
            )
        })
        .modifier(AdaptiveDetail(item: selectedPierBinding) { pier in
            PierDetailSheet(
                pier: pier,
                fishery: model.fishery(for: pier),
                isMarine: model.isMarine(pier),
                guide: model.guide,
                planDate: planDate,
                protectedAreaCheck: model.protectedAreaCheck(for: pier)
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
        }
        .onChange(of: heatVisible) { recomputeHeatZones() }
        .onChange(of: Self.heatCellDegrees(cameraDistance)) { recomputeHeatZones() }
        .onChange(of: currentMonth) { recomputeHeatZones() }
        .onChange(of: selectedSpecies) { recomputeHeatZones() }
        .onChange(of: location.fix?.latitude) { recenterOnFixIfAppropriate() }
    }

    /// Pulled back far enough, individual pins are an unreadable mass; the
    /// density overlay carries the state-wide picture instead.
    private var showsPins: Bool {
        MapDetailLevel.showsPins(atCameraDistance: cameraDistance)
    }

    /// The user's toggle, plus the forced-on case where pins are hidden.
    private var heatVisible: Bool {
        MapDetailLevel.showsHeat(userEnabled: showHeat, atCameraDistance: cameraDistance)
    }

    /// Sites and piers as MapKit annotations, ratings resolved up front.
    private var siteAnnotations: [SiteAnnotation] {
        model.accessSites.map { SiteAnnotation(site: $0, rating: rating(for: $0)) }
            + model.piers.map { SiteAnnotation(pier: $0, rating: rating(for: $0)) }
    }

    private var areaColors: [String: Color] {
        var colors: [String: Color] = [:]
        for area in model.marineAreas { colors[area.id] = color(forArea: area) }
        return colors
    }

    // MARK: Rating → color (nil rating renders neutral gray)

    private func color(forArea area: MarineArea) -> Color {
        (model.guide?.area(named: area.areaName)?.rating(inMonth: currentMonth, species: selectedSpecies)?.color) ?? .gray
    }

    private func color(forSite site: AccessSite) -> Color {
        rating(for: site)?.color ?? .gray
    }

    // MARK: Heat zones (density of good-rated spots, cold→hot)

    /// Cached in state; zones only change with the toggle, the plan month, the
    /// species filter, a data load, or the camera-distance band.
    private func recomputeHeatZones() {
        guard heatVisible else {
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
        focusRegion = MKCoordinateRegion(
            center: fix,
            span: MKCoordinateSpan(latitudeDelta: 0.9, longitudeDelta: 0.9)
        )
    }

    private var recenterButton: some View {
        Button {
            guard let fix = location.fix else { return }
            userMovedCamera = true
            focusRegion = MKCoordinateRegion(
                center: fix,
                span: MKCoordinateSpan(latitudeDelta: 0.2, longitudeDelta: 0.2)
            )
        } label: {
            Image(systemName: "location.fill")
                .font(.system(size: 15, weight: .medium))
                .frame(width: 36, height: 36)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        }
        .accessibilityLabel("Center on my location")
        .padding(.trailing, 10)
        .padding(.top, 6)
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
            // Follows what is actually drawn, not the toggle: zoomed out the
            // overlay is forced on, and a rating legend over a heat map lies.
            if heatVisible {
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
