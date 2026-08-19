import MapKit
import SwiftUI

struct FishingMapView: View {
    @State private var model = FishingMapModel()
    @State private var position = MapCameraPosition.region(
        MKCoordinateRegion(
            center: MapScope.cameraCenter.clLocationCoordinate,
            span: MKCoordinateSpan(
                latitudeDelta: MapScope.cameraSpanDegrees,
                longitudeDelta: MapScope.cameraSpanDegrees
            )
        )
    )

    var body: some View {
        Map(position: $position, selection: $model.selectedSiteID) {
            ForEach(model.marineAreas) { area in
                MapPolygon(coordinates: area.mapCoordinates)
                    .foregroundStyle(.cyan.opacity(0.22))
                    .stroke(.cyan, lineWidth: 1)
            }
            ForEach(model.accessSites) { site in
                Marker(site.facilityName, systemImage: "anchor.fill", coordinate: site.mapCoordinate)
                    .tint(.orange)
                    .tag(site.id)
            }
        }
        .mapStyle(.hybrid(elevation: .realistic))
        .safeAreaInset(edge: .bottom) {
            VStack(alignment: .leading, spacing: 8) {
                if let site = model.selectedSite {
                    Text(site.facilityName).font(.headline)
                    Text("\(site.countyName) County · \(site.launchSurface.label)")
                        .font(.subheadline)
                    if !site.directions.isEmpty {
                        Text(site.directions).font(.caption)
                    }
                }
                Text(MapScope.disclaimer)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(.ultraThinMaterial)
        }
        .task {
            try? model.loadFromBundle(bundle: .main)
        }
    }
}
