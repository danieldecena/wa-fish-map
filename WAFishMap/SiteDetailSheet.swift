import SwiftUI

extension FishingRating {
    var color: Color {
        switch self {
        case .poor: .red
        case .fair: .yellow
        case .good: .orange
        case .excellent: .green
        }
    }
}

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
                            Text(s.species).font(.subheadline.weight(.semibold))
                        }
                        Text("Best: \(Self.monthList(s.bestMonths))")
                            .font(.caption).foregroundStyle(.secondary)
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

/// Detail shown when a launch/shore marker is tapped.
struct SiteDetailSheet: View {
    let site: AccessSite
    let fishery: AreaFishery?
    let isMarine: Bool
    let guide: FisheryGuide?
    let month: Int

    private var rating: FishingRating? { fishery?.rating(inMonth: month) }
    private var inSeason: [SpeciesSeason] { fishery?.inSeason(month: month) ?? [] }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    facilitySection
                    amenitiesSection
                    BitingNowView(fishery: fishery, month: month)
                    GuidanceFooter(guide: guide)
                    if !site.directions.isEmpty { directionsSection }
                }
                .padding()
            }
            .navigationTitle(site.facilityName)
            .navigationBarTitleDisplayMode(.inline)
        }
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
    let month: Int

    private var rating: FishingRating? { fishery?.rating(inMonth: month) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(spacing: 10) {
                        RatingBadge(rating: rating)
                        Text("Public fishing pier").font(.subheadline).foregroundStyle(.secondary)
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
