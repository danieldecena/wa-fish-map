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

    @Test func bundledGuideDecodesAndHasArea13() throws {
        let bundle = try #require(FixtureBundle.loader)
        let url = try #require(bundle.url(forResource: "fisheries", withExtension: "json"))
        let guide = try FisheryLoader.guide(from: Data(contentsOf: url))
        let area = try #require(guide.area(named: "13"))
        #expect(!area.species.isEmpty)
        #expect(!guide.disclaimer.isEmpty)
        #expect(URL(string: guide.wdfwURL) != nil)
    }
}
