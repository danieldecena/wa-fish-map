import MapKit
import SwiftUI

struct FishingMapView: View {
    @State private var model = FishingMapModel()
    @State private var location = LocationProvider()
    @State private var position = MapCameraPosition.region(
        MKCoordinateRegion(
            center: MapScope.cameraCenter.clLocationCoordinate,
            span: MKCoordinateSpan(
                latitudeDelta: MapScope.cameraSpanDegrees,
                longitudeDelta: MapScope.cameraSpanDegrees
            )
        )
    )

    /// Current calendar month drives the rating. Injected here only; all rating logic
    /// lives in `AreaFishery` and is tested with an explicit month (no clock).
    private var currentMonth: Int {
        Calendar.current.component(.month, from: Date())
    }

    private var rating: FishingRating {
        model.fishery?.rating(inMonth: currentMonth) ?? .poor
    }

    var body: some View {
        Map(position: $position, selection: $model.selectedSiteID) {
            ForEach(model.marineAreas) { area in
                MapPolygon(coordinates: area.mapCoordinates)
                    .foregroundStyle(rating.color.opacity(0.18))
                    .stroke(rating.color, lineWidth: 1)
            }
            ForEach(model.accessSites) { site in
                Marker(site.facilityName, systemImage: "anchor.fill", coordinate: site.mapCoordinate)
                    .tint(rating.color)
                    .tag(site.id)
            }
            UserAnnotation()
        }
        .mapStyle(.standard(pointsOfInterest: .excludingAll))
        .mapControls {
            MapUserLocationButton()
            MapCompass()
        }
        .safeAreaInset(edge: .bottom) { statusBar }
        .sheet(item: selectedSiteBinding) { site in
            SiteDetailSheet(
                site: site,
                guide: model.guide,
                areaName: model.areaName,
                month: currentMonth
            )
            .presentationDetents([.medium, .large])
            .presentationBackgroundInteraction(.enabled(upThrough: .medium))
        }
        .task {
            location.requestIfNeeded()
            await model.load()
        }
    }

    private var selectedSiteBinding: Binding<AccessSite?> {
        Binding(
            get: { model.selectedSite },
            set: { model.selectedSiteID = $0?.id }
        )
    }

    private var statusBar: some View {
        HStack(spacing: 10) {
            RatingBadge(rating: rating)
            VStack(alignment: .leading, spacing: 2) {
                Text(model.statusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Tap a launch for what's biting. Guidance only — verify seasons in the Fish Washington app.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial)
    }
}
