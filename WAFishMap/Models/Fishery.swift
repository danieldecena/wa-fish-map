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
    /// `"odd"` or `"even"` for a species whose run alternates years (Pink Salmon).
    /// `nil` means no parity — every year rates the same.
    let years: String?
    /// Stamped at load from `years` against the plan year — like `riskMonths`, never
    /// decoded from the row directly. `rating(inMonth:)` returns `.poor` while set.
    var offYear = false

    init(species: String, bestMonths: [Int], goodMonths: [Int] = [], bait: String? = nil, bestTime: String? = nil, note: String? = nil, seasonRiskOverride: String? = nil, years: String? = nil) {
        self.species = species
        self.bestMonths = bestMonths
        self.goodMonths = goodMonths
        self.bait = bait
        self.bestTime = bestTime
        self.note = note
        self.seasonRiskOverride = seasonRiskOverride
        self.years = years
    }

    private enum CodingKeys: String, CodingKey {
        case species, bestMonths, goodMonths, bait, bestTime, note
        case seasonRisk, years
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
        years = try c.decodeIfPresent(String.self, forKey: .years)
    }

    /// A copy carrying the resolved season-risk flag.
    func withRisk(months: [Int], reason: String?) -> SpeciesSeason {
        var copy = self
        copy.riskMonths = months
        copy.riskReason = reason
        return copy
    }

    /// A copy stamped for a given plan year: `offYear` is set when this row's
    /// `years` parity does not match. A row without `years` is never off-year.
    func resolvingYear(_ year: Int) -> SpeciesSeason {
        var copy = self
        switch years?.lowercased() {
        case "odd": copy.offYear = year % 2 == 0
        case "even": copy.offYear = year % 2 != 0
        default: copy.offYear = false
        }
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
    /// clamped to `.fair` in a month where a closure is plausible. An off-year
    /// species (an odd/even-year run resolved against the wrong year) rates
    /// `.poor` outright — the run isn't there, whatever the month.
    func rating(inMonth month: Int) -> FishingRating {
        guard !offYear else { return .poor }
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

    /// `nil` species is All (`breadthRating`). A named species is an exact match,
    /// or `nil` when this area does not list it.
    func rating(inMonth month: Int, species name: String?) -> FishingRating? {
        if let name {
            return species.first { $0.species == name }?.rating(inMonth: month)
        }
        return breadthRating(inMonth: month)
    }

    /// The All-species map colour: the rounded mean of the best three species.
    /// The single best species is not enough — in September every marine area
    /// has one species at peak, so a max painted the whole map red. A spot that
    /// lists fewer than three species averages what it has, so a one-species
    /// kokanee lake at peak still reads Prime.
    func breadthRating(inMonth month: Int) -> FishingRating {
        let top = species.map { $0.rating(inMonth: month).rawValue }.sorted(by: >).prefix(3)
        guard !top.isEmpty else { return .poor }
        let mean = Double(top.reduce(0, +)) / Double(top.count)
        return FishingRating(rawValue: Int(mean.rounded())) ?? .poor
    }

    /// True when the rating for `month` rests on a species whose season may be
    /// closed, so the map can say "verify" without claiming a closure. For All,
    /// only when every species at the top rating carries the risk; one unflagged
    /// species at that rating means the spot is worth going to regardless.
    func closurePlausible(inMonth month: Int, species name: String?) -> Bool {
        if let name {
            return species.first { $0.species == name }?.riskMonths.contains(month) ?? false
        }
        let top = rating(inMonth: month)
        let leaders = species.filter { $0.rating(inMonth: month) == top }
        return !leaders.isEmpty && leaders.allSatisfy { $0.riskMonths.contains(month) }
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

    func resolvingYear(_ year: Int) -> AreaFishery {
        AreaFishery(areaName: areaName, species: species.map { $0.resolvingYear(year) })
    }
}

/// Freshwater (lake/river) guidance for launches that fall outside every marine area.
/// A statewide default plus optional per-county overrides, keyed by WDFW `CountyName`.
struct FreshwaterGuide: Decodable, Sendable {
    let species: [SpeciesSeason]
    let byCounty: [String: [SpeciesSeason]]?

    /// Rows true of one lake or river. A county is not a place a claim can be
    /// pinned to — King County holds Lake Washington, Lake Sammamish, Lake
    /// Dolloff and the Green River, and a note naming one of them is wrong at
    /// the other three.
    let byWaterbody: [String: [SpeciesSeason]]?

    /// waterbody → the WDFW `FacilityName`s that sit on it. WDFW's access-site
    /// layer carries no waterbody column, so the key has to be curated. Matching
    /// facility names against waterbody names by substring was rejected: that is
    /// the same prose-matching failure `NoteScopeTests` documents for
    /// "Potholes", and it would guess silently.
    let waterbodySites: [String: [String]]?

    /// The waterbody a named ramp sits on, or nil when it is not curated yet.
    func waterbody(forFacility facility: String) -> String? {
        waterbodySites?.first { $0.value.contains(facility) }?.key
    }

    /// Curated list first, so a lake ramp near an inlet river keeps the lake;
    /// otherwise the river the site sits on. Creeks never resolve: their names
    /// repeat across the state, so a note keyed by one would reach them all.
    func waterbody(forFacility facility: String, at point: LonLat, rivers: [River]) -> String? {
        waterbody(forFacility: facility)
            ?? River.nearest(to: point, within: River.waterbodyMatchMeters,
                             in: rivers.filter { $0.kind == .river })?.name
    }

    /// The two waterbody fields default to nil so the older two-field form keeps
    /// compiling — the tier is additive, and a guide without it behaves exactly
    /// as it did before.
    init(species: [SpeciesSeason],
         byCounty: [String: [SpeciesSeason]]? = nil,
         byWaterbody: [String: [SpeciesSeason]]? = nil,
         waterbodySites: [String: [String]]? = nil) {
        self.species = species
        self.byCounty = byCounty
        self.byWaterbody = byWaterbody
        self.waterbodySites = waterbodySites
    }

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

    /// Waterbody beats county beats statewide, overriding per species name.
    ///
    /// Order is load-bearing: `AreaFishery.inSeason(month:)` breaks rating ties
    /// on declaration index, so the overriding rows must come first.
    func fishery(county: String, waterbody: String?) -> AreaFishery {
        let base = fishery(county: county).species
        guard let waterbody, let rows = byWaterbody?[waterbody], !rows.isEmpty else {
            return AreaFishery(areaName: "freshwater", species: base)
        }
        let overridden = Set(rows.map(\.species))
        return AreaFishery(areaName: "freshwater",
                           species: rows + base.filter { !overridden.contains($0.species) })
    }

    /// Every tier is stamped. A tier omitted here silently skips the season cap,
    /// which would let a closure-prone fishery render as Prime.
    func resolvingSeasonRisk(_ table: [SeasonRisk]) -> FreshwaterGuide {
        FreshwaterGuide(
            species: species.map { $0.resolvingSeasonRisk(table) },
            byCounty: byCounty?.mapValues { $0.map { $0.resolvingSeasonRisk(table) } },
            byWaterbody: byWaterbody?.mapValues { $0.map { $0.resolvingSeasonRisk(table) } },
            waterbodySites: waterbodySites
        )
    }

    /// Every tier is stamped, same reasoning as `resolvingSeasonRisk` — a tier
    /// left out would let an off-year species keep rating Prime there.
    func resolvingYear(_ year: Int) -> FreshwaterGuide {
        FreshwaterGuide(
            species: species.map { $0.resolvingYear(year) },
            byCounty: byCounty?.mapValues { $0.map { $0.resolvingYear(year) } },
            byWaterbody: byWaterbody?.mapValues { $0.map { $0.resolvingYear(year) } },
            waterbodySites: waterbodySites
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

    /// Distinct species strings in the guide, sorted. Exact names, not collapsed.
    var speciesNames: [String] {
        var seen = Set<String>()
        var names: [String] = []
        func add(_ list: [SpeciesSeason]) {
            for s in list where seen.insert(s.species).inserted {
                names.append(s.species)
            }
        }
        for area in areas { add(area.species) }
        if let freshwater {
            add(freshwater.species)
            if let counties = freshwater.byCounty {
                for list in counties.values { add(list) }
            }
        }
        return names.sorted()
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

    /// Stamp every species with its resolved off-year flag for `year`. Cheap and
    /// idempotent — safe to call again whenever the plan year changes, and the
    /// caller (`FishingMapModel`) only calls it when the year actually changed.
    func resolvingYear(_ year: Int) -> FisheryGuide {
        FisheryGuide(
            updated: updated,
            disclaimer: disclaimer,
            wdfwURL: wdfwURL,
            areas: areas.map { $0.resolvingYear(year) },
            freshwater: freshwater?.resolvingYear(year),
            seasonRisk: seasonRisk
        )
    }
}
