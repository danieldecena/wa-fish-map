import SwiftUI

/// What a tapped river can say for itself. Everything here is an observation
/// with a timestamp or a curated note — never a claim that the river is open,
/// which is what `GuidanceFooter` routes to WDFW for.
struct RiverDetailSheet: View {
    let river: River
    let stats: RiverFlowStats?
    let flow: RiverFlow?
    /// False when the USGS fetch failed, so a missing reading is not blamed on
    /// the gauge.
    var flowsLoaded = true
    let guide: FisheryGuide?
    let planDate: Date

    private var month: Int { PlanClock.month(for: planDate) }
    private var day: Int { PlanClock.day(for: planDate) }

    private var rating: FishingRating? {
        guard let stats, let discharge = flow?.discharge else { return nil }
        return stats.rating(discharge: discharge, month: month, day: day)
    }

    /// Rows curated for this exact waterbody. Most rivers have none — the tier
    /// holds one row today — and none is the honest answer, not a gap to fill.
    private var waterbodySpecies: [SpeciesSeason] {
        river.resolvesWaterbody ? guide?.freshwater?.byWaterbody?[river.name] ?? [] : []
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    conditionsSection
                    if !waterbodySpecies.isEmpty { notesSection }
                    GuidanceFooter(guide: guide)
                }
                .padding()
            }
            .navigationTitle(river.name)
            .navigationBarTitleDisplayMode(.inline)
        }
        .accessibilityIdentifier("riverDetailSheet")
    }

    private var header: some View {
        HStack {
            RatingBadge(rating: rating)
            Spacer()
            Text("\(river.lengthKm, specifier: "%.0f") km in Washington")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder private var conditionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("\(river.kind.rawValue.capitalized) conditions").font(.headline)

            if let stats, let discharge = flow?.discharge {
                Text("\(Int(discharge.rounded())) cfs")
                    .font(.title2.weight(.semibold))
                    .accessibilityIdentifier("riverDischarge")
                if let summary = stats.summary(discharge: discharge, month: month, day: day) {
                    Text(summary).font(.subheadline)
                }
                // Timestamps are per-series: a gauge can report flow every 15
                // minutes and temperature hourly, so one "as of" would date one
                // of them wrongly.
                if let at = flow?.dischargeAt {
                    Label(Self.stamp(at), systemImage: "clock")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if let tempC = flow?.waterTempC, let tempF = flow?.waterTempF {
                    Divider()
                    Text("\(tempF, specifier: "%.0f")°F water (\(tempC, specifier: "%.1f")°C)")
                        .font(.subheadline.weight(.medium))
                    if let at = flow?.waterTempAt {
                        Label(Self.stamp(at), systemImage: "clock")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                Divider()
                Text("USGS gauge \(stats.gaugeName.capitalized), \(stats.yearsOfRecord) years of record")
                    .font(.caption2).foregroundStyle(.tertiary)
                Text("Compared against this river's own flow for the time of year, not against other rivers.")
                    .font(.caption2).foregroundStyle(.tertiary)
            } else if stats == nil {
                // Distinguishing these two matters: "no gauge exists" is
                // permanent, "no reading right now" is not.
                Text("No USGS gauge on this \(river.kind.rawValue), so there is nothing to report on its flow.")
                    .font(.subheadline).foregroundStyle(.secondary)
            } else if !flowsLoaded {
                Text("Couldn't reach USGS for a live reading. Check your connection and reopen.")
                    .font(.subheadline).foregroundStyle(.secondary)
                if let stats {
                    Text("USGS gauge \(stats.gaugeName.capitalized)")
                        .font(.caption2).foregroundStyle(.tertiary)
                }
            } else {
                Text("This river has a gauge, but it is not reporting right now.")
                    .font(.subheadline).foregroundStyle(.secondary)
                if let stats {
                    Text("USGS gauge \(stats.gaugeName.capitalized)")
                        .font(.caption2).foregroundStyle(.tertiary)
                }
            }
        }
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("What's biting").font(.headline)
            ForEach(waterbodySpecies, id: \.species) { species in
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        RatingBadge(rating: species.rating(inMonth: month))
                        Text(species.species).font(.subheadline.weight(.semibold))
                    }
                    if species.riskMonths.contains(month) {
                        Label("Season varies — verify", systemImage: "exclamationmark.triangle")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    if let note = species.note {
                        Text(note).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private static func stamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, h:mm a"
        return "Reading taken \(formatter.string(from: date))"
    }
}
