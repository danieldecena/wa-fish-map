import Foundation
import Testing
@testable import WAFishMap

struct SpeciesSizeTests {
    @Test func aSpecificRowWinsOverTheGeneralOne() throws {
        let blackmouth = try #require(SpeciesSize.typical(for: "Resident Chinook (Blackmouth)"))
        let chinook = try #require(SpeciesSize.typical(for: "Chinook Salmon (ocean)"))
        #expect(blackmouth.pounds < chinook.pounds)
        // Rock Bass is a panfish, not a Largemouth/Smallmouth bass.
        #expect(SpeciesSize.typical(for: "Rock Bass")?.pounds == 0.5)
    }

    @Test func aBiggerFishDrawsABiggerIcon() throws {
        let perch = try #require(SpeciesSize.typical(for: "Yellow Perch"))
        let coho = try #require(SpeciesSize.typical(for: "Coho Salmon"))
        let halibut = try #require(SpeciesSize.typical(for: "Halibut"))
        #expect(perch.iconPointSize < coho.iconPointSize)
        #expect(coho.iconPointSize < halibut.iconPointSize)
        #expect(perch.iconPointSize >= 16 && halibut.iconPointSize <= 48)
    }

    @Test func eachSpeciesDrawsItsOwnBodyPlan() {
        #expect(SpeciesSize.typical(for: "Halibut")?.form == .flatfish)
        #expect(SpeciesSize.typical(for: "Resident Chinook (Blackmouth)")?.form == .salmon)
        #expect(SpeciesSize.typical(for: "Albacore Tuna")?.form == .tuna)
        #expect(SpeciesSize.typical(for: "Yellow Perch")?.form == .perch)
        #expect(SpeciesSize.typical(for: "Rock Bass")?.form == .panfish)
        #expect(SpeciesSize.typical(for: "Largemouth Bass")?.form == .bass)
    }

    @Test func shellfishGetNoFish() {
        #expect(SpeciesSize.typical(for: "Dungeness Crab") == nil)
        #expect(SpeciesSize.typical(for: "Razor Clams") == nil)
        #expect(SpeciesSize.typical(for: "Spot Shrimp") == nil)
    }

    @Test func everyShippedFinfishHasASize() throws {
        let url = try #require(Bundle.main.url(forResource: "fisheries", withExtension: "json"))
        let names = try FisheryLoader.guide(from: Data(contentsOf: url)).speciesNames
        #expect(names.count > 20, "fisheries.json did not load; this check would pass vacuously")
        let notFish = ["Crab", "Clam", "Shrimp", "Squid"]
        let missing = names.filter { name in
            !notFish.contains { name.contains($0) } && SpeciesSize.typical(for: name) == nil
        }
        #expect(missing.isEmpty, "no typical size for: \(missing)")
    }
}
