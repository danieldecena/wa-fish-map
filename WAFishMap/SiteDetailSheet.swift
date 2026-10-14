import SwiftUI

/// Small colored capsule showing the rating. `nil` renders neutral gray — used for
/// spots with no curated season data yet.
struct RatingBadge: View {
    let rating: FishingRating?

    private var color: Color { rating?.color ?? DS.Rating.unrated }
    private var label: String { rating?.label ?? "No data" }

    /// The label is deliberately *not* the rating colour.
    ///
    /// It used to be, on a 20% wash of that same colour, which put both sides
    /// of the contrast ratio on the same slider: the lighter the stop, the
    /// lighter its own background. Measured in light appearance every state
    /// failed 4.5:1 and Fair reached 1.38:1. Dark appearance passed throughout,
    /// because the wash over a near-black surface stays dark while the ramp
    /// colour stays bright -- which is why this was invisible to anyone
    /// testing in dark.
    ///
    /// `.primary` adapts to both appearances and leaves the ramp doing the job
    /// it is good at: the fill and the stroke still encode the rating, so no
    /// information is lost by taking it off the text.
    /// `RatingBadgeContrastTests` holds the measurements.
    static func labelColor(for rating: FishingRating?) -> Color {
        .primary
    }

    var body: some View {
        Text(label)
            .font(.caption.bold())
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(color.opacity(0.2), in: Capsule())
            .foregroundStyle(Self.labelColor(for: rating))
            .accessibilityLabel(rating.map { "Rated \($0.label)" } ?? "No seasonal guidance")
            .overlay(Capsule().stroke(color, lineWidth: 1))
    }
}

/// Opens Apple Maps with driving directions to the spot. A maps.apple.com
/// link, not `MKMapItem`: its coordinate initializer is iOS 26 only and the
/// placemark one is deprecated there, while this app targets iOS 18.
struct DirectionsButton: View {
    let name: String
    let coordinate: LonLat

    /// iOS 18.4 adopted Apple's unified Maps URLs. Its `/directions` path lists no
    /// name parameter, so the spot's name rides only on the legacy link.
    static func url(name: String, coordinate: LonLat) -> URL? {
        let destination = "\(coordinate.latitude),\(coordinate.longitude)"
        if #available(iOS 18.4, *) {
            var components = URLComponents(string: "https://maps.apple.com/directions")
            components?.queryItems = [
                URLQueryItem(name: "destination", value: destination),
                URLQueryItem(name: "mode", value: "driving"),
            ]
            return components?.url
        }
        var components = URLComponents(string: "https://maps.apple.com/")
        components?.queryItems = [
            URLQueryItem(name: "daddr", value: destination),
            URLQueryItem(name: "dirflg", value: "d"),
            URLQueryItem(name: "q", value: name),
        ]
        return components?.url
    }

    var body: some View {
        if let url = Self.url(name: name, coordinate: coordinate) {
            Link(destination: url) {
                Label("Directions in Maps", systemImage: "car.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("directionsButton")
        }
    }
}

/// Shared "what's biting" list, used by both the launch and pier detail sheets.
struct BitingNowView: View {
    let fishery: AreaFishery?
    let month: Int

    private var inSeason: [SpeciesSeason] { fishery?.inSeason(month: month) ?? [] }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("What's biting").font(.headline)
                .accessibilityIdentifier("whatsBitingHeading")
            if fishery == nil {
                Text("No seasonal guidance for this spot's area yet. Marker shown neutral.")
                    .font(.subheadline).foregroundStyle(.secondary)
            } else if inSeason.isEmpty {
                Text("Nothing is peaking here this month. Check back closer to a run, and confirm openings with WDFW.")
                    .font(.subheadline).foregroundStyle(.secondary)
            } else {
                ForEach(inSeason, id: \.species) { s in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            RatingBadge(rating: s.rating(inMonth: month))
                            // Counts the species on screen for the UI test. It sits
                            // on the name, not the card: an identifier on the card
                            // container makes SwiftUI collapse it into one element
                            // and the badge inside stops being queryable.
                            Text(s.species).font(.subheadline.weight(.semibold))
                                .accessibilityIdentifier("speciesName")
                            if let size = SpeciesSize.typical(for: s.species) {
                                Spacer(minLength: 8)
                                VStack(spacing: 0) {
                                    FishSilhouette(form: size.form)
                                        .fill(.secondary)
                                        .frame(width: size.iconPointSize * 1.15,
                                               height: size.iconPointSize * 1.15 * size.form.aspect)
                                        .frame(width: 56, height: 36)
                                    Text(size.range).font(.caption2).foregroundStyle(.secondary)
                                }
                                .accessibilityElement(children: .ignore)
                                .accessibilityLabel("Typical size \(size.range)")
                            }
                        }
                        if s.riskMonths.contains(month) {
                            Label("Season varies — verify", systemImage: "exclamationmark.triangle")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .accessibilityIdentifier("verifyBadge")
                        }
                        // Was "Best months: Jun, Jul, Aug". That reads the
                        // same as "Mar, Jul, Nov" while being a completely
                        // different fishery, so the shape is drawn instead.
                        SeasonRibbon(season: s, month: month)
                            .padding(.top, 2)
                        if let bestTime = s.bestTime {
                            Label("Best time: \(bestTime)", systemImage: "clock")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        if s.riskMonths.contains(month), let why = s.riskReason {
                            Text(why)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        if let bait = s.bait {
                            Label(bait, systemImage: "fish")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        if let note = s.note {
                            Text(note).font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
                }
            }
        }
    }

}

/// Shared "Before you go" disclaimer + WDFW link, used by both detail sheets.
struct GuidanceFooter: View {
    let guide: FisheryGuide?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Before you go").font(.headline)
            if let urlString = guide?.wdfwURL, let url = URL(string: urlString) {
                Link(destination: url) {
                    Label("Verify seasons & limits at WDFW", systemImage: "exclamationmark.shield")
                        .font(.subheadline.weight(.semibold))
                }
                .accessibilityIdentifier("wdfwLink")
            }
            if let disclaimer = guide?.disclaimer {
                Text(disclaimer).font(.caption).foregroundStyle(.secondary)
                    .accessibilityIdentifier("guidanceDisclaimer")
            }
            Text("Not for navigation or safety decisions.")
                .font(.caption)
                .foregroundStyle(.secondary)
            if let updated = guide?.updated {
                Text("Guidance updated \(updated)").font(.caption2).foregroundStyle(.tertiary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        // Neutral, not yellow: a yellow wash is also the Fair rating, and both
        // appear on this sheet — a reader had no way to tell a caution from a
        // rating. The shield glyph and the heading carry the caution.
        .background(DS.Surface.advisory,
                    in: RoundedRectangle(cornerRadius: DS.Surface.advisoryRadius))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("guidanceFooter")
    }
}

/// The MPA qualifier, shared by the launch and pier sheets. Shown above "What's
/// biting" so it is read before the guidance it qualifies.
///
/// `unavailable` gets its own row: a spot whose MPA check never ran must not
/// render identically to one that came back clear.
struct ProtectedAreaSection: View {
    let check: ProtectedAreaCheck

    var body: some View {
        switch check {
        case .inside(let mpa):
            VStack(alignment: .leading, spacing: 4) {
                Label(mpa.headline, systemImage: "exclamationmark.shield")
                    .font(.subheadline.weight(.semibold))
                Text(mpa.detailLine)
                    .font(.caption)
                if let url = mpa.detailURL {
                    Link("WDFW details", destination: url).font(.caption)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.orange.opacity(0.14), in: RoundedRectangle(cornerRadius: 10))
        case .unavailable:
            VStack(alignment: .leading, spacing: 4) {
                Label("Protected-area check unavailable", systemImage: "questionmark.circle")
                    .font(.subheadline.weight(.semibold))
                Text("WDFW's protected-area layer didn't load, so this app can't say whether this spot sits in one. Check WDFW.")
                    .font(.caption)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.gray.opacity(0.14), in: RoundedRectangle(cornerRadius: 10))
        case .clear:
            EmptyView()
        }
    }
}

/// WDFW's own facts for the lake a launch sits on. Everything here is WDFW's
/// per-lake data, so it is true of the whole lake and bypasses the scoped notes
/// in `fisheries.json`.
struct LakeFactsSection: View {
    let lake: Lake

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Lake facts (WDFW)").font(.headline)
            Text(lake.name).font(.subheadline.weight(.semibold))
            if let acres = lake.acres {
                Label("\(acres.formatted(.number.precision(.fractionLength(0...1)))) acres", systemImage: "ruler")
            }
            if let elevation = lake.elevationFeet {
                Label("\(elevation.formatted()) ft elevation", systemImage: "mountain.2")
            }
            if let ramp = lake.boatRamp {
                Label("Boat ramp: \(ramp)", systemImage: "ferry")
            }
            if let access = lake.shorelineAccess {
                Label("Shoreline access: \(access)", systemImage: "figure.fishing")
            }
            if let management = lake.management {
                Label(management, systemImage: "building.columns")
            }
            if !lake.species.isEmpty {
                Label("WDFW lists: \(lake.species.joined(separator: ", "))", systemImage: "fish")
            }
            if let urlString = lake.websiteURL, let url = URL(string: urlString) {
                Link("WDFW lake page", destination: url)
            }
            Text("From WDFW's lowland lakes map (2014). Species listed are not a stocking or season guarantee.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .font(.subheadline)
        .accessibilityIdentifier("lakeFactsSection")
    }
}

/// Detail shown when a launch/shore marker is tapped.
struct SiteDetailSheet: View {
    let site: AccessSite
    let fishery: AreaFishery?
    let isMarine: Bool
    let guide: FisheryGuide?
    let planDate: Date
    var protectedAreaCheck: ProtectedAreaCheck = .unavailable
    /// The map's species filter, if any. Threaded through so the header badge
    /// agrees with the pin colour, which is already species-aware
    /// (`FishingMapModel.rating(for:month:species:)`).
    var species: String? = nil
    /// The WDFW lake this launch sits on, when `Lake.match` found exactly one.
    var lake: Lake? = nil

    private var month: Int { PlanClock.month(for: planDate) }
    private var rating: FishingRating? { fishery?.rating(inMonth: month, species: species) }
    private var inSeason: [SpeciesSeason] { fishery?.inSeason(month: month) ?? [] }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    // The guidance leads: it is what the medium detent shows
                    // and the one thing this app knows that Maps does not.
                    // The protected-area qualifier stays above it and the
                    // footer right after it, since both qualify it.
                    ProtectedAreaSection(check: protectedAreaCheck)
                    BitingNowView(fishery: fishery, month: month)
                    GuidanceFooter(guide: guide)
                    facilitySection
                    DirectionsButton(name: site.facilityName, coordinate: site.coordinate)
                    amenitiesSection
                    if let lake { LakeFactsSection(lake: lake) }
                    DaylightView(coordinate: site.coordinate, planDate: planDate)
                    TidePredictionsView(
                        coordinate: site.coordinate,
                        planDate: planDate,
                        isMarine: isMarine
                    )
                    BuoyConditionsView(coordinate: site.coordinate, isMarine: isMarine)
                    PlanWeatherView(coordinate: site.coordinate, planDate: planDate)
                    if !site.directions.isEmpty { directionsSection }
                }
                .padding()
            }
            .navigationTitle(site.facilityName)
            .navigationBarTitleDisplayMode(.inline)
            // The badge + subtitle row is the first thing in the scroll view, so
            // a transparent bar let the title draw straight through it
            // ("Public fishin{Les Davis Pier}g pier"). An opaque bar gives the
            // content something to scroll under instead of into.
            .toolbarBackground(.visible, for: .navigationBar)
        }
        // Lets a UI test wait for the sheet before asserting the *absence* of the
        // verify badge; without it an absence check can pass by running early.
        .accessibilityIdentifier("siteDetailSheet")
    }

    private var header: some View {
        HStack(spacing: 10) {
            RatingBadge(rating: rating)
            Text(headerSummary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var headerSummary: String {
        if fishery == nil {
            return site.countyName.isEmpty ? "Launch" : "\(site.countyName) County"
        }
        if inSeason.isEmpty { return "No standout species this month" }
        return "Biting now: \(inSeason.prefix(2).map(\.species).joined(separator: ", "))"
    }

    private var facilitySection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("\(site.countyName) County", systemImage: "mappin.and.ellipse")
            Label(isMarine ? "Marine water" : "Freshwater",
                  systemImage: isMarine ? "water.waves" : "drop")
            Label(site.hasLaunch ? "\(site.launchSurface.label) boat launch" : "Shore / bank access",
                  systemImage: site.hasLaunch ? "ferry" : "figure.fishing")
            Label(site.hasRestrooms ? "Restrooms on site" : "No restrooms",
                  systemImage: site.hasRestrooms ? "checkmark.circle" : "xmark.circle")
                .foregroundStyle(site.hasRestrooms ? .primary : .secondary)
        }
        .font(.subheadline)
    }

    @ViewBuilder private var amenitiesSection: some View {
        let hasAmenities = site.hasCamping || site.ada.any
            || !site.openDates.isEmpty || !site.publicNotes.isEmpty
        if hasAmenities {
            VStack(alignment: .leading, spacing: 6) {
                if site.hasCamping {
                    Label("Camping", systemImage: "tent")
                }
                if site.ada.any {
                    Label(adaSummary, systemImage: "figure.roll")
                }
                if !site.openDates.isEmpty {
                    Label("Open: \(site.openDates)", systemImage: "calendar")
                }
                if !site.publicNotes.isEmpty {
                    Text(site.publicNotes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .font(.subheadline)
        }
    }

    private var adaSummary: String {
        var parts: [String] = []
        if site.ada.parking { parts.append("parking") }
        if site.ada.restroom { parts.append("restroom") }
        if site.ada.dock { parts.append("dock") }
        if site.ada.boatLaunch { parts.append("launch") }
        return "ADA access: " + parts.joined(separator: ", ")
    }

    private var directionsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Directions").font(.headline)
            Text(site.directions).font(.caption).foregroundStyle(.secondary)
        }
    }
}

/// Detail shown when a public fishing pier is tapped.
struct PierDetailSheet: View {
    let pier: FishingPier
    let fishery: AreaFishery?
    let isMarine: Bool
    let guide: FisheryGuide?
    let planDate: Date
    var protectedAreaCheck: ProtectedAreaCheck = .unavailable
    /// The map's species filter, if any. Threaded through so the header badge
    /// agrees with the pin colour, which is already species-aware — mirrors
    /// `SiteDetailSheet.species`.
    var species: String? = nil

    private var month: Int { PlanClock.month(for: planDate) }
    private var rating: FishingRating? { fishery?.rating(inMonth: month, species: species) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(spacing: 10) {
                        if pier.isClosed {
                            Label("Closed", systemImage: "xmark.octagon.fill")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(.gray, in: Capsule())
                                .accessibilityIdentifier("closedBadge")
                        } else {
                            RatingBadge(rating: rating)
                        }
                        Text("Public fishing pier").font(.subheadline).foregroundStyle(.secondary)
                    }
                    if pier.isClosed {
                        Text("WDFW lists this pier as closed. Check the WDFW page before you go.")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    ProtectedAreaSection(check: protectedAreaCheck)
                    BitingNowView(fishery: fishery, month: month)
                    GuidanceFooter(guide: guide)
                    VStack(alignment: .leading, spacing: 6) {
                        Label("\(pier.countyName) County", systemImage: "mappin.and.ellipse")
                        Label(isMarine ? "Marine water" : "Freshwater",
                              systemImage: isMarine ? "water.waves" : "drop")
                        if let url = URL(string: pier.websiteURL), !pier.websiteURL.isEmpty {
                            Link(destination: url) {
                                Label("Pier details (WDFW)", systemImage: "link")
                            }
                        }
                    }
                    .font(.subheadline)
                    DirectionsButton(name: pier.name, coordinate: pier.coordinate)
                    DaylightView(coordinate: pier.coordinate, planDate: planDate)
                    TidePredictionsView(
                        coordinate: pier.coordinate,
                        planDate: planDate,
                        isMarine: isMarine
                    )
                    BuoyConditionsView(coordinate: pier.coordinate, isMarine: isMarine)
                    PlanWeatherView(coordinate: pier.coordinate, planDate: planDate)
                }
                .padding()
            }
            .navigationTitle(pier.name)
            .navigationBarTitleDisplayMode(.inline)
            // The badge + subtitle row is the first thing in the scroll view, so
            // a transparent bar let the title draw straight through it
            // ("Public fishin{Les Davis Pier}g pier"). An opaque bar gives the
            // content something to scroll under instead of into.
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .accessibilityIdentifier("pierDetailSheet")
    }
}
