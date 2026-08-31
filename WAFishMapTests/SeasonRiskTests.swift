import Foundation
import Testing
@testable import WAFishMap

struct SeasonRiskTests {
    let chinook = SeasonRisk(
        match: "Chinook",
        months: [1, 2, 3],
        reason: "Selective-fishery and quota dates set annually"
    )

    @Test func matchesExactName() {
        #expect(chinook.matches("Chinook Salmon"))
    }

    @Test func matchesParentheticalVariants() {
        #expect(chinook.matches("Chinook Salmon (ocean)"))
        #expect(chinook.matches("Chinook Salmon (Tulalip)"))
        #expect(chinook.matches("Resident Chinook (Blackmouth)"))
    }

    @Test func matchingIsCaseInsensitive() {
        #expect(chinook.matches("CHINOOK SALMON"))
        #expect(chinook.matches("chinook salmon"))
    }

    @Test func doesNotMatchUnrelatedSpecies() {
        #expect(!chinook.matches("Coho Salmon"))
        #expect(!chinook.matches("Rainbow Trout"))
    }
}

struct SeasonRiskResolutionTests {
    /// Minimal guide JSON: one area, two species, one risk row.
    let json = """
    {
      "updated": "2026-08-31",
      "disclaimer": "d",
      "wdfwURL": "https://wdfw.wa.gov",
      "seasonRisk": [
        { "match": "Chinook", "months": [1, 2], "reason": "Quota-driven" }
      ],
      "areas": [
        {
          "areaName": "13",
          "species": [
            { "species": "Chinook Salmon", "bestMonths": [1] },
            { "species": "Rainbow Trout", "bestMonths": [1] }
          ]
        }
      ]
    }
    """.data(using: .utf8)!

    @Test func stampsMatchingSpeciesOnly() throws {
        let guide = try FisheryLoader.guide(from: json)
        let species = try #require(guide.area(named: "13")?.species)
        let chinook = try #require(species.first { $0.species == "Chinook Salmon" })
        let trout = try #require(species.first { $0.species == "Rainbow Trout" })
        #expect(chinook.riskMonths == [1, 2])
        #expect(chinook.riskReason == "Quota-driven")
        #expect(trout.riskMonths.isEmpty)
        #expect(trout.riskReason == nil)
    }

    @Test func unflaggedSpeciesKeepsTheAreaPrime() throws {
        let guide = try FisheryLoader.guide(from: json)
        let area = try #require(guide.area(named: "13"))
        // Trout is unflagged and peaks in January, so the area stays Prime.
        #expect(area.rating(inMonth: 1) == .excellent)
    }

    @Test func areaOfOnlyFlaggedSpeciesCapsToFair() throws {
        let onlyChinook = """
        {
          "updated": "2026-08-31", "disclaimer": "d", "wdfwURL": "u",
          "seasonRisk": [{ "match": "Chinook", "months": [1], "reason": "r" }],
          "areas": [{ "areaName": "13",
            "species": [{ "species": "Chinook Salmon", "bestMonths": [1] }] }]
        }
        """.data(using: .utf8)!
        let guide = try FisheryLoader.guide(from: onlyChinook)
        #expect(guide.area(named: "13")?.rating(inMonth: 1) == .fair)
    }

    @Test func rowCanOptOutOfTheTable() throws {
        let optOut = """
        {
          "updated": "2026-08-31", "disclaimer": "d", "wdfwURL": "u",
          "seasonRisk": [{ "match": "Chinook", "months": [1], "reason": "r" }],
          "areas": [{ "areaName": "13", "species": [
            { "species": "Chinook Salmon", "bestMonths": [1], "seasonRisk": "none" }
          ] }]
        }
        """.data(using: .utf8)!
        let guide = try FisheryLoader.guide(from: optOut)
        let species = try #require(guide.area(named: "13")?.species.first)
        #expect(species.riskMonths.isEmpty)
        #expect(guide.area(named: "13")?.rating(inMonth: 1) == .excellent)
    }

    @Test func guideWithoutTableIsUnchanged() throws {
        let noTable = """
        {
          "updated": "2026-08-31", "disclaimer": "d", "wdfwURL": "u",
          "areas": [{ "areaName": "13",
            "species": [{ "species": "Chinook Salmon", "bestMonths": [1] }] }]
        }
        """.data(using: .utf8)!
        let guide = try FisheryLoader.guide(from: noTable)
        #expect(guide.area(named: "13")?.rating(inMonth: 1) == .excellent)
    }
}
