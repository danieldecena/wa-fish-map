import SwiftUI

/// Small colored capsule showing the rating. `nil` renders neutral gray — used for
/// spots with no curated season data yet.
struct RatingBadge: View {
    let rating: FishingRating?

    private var color: Color { rating?.color ?? .gray }
    private var label: String { rating?.label ?? "No data" }

    var body: some View {
        Text(label)
            .font(.caption.bold())
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(color.opacity(0.2), in: Capsule())
            .foregroundStyle(color)
            .overlay(Capsule().stroke(color, lineWidth: 1))
    }
}

/// Opens Apple Maps with driving directions to the spot. A maps.apple.com
/// link, not `MKMapItem`: its coordinate initializer is iOS 26 only and the
/// placemark one is deprecated there, while this app targets iOS 18.
struct DirectionsButton: View {
    let name: String
    let coordinate: LonLat

    static func url(name: String, coordinate: LonLat) -> URL? {
        var components = URLComponents(string: "https://maps.apple.com/")
        components?.queryItems = [
            URLQueryItem(name: "daddr", value: "\(coordinate.latitude),\(coordinate.longitude)"),
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
                                    Image(systemName: "fish.fill")
                                        .font(.system(size: size.iconPointSize))
                                        .foregroundStyle(.secondary)
                                        .frame(width: 52, height: 48)
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
                        Label("Best months: \(Self.monthList(s.bestMonths))", systemImage: "calendar")
                            .font(.caption).foregroundStyle(.secondary)
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

    private static let shortMonthSymbols = DateFormatter().shortMonthSymbols ?? []

    /// "9, 10" → "Sep, Oct".
    static func monthList(_ months: [Int]) -> String {
        months.sorted()
            .compactMap { $0 >= 1 && $0 <= shortMonthSymbols.count ? shortMonthSymbols[$0 - 1] : nil }
            .joined(separator: ", ")
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
            }
            if let disclaimer = guide?.disclaimer {
                Text(disclaimer).font(.caption).foregroundStyle(.secondary)
            }
            if let updated = guide?.updated {
                Text("Guidance updated \(updated)").font(.caption2).foregroundStyle(.tertiary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.yellow.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
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

    private var month: Int { PlanClock.month(for: planDate) }
    private var rating: FishingRating? { fishery?.rating(inMonth: month, species: species) }
    private var inSeason: [SpeciesSeason] { fishery?.inSeason(month: month) ?? [] }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    facilitySection
                    DirectionsButton(name: site.facilityName, coordinate: site.coordinate)
                    amenitiesSection
                    DaylightView(coordinate: site.coordinate, planDate: planDate)
                    TidePredictionsView(
                        coordinate: site.coordinate,
                        planDate: planDate,
                        isMarine: isMarine
                    )
                    BuoyConditionsView(coordinate: site.coordinate, isMarine: isMarine)
                    PlanWeatherView(coordinate: site.coordinate, planDate: planDate)
                    ProtectedAreaSection(check: protectedAreaCheck)
                    BitingNowView(fishery: fishery, month: month)
                    GuidanceFooter(guide: guide)
                    if !site.directions.isEmpty { directionsSection }
                }
                .padding()
            }
            .navigationTitle(site.facilityName)
            .navigationBarTitleDisplayMode(.inline)
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
                    ProtectedAreaSection(check: protectedAreaCheck)
                    BitingNowView(fishery: fishery, month: month)
                    GuidanceFooter(guide: guide)
                }
                .padding()
            }
            .navigationTitle(pier.name)
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
