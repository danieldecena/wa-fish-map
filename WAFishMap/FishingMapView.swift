import MapKit
import SwiftUI

struct FishingMapView: View {
    @State private var model = FishingMapModel()
    @State private var location = LocationProvider()
    @State private var position: MapCameraPosition = .automatic
    /// Date/time the user is planning for. Defaults to now; the month drives ratings.
    @State private var planDate = Date()
    @State private var showHeat = false
    @State private var showDisclaimer = false
    @State private var heatZones: [HeatZone] = []
    /// Camera altitude in meters; starts far out so area labels stay hidden until the
    /// first camera event. Below the threshold the "MA n" capsules stop overlapping.
    @State private var cameraDistance: Double = .greatestFiniteMagnitude
    private static let areaLabelMaxDistance: Double = 600_000
    /// Where the user is looking; drives the sun-time math. Statewide the east-west
    /// sunrise spread is ~10 minutes, so camera-center precision is plenty.
    @State private var cameraCenter = MapScope.cameraCenter
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
                    .foregroundStyle(color(forArea: area).opacity(0.18))
                    .stroke(color(forArea: area), lineWidth: 1)
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
                MapCircle(center: zone.center.clLocationCoordinate, radius: 9000)
                    .foregroundStyle(heatColor(zone.intensity).opacity(0.30))
            }
            ForEach(model.accessSites) { site in
                Marker(site.facilityName,
                       systemImage: site.hasLaunch ? "anchor.fill" : "figure.fishing",
                       coordinate: site.mapCoordinate)
                    .tint(color(forSite: site))
                    .tag(site.id)
            }
            ForEach(model.piers) { pier in
                Marker(pier.name, systemImage: "fish.fill", coordinate: pier.mapCoordinate)
                    .tint(model.rating(for: pier, month: currentMonth)?.color ?? .gray)
                    .tag(pier.id)
            }
            UserAnnotation()
        }
        .mapStyle(.standard(pointsOfInterest: .including(landmarkCategories)))
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
                month: currentMonth
            )
        })
        .modifier(AdaptiveDetail(item: selectedPierBinding) { pier in
            PierDetailSheet(
                pier: pier,
                fishery: model.fishery(for: pier),
                isMarine: model.isMarine(pier),
                guide: model.guide,
                month: currentMonth
            )
        })
        .task {
            location.requestIfNeeded()
            await model.load()
            recomputeHeatZones()
        }
        .onChange(of: showHeat) { recomputeHeatZones() }
        .onChange(of: currentMonth) { recomputeHeatZones() }
        .onMapCameraChange(frequency: .onEnd) { context in
            cameraDistance = context.camera.distance
            cameraCenter = LonLat(
                longitude: context.camera.centerCoordinate.longitude,
                latitude: context.camera.centerCoordinate.latitude
            )
        }
    }

    // MARK: Rating → color (nil rating renders neutral gray)

    private func color(forArea area: MarineArea) -> Color {
        (model.guide?.area(named: area.areaName)?.rating(inMonth: currentMonth).color) ?? .gray
    }

    private func color(forSite site: AccessSite) -> Color {
        (model.rating(for: site, month: currentMonth)?.color) ?? .gray
    }

    // MARK: Heat zones (density of good-rated spots, cold→hot)

    /// Cached in state; zones only change with the toggle, the plan month, or a data
    /// load, so they are recomputed there instead of on every body evaluation.
    private func recomputeHeatZones() {
        guard showHeat else {
            heatZones = []
            return
        }
        var points: [(coord: LonLat, weight: Double)] = []
        for site in model.accessSites {
            points.append((site.coordinate, heatWeight(model.rating(for: site, month: currentMonth))))
        }
        for pier in model.piers {
            points.append((pier.coordinate, heatWeight(model.rating(for: pier, month: currentMonth))))
        }
        heatZones = HeatMap.zones(points: points, cellDegrees: 0.15)
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

    /// Cold (blue) → hot (red) through purple midtones — deliberately distinct from the
    /// green/yellow/orange/red marker rating palette.
    private func heatColor(_ intensity: Double) -> Color {
        Color(red: intensity, green: 0.1, blue: 1 - intensity)
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

    private var dateControl: some View {
        HStack(spacing: 10) {
            Image(systemName: timeOfDay.symbol)
                .foregroundStyle(timeOfDay.isPrimeLight ? .green : .secondary)
            DatePicker("Plan for", selection: $planDate)
                .labelsHidden()
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

/// Cold-to-hot key shown while the heat overlay is on; mirrors heatColor's ramp.
private struct HeatLegend: View {
    var body: some View {
        HStack(spacing: 6) {
            Text("Cold").font(.caption2).foregroundStyle(.secondary)
            LinearGradient(
                colors: [
                    Color(red: 0, green: 0.1, blue: 1),
                    Color(red: 0.5, green: 0.1, blue: 0.5),
                    Color(red: 1, green: 0.1, blue: 0)
                ],
                startPoint: .leading, endPoint: .trailing
            )
            .frame(width: 90, height: 8)
            .clipShape(Capsule())
            Text("Hot").font(.caption2).foregroundStyle(.secondary)
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
