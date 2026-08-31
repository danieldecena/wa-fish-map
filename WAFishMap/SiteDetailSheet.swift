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

/// Small colored capsule showing the current rating (Slow / Fair / Good / Prime).
struct RatingBadge: View {
    let rating: FishingRating

    var body: some View {
        Text(rating.label)
            .font(.caption.bold())
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(rating.color.opacity(0.2), in: Capsule())
            .foregroundStyle(rating.color)
            .overlay(Capsule().stroke(rating.color, lineWidth: 1))
    }
}

/// Detail shown when a launch marker is tapped: facility info, what's biting this
/// month, and the regulatory / freshness alerts.
struct SiteDetailSheet: View {
    let site: AccessSite
    let guide: FisheryGuide?
    let areaName: String
    let month: Int

    private var area: AreaFishery? { guide?.area(named: areaName) }
    private var rating: FishingRating { area?.rating(inMonth: month) ?? .poor }
    private var inSeason: [SpeciesSeason] { area?.inSeason(month: month) ?? [] }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    facilitySection
                    bitingNowSection
                    alertsSection
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
            Text(inSeason.isEmpty
                 ? "No standout species this month"
                 : "Biting now: \(inSeason.prefix(2).map(\.species).joined(separator: ", "))")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var facilitySection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("\(site.countyName) County", systemImage: "mappin.and.ellipse")
            Label("\(site.launchSurface.label) launch", systemImage: "ferry")
            Label(site.hasRestrooms ? "Restrooms on site" : "No restrooms",
                  systemImage: site.hasRestrooms ? "checkmark.circle" : "xmark.circle")
                .foregroundStyle(site.hasRestrooms ? .primary : .secondary)
        }
        .font(.subheadline)
    }

    private var bitingNowSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("What's biting").font(.headline)
            if inSeason.isEmpty {
                Text("Nothing is peaking here this month. Check back closer to a run, and confirm openings with WDFW.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(inSeason, id: \.species) { s in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            RatingBadge(rating: s.rating(inMonth: month))
                            Text(s.species).font(.subheadline.weight(.semibold))
                        }
                        Text("Best: \(Self.monthList(s.bestMonths))")
                            .font(.caption).foregroundStyle(.secondary)
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

    private var alertsSection: some View {
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

    private var directionsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Directions").font(.headline)
            Text(site.directions).font(.caption).foregroundStyle(.secondary)
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
