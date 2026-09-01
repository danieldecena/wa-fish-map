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
        #expect(area.rating(inMonth: 8, species: nil) == .excellent)
        #expect(area.rating(inMonth: 8, species: "Chinook Salmon") == .excellent)
        #expect(area.rating(inMonth: 8, species: "Chinook Salmon (ocean)") == .poor)
        #expect(area.rating(inMonth: 8, species: "Coho") == .good)
        #expect(area.rating(inMonth: 8, species: "Lingcod") == nil)
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
