import MapKit
import SwiftUI

struct FishingMapView: View {
    @State private var model = FishingMapModel()
    @State private var location = LocationProvider()
    @State private var position: MapCameraPosition = .automatic
    @Environment(\.horizontalSizeClass) private var sizeClass

    /// POIs worth showing an angler (instead of hiding all landmarks).
    private let landmarkCategories: [MKPointOfInterestCategory] = [
        .marina, .park, .campground, .nationalPark, .parking, .publicTransport, .gasStation
    ]

    /// Current calendar month drives the ratings. Injected here only; all rating logic
    /// lives in `AreaFishery` and is tested with an explicit month (no clock).
    private var currentMonth: Int {
        Calendar.current.component(.month, from: Date())
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
            ForEach(model.accessSites) { site in
                Marker(site.facilityName,
                       systemImage: site.hasLaunch ? "anchor.fill" : "figure.fishing",
                       coordinate: site.mapCoordinate)
                    .tint(color(forSite: site))
                    .tag(site.id)
            }
            ForEach(model.piers) { pier in
                Marker(pier.name, systemImage: "building.columns", coordinate: pier.mapCoordinate)
                    .tint(model.rating(for: pier, month: currentMonth)?.color ?? .gray)
            }
            UserAnnotation()
        }
        .mapStyle(.standard(pointsOfInterest: .including(landmarkCategories)))
        .mapControls {
            MapUserLocationButton()
            MapCompass()
        }
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

    private var selectedSiteBinding: Binding<AccessSite?> {
        Binding(
            get: { model.selectedSite },
            set: { model.selectedSiteID = $0?.id }
        )
    }

    private var statusBar: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(model.statusMessage)
                .font(.caption)
                .foregroundStyle(.secondary)
            RatingLegend()
            Text("Tap a launch for what's biting. Guidance only — verify seasons in the Fish Washington app.")
                .font(.caption2)
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
