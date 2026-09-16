import CoreGraphics
import Foundation

/// Typical sport-caught weight for a species, drawn as a fish that grows with it.
///
/// Hand-entered from general angling knowledge and **unverified** — like the
/// rest of the species guidance, check before treating a number as fact. It is
/// a size impression for the detail sheet, never a record or a limit.
struct SpeciesSize: Equatable, Sendable {
    /// Shown to the user, e.g. "10-25 lb".
    let range: String
    /// A representative weight; only drives the icon size.
    let pounds: Double

    /// First match wins, so a specific row ("Blackmouth") sits above the
    /// general one ("Chinook") it would otherwise fall into. Shellfish and
    /// squid have no row: a fish silhouette would misdescribe them.
    private static let table: [(match: String, size: SpeciesSize)] = [
        ("Blackmouth", SpeciesSize(range: "4-10 lb", pounds: 6)),
        ("Buoy 10", SpeciesSize(range: "8-20 lb", pounds: 12)),
        ("Chinook", SpeciesSize(range: "10-25 lb", pounds: 15)),
        ("Chum", SpeciesSize(range: "8-15 lb", pounds: 11)),
        ("Coho", SpeciesSize(range: "6-12 lb", pounds: 8)),
        ("Sockeye", SpeciesSize(range: "4-8 lb", pounds: 6)),
        ("Pink Salmon", SpeciesSize(range: "3-6 lb", pounds: 4)),
        ("Halibut", SpeciesSize(range: "20-60 lb", pounds: 35)),
        ("Albacore", SpeciesSize(range: "15-30 lb", pounds: 20)),
        ("Lingcod", SpeciesSize(range: "8-20 lb", pounds: 12)),
        ("Rockfish", SpeciesSize(range: "2-5 lb", pounds: 3)),
        ("Catfish", SpeciesSize(range: "2-10 lb", pounds: 5)),
        ("Walleye", SpeciesSize(range: "2-6 lb", pounds: 3)),
        ("Largemouth", SpeciesSize(range: "2-5 lb", pounds: 3)),
        ("Smallmouth", SpeciesSize(range: "1-4 lb", pounds: 2)),
        ("Rainbow Trout", SpeciesSize(range: "0.5-3 lb", pounds: 1.5)),
        ("Redband", SpeciesSize(range: "0.5-2 lb", pounds: 1)),
        ("Cutthroat", SpeciesSize(range: "0.5-2 lb", pounds: 1)),
        ("Kokanee", SpeciesSize(range: "0.5-2 lb", pounds: 1)),
        ("Surfperch", SpeciesSize(range: "0.5-2 lb", pounds: 1)),
        ("Crappie", SpeciesSize(range: "0.5-1.5 lb", pounds: 0.75)),
        ("Yellow Perch", SpeciesSize(range: "0.25-1 lb", pounds: 0.5)),
        ("Rock Bass", SpeciesSize(range: "0.25-1 lb", pounds: 0.5)),
    ]

    static func typical(for species: String) -> SpeciesSize? {
        table.first { species.range(of: $0.match, options: .caseInsensitive) != nil }?.size
    }

    /// Icon point size, 16...48. Logarithmic, so a half-pound perch and a
    /// 35 lb halibut both read at a glance instead of the perch vanishing.
    var iconPointSize: CGFloat {
        let scale = log2(min(pounds, 60) + 1) / log2(61)
        return 16 + 32 * CGFloat(scale)
    }
}
