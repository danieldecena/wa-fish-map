import MapKit
import SwiftUI

struct FishingMapView: View {
    @State private var model = FishingMapModel()
    @State private var location = LocationProvider()
    @State private var position: MapCameraPosition = .automatic
    /// Date/time the user is planning for. Defaults to now; the month drives ratings.
    @State private var planDate = Date()
    @State private var showHeat = false
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
        TimeOfDay(hour: Calendar.current.component(.hour, from: planDate))
    }

    var body: some View {
        Map(position: $position, selection: $model.selectedSiteID) {
            ForEach(model.marineAreas) { area in
                MapPolygon(coordinates: area.mapCoordinates)
                    .foregroundStyle(color(forArea: area).opacity(0.18))
                    .stroke(color(forArea: area), lineWidth: 1)
                Annotation("Area \(area.areaName)", coordinate: area.center) {
                    Text("MA \(area.areaName)")
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 5).padding(.vertical, 2)
                        .background(.ultraThinMaterial, in: Capsule())
                }
                .annotationTitles(.hidden)
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
        .sheet(item: selectedPierBinding) { pier in
            PierDetailSheet(
                pier: pier,
                fishery: model.fishery(atCoordinate: pier.coordinate, county: pier.countyName),
                isMarine: model.isMarine(coordinate: pier.coordinate),
                guide: model.guide,
                month: currentMonth
            )
            .presentationDetents([.medium, .large])
        }
        .task {
            location.requestIfNeeded()
            await model.load()
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

    private var heatZones: [HeatZone] {
        guard showHeat else { return [] }
        var points: [(coord: LonLat, weight: Double)] = []
        for site in model.accessSites {
            points.append((site.coordinate, heatWeight(model.rating(for: site, month: currentMonth))))
        }
        for pier in model.piers {
            points.append((pier.coordinate, heatWeight(model.rating(for: pier, month: currentMonth))))
        }
        return HeatMap.zones(points: points, cellDegrees: 0.15)
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
            VStack(alignment: .trailing, spacing: 1) {
                Text(timeOfDay.label).font(.caption2.weight(.semibold))
                Text(timeOfDay.lightHint).font(.system(size: 9)).foregroundStyle(.secondary)
            }
            Button("Now") { planDate = Date() }
                .font(.caption2.weight(.semibold))
                .buttonStyle(.bordered)
        }
        .font(.caption2)
        .controlSize(.small)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .frame(maxWidth: sizeClass == .regular ? 560 : .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: sizeClass == .regular ? 14 : 0))
        .padding(sizeClass == .regular ? 12 : 0)
    }

    private var statusBar: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
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
            }
            RatingLegend()
            Text("Tap a launch for what's biting. Guidance only — verify seasons in the Fish Washington app.")
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .frame(maxWidth: sizeClass == .regular ? 460 : .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: sizeClass == .regular ? 14 : 0))
        .padding(sizeClass == .regular ? 12 : 0)
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
private struct AdaptiveDetail<Detail: View>: ViewModifier {
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Binding var item: AccessSite?
    @ViewBuilder let detail: (AccessSite) -> Detail

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
