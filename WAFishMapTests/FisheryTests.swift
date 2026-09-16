import Foundation
import Testing
@testable import WAFishMap

struct FisheryTests {
    let coho = SpeciesSeason(species: "Coho", bestMonths: [9, 10], goodMonths: [8, 11])

    @Test func peakMonthIsExcellent() {
        #expect(coho.rating(inMonth: 9) == .excellent)
        #expect(coho.rating(inMonth: 10) == .excellent)
    }

    @Test func goodMonthIsGood() {
        #expect(coho.rating(inMonth: 8) == .good)
        #expect(coho.rating(inMonth: 11) == .good)
    }

    @Test func shoulderMonthIsFair() {
        #expect(coho.rating(inMonth: 7) == .fair)   // adjacent to good month 8
        #expect(coho.rating(inMonth: 12) == .fair)  // adjacent to good month 11
    }

    @Test func offSeasonIsPoor() {
        #expect(coho.rating(inMonth: 3) == .poor)
    }

    @Test func decemberJanuaryWrapsAround() {
        let squid = SpeciesSeason(species: "Squid", bestMonths: [12, 1])
        #expect(squid.rating(inMonth: 11) == .fair) // adjacent to Dec
        #expect(squid.rating(inMonth: 2) == .fair)  // adjacent to Jan
        #expect(SpeciesSeason.circularMonthDistance(12, 1) == 1)
        #expect(SpeciesSeason.circularMonthDistance(1, 12) == 1)
    }

    @Test func areaRatingTakesBestSpecies() {
        let area = AreaFishery(areaName: "13", species: [
            SpeciesSeason(species: "Peaking", bestMonths: [6]),
            SpeciesSeason(species: "Merely good", bestMonths: [], goodMonths: [6]),
        ])
        #expect(area.rating(inMonth: 6) == .excellent)
    }

    @Test func areaRatingIsPoorWithNoSpecies() {
        #expect(AreaFishery(areaName: "13", species: []).rating(inMonth: 6) == .poor)
    }

    @Test func inSeasonIsSortedBestFirstAndExcludesOffSeason() {
        let area = AreaFishery(areaName: "13", species: [
            SpeciesSeason(species: "Good", bestMonths: [], goodMonths: [6]),
            SpeciesSeason(species: "Peak", bestMonths: [6]),
            SpeciesSeason(species: "Off", bestMonths: [1]),
        ])
        #expect(area.inSeason(month: 6).map(\.species) == ["Peak", "Good"])
    }

    @Test func countyOverrideMergesWithStatewideDefaults() {
        let guide = FreshwaterGuide(
            species: [
                SpeciesSeason(species: "Rainbow Trout", bestMonths: [4, 5]),
                SpeciesSeason(species: "Kokanee", bestMonths: [5, 6], note: "Statewide note"),
            ],
            byCounty: ["King": [SpeciesSeason(species: "Kokanee", bestMonths: [6, 7], note: "Local note")]]
        )
        let king = guide.fishery(county: "King")
        // County entry wins for its species (local note kept), defaults inherited after.
        #expect(king.species.map(\.species) == ["Kokanee", "Rainbow Trout"])
        #expect(king.species[0].note == "Local note")
        #expect(king.species[0].bestMonths == [6, 7])
    }

    @Test func emptyOrMissingCountyOverrideFallsBackToStatewide() {
        let guide = FreshwaterGuide(
            species: [SpeciesSeason(species: "Rainbow Trout", bestMonths: [4, 5])],
            byCounty: ["Empty": []]
        )
        // An empty override list must not shadow the default with zero species.
        #expect(guide.fishery(county: "Empty").species.map(\.species) == ["Rainbow Trout"])
        #expect(guide.fishery(county: "Unlisted").species.map(\.species) == ["Rainbow Trout"])
    }

    // MARK: Lake species filter

    let lakeGuide = FreshwaterGuide(
        species: [
            SpeciesSeason(species: "Rainbow Trout", bestMonths: [4, 5], goodMonths: [9]),
            SpeciesSeason(species: "Largemouth Bass", bestMonths: [6], goodMonths: [9]),
            SpeciesSeason(species: "Cutthroat Trout", bestMonths: [9]),
        ],
        byCounty: ["Pierce": [SpeciesSeason(species: "Rock Bass", bestMonths: [7])]],
        byWaterbody: ["Walleye Lake": [SpeciesSeason(species: "Walleye", bestMonths: [9], note: "curated")]]
    )

    @Test func aTroutOnlyLakeDropsBass() throws {
        let f = try #require(lakeGuide.fishery(county: "King", waterbody: nil,
                                               lakeSpecies: ["Rainbow Trout", "Coastal Cutthroat"]))
        #expect(f.species.map(\.species) == ["Rainbow Trout", "Cutthroat Trout"])
    }

    @Test func aLakeListingBassKeepsItAndDropsWhatItDoesNotList() throws {
        let f = try #require(lakeGuide.fishery(county: "King", waterbody: nil,
                                               lakeSpecies: ["Largemouth Bass", "Yellow Perch"]))
        #expect(f.species.map(\.species) == ["Largemouth Bass"])
    }

    /// WDFW's lake layer has no rock bass column, so its silence says nothing.
    @Test func aSpeciesWithNoWDFWMappingIsKept() throws {
        let f = try #require(lakeGuide.fishery(county: "Pierce", waterbody: nil,
                                               lakeSpecies: ["Rainbow Trout"]))
        #expect(f.species.map(\.species) == ["Rock Bass", "Rainbow Trout"])
    }

    @Test func noLakeMatchOrAnEmptyListChangesNothing() {
        let unfiltered = lakeGuide.fishery(county: "King", waterbody: nil).species.map(\.species)
        #expect(lakeGuide.fishery(county: "King", waterbody: nil, lakeSpecies: nil)?.species.map(\.species) == unfiltered)
        #expect(lakeGuide.fishery(county: "King", waterbody: nil, lakeSpecies: [])?.species.map(\.species) == unfiltered)
        #expect(unfiltered.count == 3)
    }

    /// Walleye is absent from this lake's WDFW list, and kept anyway: a waterbody
    /// row is curated for that water, which outranks the 2014 layer.
    @Test func waterbodyRowsAreNeverFiltered() throws {
        let f = try #require(lakeGuide.fishery(county: "King", waterbody: "Walleye Lake",
                                               lakeSpecies: ["Rainbow Trout"]))
        #expect(f.species.map(\.species) == ["Walleye", "Rainbow Trout"])
        #expect(f.species[0].note == "curated")
    }

    /// Nil, not an empty fishery: an empty one rates `.poor`, which would paint a
    /// blue pin for a lake the guide simply says nothing about.
    @Test func aLakeSupportingNoGuideSpeciesHasNoFishery() {
        #expect(lakeGuide.fishery(county: "King", waterbody: nil, lakeSpecies: ["Brown Bullhead"]) == nil)
        #expect(AreaFishery(areaName: "freshwater", species: []).rating(inMonth: 9) == .poor)
    }

    @Test func bundledGuideDecodesAndHasArea13() throws {
        let bundle = try #require(FixtureBundle.loader)
        let url = try #require(bundle.url(forResource: "fisheries", withExtension: "json"))
        let guide = try FisheryLoader.guide(from: Data(contentsOf: url))
        let area = try #require(guide.area(named: "13"))
        #expect(!area.species.isEmpty)
        #expect(!guide.disclaimer.isEmpty)
        #expect(URL(string: guide.wdfwURL) != nil)
    }

    @Test func flaggedMonthCapsPeakToFair() {
        let flagged = coho.withRisk(months: [9], reason: "Quota-driven")
        #expect(flagged.rating(inMonth: 9) == .fair)
    }

    @Test func unflaggedMonthKeepsFullRating() {
        let flagged = coho.withRisk(months: [9], reason: "Quota-driven")
        #expect(flagged.rating(inMonth: 10) == .excellent)
    }

    @Test func capNeverRaisesAWeakRating() {
        let flagged = coho.withRisk(months: [3], reason: "Quota-driven")
        #expect(flagged.rating(inMonth: 3) == .poor)
    }

    @Test func unstampedSpeciesIsUnaffected() {
        #expect(coho.riskMonths.isEmpty)
        #expect(coho.rating(inMonth: 9) == .excellent)
    }

    @Test func namedSpeciesRatingIsExactMatchOnly() {
        let area = AreaFishery(areaName: "13", species: [
            SpeciesSeason(species: "Chinook Salmon", bestMonths: [8]),
            SpeciesSeason(species: "Chinook Salmon (ocean)", bestMonths: [6]),
            SpeciesSeason(species: "Coho", bestMonths: [], goodMonths: [8]),
        ])
        // All is the breadth rating: Prime, Slow, Good average to Good.
        #expect(area.rating(inMonth: 8, species: nil) == .good)
        #expect(area.rating(inMonth: 8, species: "Chinook Salmon") == .excellent)
        #expect(area.rating(inMonth: 8, species: "Chinook Salmon (ocean)") == .poor)
        #expect(area.rating(inMonth: 8, species: "Coho") == .good)
        #expect(area.rating(inMonth: 8, species: "Lingcod") == nil)
    }

    @Test func breadthRatingAveragesTheTopThreeSpecies() {
        let area = AreaFishery(areaName: "13", species: [
            SpeciesSeason(species: "A", bestMonths: [9]),
            SpeciesSeason(species: "B", bestMonths: [9]),
            SpeciesSeason(species: "C", bestMonths: [9]),
            SpeciesSeason(species: "D", bestMonths: [3]),
        ])
        // Three at peak: the slow fourth species does not drag it down.
        #expect(area.breadthRating(inMonth: 9) == .excellent)
        // One peak among slow species is no longer Prime, as max would say.
        #expect(area.rating(inMonth: 3) == .excellent)
        #expect(area.breadthRating(inMonth: 3) == .fair)
    }

    @Test func breadthRatingKeepsASingleSpeciesSpotAtItsOwnRating() {
        let lake = AreaFishery(areaName: "Lake", species: [SpeciesSeason(species: "Kokanee", bestMonths: [6])])
        #expect(lake.breadthRating(inMonth: 6) == .excellent)
        #expect(AreaFishery(areaName: "x", species: []).breadthRating(inMonth: 6) == .poor)
    }

    @Test func speciesNamesAreUniqueAndSorted() {
        let guide = FisheryGuide(
            updated: "2026-08-31", disclaimer: "d", wdfwURL: "https://example.com",
            areas: [
                AreaFishery(areaName: "13", species: [
                    SpeciesSeason(species: "Coho", bestMonths: [9]),
                    SpeciesSeason(species: "Chinook Salmon", bestMonths: [8]),
                ]),
            ],
            freshwater: FreshwaterGuide(
                species: [SpeciesSeason(species: "Rainbow Trout", bestMonths: [5])],
                byCounty: ["King": [SpeciesSeason(species: "Coho", bestMonths: [10])]]
            ),
            seasonRisk: []
        )
        #expect(guide.speciesNames == ["Chinook Salmon", "Coho", "Rainbow Trout"])
    }
}

/// Odd/even-year species (Pink Salmon is odd-year) must not rate Prime in the
/// wrong year — `SpeciesSeason.rating(inMonth:)` is month-only, so without a
/// year stamp a 2026 (even) plan showed pinks at Prime in August.
struct OddYearSpeciesTests {
    let pink = SpeciesSeason(species: "Pink Salmon", bestMonths: [8, 9], goodMonths: [7], years: "odd")

    @Test func decodesYearsField() throws {
        let json = #"{"species": "Pink Salmon", "bestMonths": [8], "years": "odd"}"#.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(SpeciesSeason.self, from: json)
        #expect(decoded.years == "odd")
    }

    @Test func absentYearsFieldDecodesToNil() throws {
        let json = #"{"species": "Coho", "bestMonths": [9]}"#.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(SpeciesSeason.self, from: json)
        #expect(decoded.years == nil)
    }

    @Test func oddRowRatesExcellentInAnOddYearAndPoorInAnEvenYear() {
        #expect(pink.resolvingYear(2025).rating(inMonth: 8) == .excellent)
        #expect(pink.resolvingYear(2026).rating(inMonth: 8) == .poor)
    }

    @Test func rowWithoutYearsIsUnaffectedByEitherYear() {
        let coho = SpeciesSeason(species: "Coho", bestMonths: [9, 10])
        #expect(coho.resolvingYear(2025).rating(inMonth: 9) == .excellent)
        #expect(coho.resolvingYear(2026).rating(inMonth: 9) == .excellent)
    }

    @Test func offYearExcludesFromInSeason() {
        let area = AreaFishery(areaName: "7", species: [pink])
        #expect(area.resolvingYear(2025).inSeason(month: 8).map(\.species) == ["Pink Salmon"])
        #expect(area.resolvingYear(2026).inSeason(month: 8).isEmpty)
    }

    @Test func fisheryGuideResolvingYearStampsEveryTier() {
        let guide = FisheryGuide(
            updated: "2026-09-16", disclaimer: "d", wdfwURL: "https://example.com",
            areas: [AreaFishery(areaName: "7", species: [pink])],
            freshwater: FreshwaterGuide(
                species: [pink],
                byCounty: ["Skagit": [pink]],
                byWaterbody: ["Baker Lake": [pink]]
            ),
            seasonRisk: []
        )
        let resolved = guide.resolvingYear(2026)
        #expect(resolved.area(named: "7")?.species.first?.rating(inMonth: 8) == .poor)
        #expect(resolved.freshwater?.species.first?.rating(inMonth: 8) == .poor)
        #expect(resolved.freshwater?.fishery(county: "Skagit").species.first?.rating(inMonth: 8) == .poor)
        #expect(resolved.freshwater?.fishery(county: "Skagit", waterbody: "Baker Lake")
            .species.first?.rating(inMonth: 8) == .poor)
    }
}

/// Confirms the shipped `fisheries.json` Pink Salmon rows actually carry
/// `years: "odd"` and rate correctly for a real odd/even year pair.
struct ShippedOddYearTests {
    @Test func area7PinkSalmonIsNotPrimeInAnEvenYearButIsInAnOddYear() throws {
        let url = try #require(Bundle.main.url(forResource: "fisheries", withExtension: "json"))
        let guide = try FisheryLoader.guide(from: Data(contentsOf: url))
        let area = try #require(guide.area(named: "7"))
        #expect(area.resolvingYear(2026).rating(inMonth: 8, species: "Pink Salmon") == .poor)
        #expect(area.resolvingYear(2025).rating(inMonth: 8, species: "Pink Salmon") == .excellent)
    }
}
