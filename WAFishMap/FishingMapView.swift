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
    @State private var showRivers = false
    /// The tapped river, by name. Overlays are not selectable the way
    /// annotations are, so the coordinator sets this from an explicit hit test.
    @State private var selectedRiverID: River.ID?
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
    @State private var showPlanPicker = false
    /// A one-shot camera move handed to the representable (the recentre-on-fix
    /// ease). MapKit's own delegate reports real pan/pinch touches, so the
    /// three-phase `CameraGuardPhase` machine this replaced is gone.
    @State private var focusRegion: MKCoordinateRegion?
    /// A one-shot recentre request; the representable resolves the coordinate
    /// because only it can read the map's live user location.
    @State private var recenterRequested = false
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

    /// Month from the selected plan date drives every rating on the map. Pacific,
    /// matching `TidePredictionsView`/`DaylightView` — the map's own solar and
    /// tide math must key off the same local day, not the device's time zone.
    private var currentMonth: Int {
        UITestSeam.planMonth ?? Calendar.pacific.component(.month, from: planDate)
    }

    /// Day of the month from the plan date, paired with `currentMonth` to place
    /// a reading in the right row of a river's day-of-year table.
    private var currentDay: Int {
        Calendar.pacific.component(.day, from: planDate)
    }

    /// Year from the plan date — drives odd/even-year species (Pink Salmon) via
    /// `model.setPlanYear`. Same Pacific rule as `currentMonth`/`currentDay`.
    private var currentYear: Int {
        PlanClock.year(for: planDate)
    }

    private var timeOfDay: TimeOfDay {
        if let solar = SolarTimes.compute(on: planDate, at: cameraCenter, calendar: .pacific) {
            return TimeOfDay(date: planDate, solar: solar)
        }
        return TimeOfDay(hour: Calendar.pacific.component(.hour, from: planDate))
    }

    var body: some View {
        FishingMapRepresentable(
            annotations: showsPins ? siteAnnotations : [],
            fitAnnotations: siteAnnotations,
            areas: model.marineAreas,
            areaColors: areaColors,
            protectedAreas: model.protectedAreas,
            heatZones: heatZones,
            rivers: model.rivers,
            riverColors: riverColors,
            showRivers: showRivers,
            showHeat: heatVisible,
            showAreaLabels: cameraDistance < Self.areaLabelMaxDistance,
            pointsOfInterest: landmarkCategories,
            selectedID: $model.selectedSiteID,
            selectedRiverID: $selectedRiverID,
            cameraDistance: $cameraDistance,
            cameraCenter: $cameraCenter,
            userMovedCamera: $userMovedCamera,
            focusRegion: $focusRegion,
            recenterRequested: $recenterRequested,
            locationFix: location.fix
        )
        .ignoresSafeArea()
        // Custom rather than `showsUserTrackingButton` (iOS 17+): that control
        // cycles follow/heading tracking modes, and this one is a single tap to a
        // fixed zoom that also marks the camera as user-claimed. The compass is
        // native (`showsCompass`).
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
                protectedAreaCheck: model.protectedAreaCheck(for: site),
                species: selectedSpecies,
                lake: model.lake(for: site)
            )
        })
        .modifier(AdaptiveDetail(item: selectedRiverBinding) { river in
            RiverDetailSheet(
                river: river,
                stats: model.stats(for: river),
                flow: model.flow(for: river),
                flowsLoaded: model.riverFlowsLoaded,
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
                planDate: planDate,
                protectedAreaCheck: model.protectedAreaCheck(for: pier),
                species: selectedSpecies
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
            // Before anything that could move the camera. Setting
            // userMovedCamera suppresses the ease onto the location fix, which
            // is the thing that made two screenshot runs incomparable.
            if let pinned = UITestSeam.region {
                focusRegion = MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: pinned.latitude,
                                                   longitude: pinned.longitude),
                    span: MKCoordinateSpan(latitudeDelta: pinned.span,
                                           longitudeDelta: pinned.span))
                userMovedCamera = true
            }
            location.requestIfNeeded()
            // Before `load`: it publishes the guide ahead of its network awaits.
            model.setPlanYear(currentYear)
            await model.load()
            if let river = model.initialRiverID { selectedRiverID = river }
            recomputeHeatZones()
        }
        .onChange(of: heatVisible) { recomputeHeatZones() }
        .onChange(of: Self.heatCellDegrees(cameraDistance)) { recomputeHeatZones() }
        .onChange(of: currentMonth) { recomputeHeatZones() }
        .onChange(of: currentYear) {
            model.setPlanYear(currentYear)
            recomputeHeatZones()
        }
        .onChange(of: selectedSpecies) { recomputeHeatZones() }
        .onChange(of: location.fix?.latitude) { recenterOnFixIfAppropriate() }
    }

    /// Pulled back far enough, individual pins are an unreadable mass; the
    /// density overlay carries the state-wide picture instead.
    private var showsPins: Bool {
        MapDetailLevel.showsPins(atCameraDistance: cameraDistance)
    }

    /// The user's toggle, plus the forced-on case where pins are hidden.
    /// Flow colour per river. A river with no gauge, or a gauge that reported
    /// nothing today, is simply absent here and draws neutral — the map never
    /// invents a reading to fill a gap.
    private var riverColors: [String: Color] {
        guard showRivers else { return [:] }
        return model.riverRatings(month: currentMonth, day: currentDay)
            .mapValues(\.color)
    }

    private var heatVisible: Bool {
        MapDetailLevel.showsHeat(userEnabled: showHeat, atCameraDistance: cameraDistance)
    }

    /// Sites and piers as MapKit annotations, ratings resolved up front.
    private var siteAnnotations: [SiteAnnotation] {
        model.accessSites.map {
            SiteAnnotation(site: $0, rating: rating(for: $0),
                           closurePlausible: model.closurePlausible(for: $0, month: currentMonth, species: selectedSpecies))
        }
            + model.piers.map {
                SiteAnnotation(pier: $0, rating: rating(for: $0),
                               closurePlausible: model.closurePlausible(for: $0, month: currentMonth, species: selectedSpecies))
            }
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
            recenterRequested = true
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

    /// `River` is already `Identifiable` by name, so the sheet binds to the
    /// river itself rather than to a wrapper around the name.
    private var selectedRiverBinding: Binding<River?> {
        Binding(
            get: { model.rivers.first { $0.id == selectedRiverID } },
            set: { selectedRiverID = $0?.id }
        )
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
        // The compact DatePicker's date and time pills ignore controlSize, so on
        // an iPhone one row overflowed the screen and pushed the card off both
        // edges. Measured against actual width, not size class: narrow regular
        // contexts (iPad split view, Mac windows) need the two-row form too.
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                planPicker
                speciesMenu
                Spacer(minLength: 4)
                timeOfDayHint
                nowButton
            }
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 10) {
                    planPicker
                    Spacer(minLength: 4)
                    nowButton
                }
                HStack(spacing: 10) {
                    speciesMenu
                    Spacer(minLength: 4)
                    timeOfDayHint
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

    /// One button that says when, and opens the picker when asked.
    ///
    /// This was a compact `DatePicker`, whose date and time pills ignore
    /// `controlSize` -- the comment on `dateControl` records that they
    /// overflowed an iPhone row and forced the whole bar onto two lines. One
    /// control fits, which is where most of the reclaimed height comes from.
    ///
    /// The symbol that used to sit beside it moved into `timeOfDayHint`; two
    /// copies of the same sun/moon glyph in one bar was the header spending
    /// width to say the same thing twice.
    private var planPicker: some View {
        Button { showPlanPicker.toggle() } label: {
            Label(Self.planLabel(planDate), systemImage: "calendar")
                .font(.caption2.weight(.semibold))
                .lineLimit(1)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .fixedSize()
        .accessibilityLabel("Plan for \(Self.planLabel(planDate))")
        .accessibilityHint("Opens a date and time picker")
        .accessibilityIdentifier("planDateButton")
        .popover(isPresented: $showPlanPicker, arrowEdge: .top) {
            DatePicker("Plan for", selection: $planDate)
                .datePickerStyle(.graphical)
                .labelsHidden()
                .padding()
                .frame(minWidth: 320)
                .presentationCompactAdaptation(.popover)
        }
    }

    /// "Sep 20, 2:33 AM" -- short enough for a chip, and it must carry both
    /// halves, since the two pills it replaces each carried one.
    static func planLabel(_ date: Date, calendar: Calendar = .pacific) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.calendar = calendar
        f.timeZone = calendar.timeZone
        f.dateFormat = "MMM d, h:mm a"
        return f.string(from: date)
    }

    /// One chip: glyph and word, nothing else.
    ///
    /// This used to carry `lightHint` as a second line -- a full sentence
    /// across the top of a map whose whole job is the map. The sentence is not
    /// wrong, it is just not worth a permanent line of chrome, so it moved to
    /// the info popover where a reader goes when they want the explanation.
    private var timeOfDayHint: some View {
        Label(timeOfDay.label, systemImage: timeOfDay.symbol)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(timeOfDay.isPrimeLight ? .green : .secondary)
            .labelStyle(.titleAndIcon)
            .fixedSize()
            .accessibilityLabel("\(timeOfDay.label). \(timeOfDay.lightHint)")
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
                Button { showRivers.toggle() } label: {
                    Label("Rivers", systemImage: "water.waves")
                        .font(.caption2.weight(.semibold))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(showRivers ? .teal : .secondary)
                Button { showHeat.toggle() } label: {
                    Label("Heat", systemImage: showHeat ? "flame.fill" : "flame")
                        .font(.caption2.weight(.semibold))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(showHeat ? .orange : .secondary)
                Button { showDisclaimer.toggle() } label: {
                    Image(systemName: "info.circle")
                        .font(.body)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("About this guidance")
                .accessibilityHint("Opens guidance disclaimer and WDFW link")
                .accessibilityIdentifier("guidanceInfoButton")
                .popover(isPresented: $showDisclaimer, arrowEdge: .bottom) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Tap a launch for what's biting. Guidance only — verify seasons in the Fish Washington app.")
                            .font(.caption)
                        // Was a permanent line in the header. It belongs where
                        // someone has asked for an explanation.
                        Label(timeOfDay.lightHint, systemImage: timeOfDay.symbol)
                            .font(.caption)
                            .foregroundStyle(timeOfDay.isPrimeLight ? .green : .secondary)
                        Text("Not for navigation or safety decisions.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if let urlString = model.guide?.wdfwURL, let url = URL(string: urlString) {
                            Link(destination: url) {
                                Label("Verify seasons & limits at WDFW", systemImage: "exclamationmark.shield")
                                    .font(.caption.weight(.semibold))
                            }
                            .accessibilityIdentifier("wdfwLink")
                        }
                    }
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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Heat map key: darker cells have more well-rated spots")
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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Map key: red Prime, orange Good, yellow Fair, blue Slow, gray No data. "
            + "An outlined pin means the season may be closed; a faded gray pin is closed.")
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
                    // At the medium detent the sheet sat over a live, heat-washed
                    // map and the body rows were read against green-blue mottling.
                    // Opaque enough to read on, still clearly a layer over the map.
                    .presentationBackground(.thickMaterial)
            }
        }
    }
}
