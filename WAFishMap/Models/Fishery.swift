import Foundation

/// How good the fishing is judged to be right now, worst→best.
///
/// This is curated *guidance* derived from typical seasonal timing — never a live
/// catch report and never a statement of open seasons. See the app disclaimer and
/// always confirm regulations in the WDFW Fish Washington app.
enum FishingRating: Int, Comparable, Sendable {
    case poor = 0        // red — nothing notable in season
    case fair = 1        // orange — shoulder of a season
    case good = 2        // yellow — a species is in a good stretch
    case excellent = 3   // green — a species is at its peak

    static func < (lhs: FishingRating, rhs: FishingRating) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var label: String {
        switch self {
        case .poor: "Slow"
        case .fair: "Fair"
        case .good: "Good"
        case .excellent: "Prime"
        }
    }
}

/// One species and the months it typically fishes best in a given area. Months are 1–12.
struct SpeciesSeason: Decodable, Equatable, Sendable {
    let species: String
    let bestMonths: [Int]
    let goodMonths: [Int]
    let bait: String?
    /// Best time of day for this species (e.g. "Dawn & dusk", "Night, under lights").
    /// General light guidance, not a bite forecast.
    let bestTime: String?
    let note: String?

    init(species: String, bestMonths: [Int], goodMonths: [Int] = [], bait: String? = nil, bestTime: String? = nil, note: String? = nil) {
        self.species = species
        self.bestMonths = bestMonths
        self.goodMonths = goodMonths
        self.bait = bait
        self.bestTime = bestTime
        self.note = note
    }

    private enum CodingKeys: String, CodingKey {
        case species, bestMonths, goodMonths, bait, bestTime, note
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        species = try c.decode(String.self, forKey: .species)
        bestMonths = try c.decodeIfPresent([Int].self, forKey: .bestMonths) ?? []
        goodMonths = try c.decodeIfPresent([Int].self, forKey: .goodMonths) ?? []
        bait = try c.decodeIfPresent(String.self, forKey: .bait)
        bestTime = try c.decodeIfPresent(String.self, forKey: .bestTime)
        note = try c.decodeIfPresent(String.self, forKey: .note)
    }

    /// This species' rating in a given month: peak → good → shoulder → off.
    func rating(inMonth month: Int) -> FishingRating {
        if bestMonths.contains(month) { return .excellent }
        if goodMonths.contains(month) { return .good }
        let onShoulder = (bestMonths + goodMonths)
            .contains { Self.circularMonthDistance($0, month) == 1 }
        return onShoulder ? .fair : .poor
    }

    /// Distance between two months on a 12-month circle, so Dec↔Jan == 1.
    static func circularMonthDistance(_ a: Int, _ b: Int) -> Int {
        let raw = abs(a - b) % 12
        return min(raw, 12 - raw)
    }
}

/// Curated fishing guidance for one WDFW marine area.
struct AreaFishery: Decodable, Equatable, Sendable {
    let areaName: String
    let species: [SpeciesSeason]

    /// The month's overall rating: the best any single species reaches.
    func rating(inMonth month: Int) -> FishingRating {
        species.map { $0.rating(inMonth: month) }.max() ?? .poor
    }

    /// Species worth targeting this month, best first (excludes off-season species).
    /// Ties break on declaration order so the list is stable across renders.
    func inSeason(month: Int) -> [SpeciesSeason] {
        struct Ranked {
            let index: Int
            let species: SpeciesSeason
            let rating: FishingRating
        }
        var ranked: [Ranked] = []
        for (index, s) in species.enumerated() {
            let r = s.rating(inMonth: month)
            if r >= .fair {
                ranked.append(Ranked(index: index, species: s, rating: r))
            }
        }
        ranked.sort { $0.rating != $1.rating ? $0.rating > $1.rating : $0.index < $1.index }
        return ranked.map(\.species)
    }
}

/// Freshwater (lake/river) guidance for launches that fall outside every marine area.
/// A statewide default plus optional per-county overrides, keyed by WDFW `CountyName`.
struct FreshwaterGuide: Decodable, Sendable {
    let species: [SpeciesSeason]
    let byCounty: [String: [SpeciesSeason]]?

    func fishery(county: String) -> AreaFishery {
        AreaFishery(areaName: "freshwater", species: byCounty?[county] ?? species)
    }
}

/// Top-level bundle of curated guidance. Static, offline, editorial — not a live feed.
struct FisheryGuide: Decodable, Sendable {
    let updated: String
    let disclaimer: String
    let wdfwURL: String
    let areas: [AreaFishery]
    let freshwater: FreshwaterGuide?

    func area(named name: String) -> AreaFishery? {
        areas.first { $0.areaName == name }
    }
}
