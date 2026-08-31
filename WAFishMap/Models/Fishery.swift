import Foundation

/// How good the fishing is judged to be right now, worst→best.
///
/// This is curated *guidance* derived from typical seasonal timing — never a live
/// catch report and never a statement of open seasons. See the app disclaimer and
/// always confirm regulations in the WDFW Fish Washington app.
enum FishingRating: Int, Comparable, Sendable {
    case poor = 0        // blue — nothing notable in season
    case fair = 1        // amber — shoulder of a season
    case good = 2        // orange — a species is in a good stretch
    case excellent = 3   // red — a species is at its peak

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
    /// Months where a closure is plausible. Stamped at load from the `seasonRisk`
    /// table, never decoded from a species row.
    var riskMonths: [Int] = []
    /// Why verification is needed, shown beside the capped rating.
    var riskReason: String?
    /// A row sets `"seasonRisk": "none"` where this area is open while its
    /// neighbours are not. The central table cannot express that; this is the
    /// escape hatch, applied case by case as it is discovered.
    let seasonRiskOverride: String?

    init(species: String, bestMonths: [Int], goodMonths: [Int] = [], bait: String? = nil, bestTime: String? = nil, note: String? = nil, seasonRiskOverride: String? = nil) {
        self.species = species
        self.bestMonths = bestMonths
        self.goodMonths = goodMonths
        self.bait = bait
        self.bestTime = bestTime
        self.note = note
        self.seasonRiskOverride = seasonRiskOverride
    }

    private enum CodingKeys: String, CodingKey {
        case species, bestMonths, goodMonths, bait, bestTime, note
        case seasonRisk
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        species = try c.decode(String.self, forKey: .species)
        bestMonths = try c.decodeIfPresent([Int].self, forKey: .bestMonths) ?? []
        goodMonths = try c.decodeIfPresent([Int].self, forKey: .goodMonths) ?? []
        bait = try c.decodeIfPresent(String.self, forKey: .bait)
        bestTime = try c.decodeIfPresent(String.self, forKey: .bestTime)
        note = try c.decodeIfPresent(String.self, forKey: .note)
        seasonRiskOverride = try c.decodeIfPresent(String.self, forKey: .seasonRisk)
    }

    /// A copy carrying the resolved season-risk flag.
    func withRisk(months: [Int], reason: String?) -> SpeciesSeason {
        var copy = self
        copy.riskMonths = months
        copy.riskReason = reason
        return copy
    }

    /// Union the months of every matching row; join distinct reasons with "; ".
    /// An explicit "none" on the row beats any table match.
    func resolvingSeasonRisk(_ table: [SeasonRisk]) -> SpeciesSeason {
        guard seasonRiskOverride?.lowercased() != "none" else { return self }
        let hits = table.filter { $0.matches(species) }
        guard !hits.isEmpty else { return self }
        let months = Array(Set(hits.flatMap(\.months))).sorted()
        var reasons: [String] = []
        for hit in hits where !reasons.contains(hit.reason) { reasons.append(hit.reason) }
        return withRisk(months: months, reason: reasons.joined(separator: "; "))
    }

    /// This species' rating in a given month: peak → good → shoulder → off, then
    /// clamped to `.fair` in a month where a closure is plausible.
    func rating(inMonth month: Int) -> FishingRating {
        let base: FishingRating
        if bestMonths.contains(month) {
            base = .excellent
        } else if goodMonths.contains(month) {
            base = .good
        } else {
            let onShoulder = (bestMonths + goodMonths)
                .contains { Self.circularMonthDistance($0, month) == 1 }
            base = onShoulder ? .fair : .poor
        }
        return riskMonths.contains(month) ? min(base, .fair) : base
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

    func resolvingSeasonRisk(_ table: [SeasonRisk]) -> AreaFishery {
        AreaFishery(areaName: areaName, species: species.map { $0.resolvingSeasonRisk(table) })
    }
}

/// Freshwater (lake/river) guidance for launches that fall outside every marine area.
/// A statewide default plus optional per-county overrides, keyed by WDFW `CountyName`.
struct FreshwaterGuide: Decodable, Sendable {
    let species: [SpeciesSeason]
    let byCounty: [String: [SpeciesSeason]]?

    /// County entries refine the statewide default, they don't erase it: overrides
    /// come first (they carry the local note), then any statewide species the county
    /// doesn't redefine. An empty override list falls back to the default outright.
    func fishery(county: String) -> AreaFishery {
        guard let overrides = byCounty?[county], !overrides.isEmpty else {
            return AreaFishery(areaName: "freshwater", species: species)
        }
        let overridden = Set(overrides.map(\.species))
        let inherited = species.filter { !overridden.contains($0.species) }
        return AreaFishery(areaName: "freshwater", species: overrides + inherited)
    }

    func resolvingSeasonRisk(_ table: [SeasonRisk]) -> FreshwaterGuide {
        FreshwaterGuide(
            species: species.map { $0.resolvingSeasonRisk(table) },
            byCounty: byCounty?.mapValues { $0.map { $0.resolvingSeasonRisk(table) } }
        )
    }
}

/// Top-level bundle of curated guidance. Static, offline, editorial — not a live feed.
struct FisheryGuide: Decodable, Sendable {
    let updated: String
    let disclaimer: String
    let wdfwURL: String
    let areas: [AreaFishery]
    let freshwater: FreshwaterGuide?
    let seasonRisk: [SeasonRisk]

    private enum CodingKeys: String, CodingKey {
        case updated, disclaimer, wdfwURL, areas, freshwater, seasonRisk
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        updated = try c.decode(String.self, forKey: .updated)
        disclaimer = try c.decode(String.self, forKey: .disclaimer)
        wdfwURL = try c.decode(String.self, forKey: .wdfwURL)
        areas = try c.decode([AreaFishery].self, forKey: .areas)
        freshwater = try c.decodeIfPresent(FreshwaterGuide.self, forKey: .freshwater)
        seasonRisk = try c.decodeIfPresent([SeasonRisk].self, forKey: .seasonRisk) ?? []
    }

    init(updated: String, disclaimer: String, wdfwURL: String,
         areas: [AreaFishery], freshwater: FreshwaterGuide?, seasonRisk: [SeasonRisk]) {
        self.updated = updated
        self.disclaimer = disclaimer
        self.wdfwURL = wdfwURL
        self.areas = areas
        self.freshwater = freshwater
        self.seasonRisk = seasonRisk
    }

    func area(named name: String) -> AreaFishery? {
        areas.first { $0.areaName == name }
    }

    /// Stamp every species with its resolved risk months. Done once at load so
    /// matching costs nothing per render.
    func resolvingSeasonRisk() -> FisheryGuide {
        guard !seasonRisk.isEmpty else { return self }
        return FisheryGuide(
            updated: updated,
            disclaimer: disclaimer,
            wdfwURL: wdfwURL,
            areas: areas.map { $0.resolvingSeasonRisk(seasonRisk) },
            freshwater: freshwater?.resolvingSeasonRisk(seasonRisk),
            seasonRisk: seasonRisk
        )
    }
}
