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

    @Test func multipleMatchingRowsUnionMonthsAndJoinReasons() throws {
        // "Chinook Salmon (ocean)" matches both the "Chinook Salmon (ocean)" row
        // and the general "Chinook Salmon" row — live in shipped data — so
        // resolvingSeasonRisk must union their months and join both reasons.
        let twoRows = """
        {
          "updated": "2026-08-31", "disclaimer": "d", "wdfwURL": "u",
          "seasonRisk": [
            { "match": "Chinook Salmon (ocean)", "months": [6, 7, 8], "reason": "Ocean quota" },
            { "match": "Chinook Salmon", "months": [7, 8, 9], "reason": "Summer quota" }
          ],
          "areas": [{ "areaName": "13",
            "species": [{ "species": "Chinook Salmon (ocean)", "bestMonths": [7] }] }]
        }
        """.data(using: .utf8)!
        let guide = try FisheryLoader.guide(from: twoRows)
        let species = try #require(guide.area(named: "13")?.species.first)
        #expect(species.riskMonths == [6, 7, 8, 9])
        #expect(species.riskReason == "Ocean quota; Summer quota")
    }

    @Test func byCountyFreshwaterSpeciesAreResolved() throws {
        let byCounty = """
        {
          "updated": "2026-08-31", "disclaimer": "d", "wdfwURL": "u",
          "seasonRisk": [{ "match": "Chinook", "months": [1, 2], "reason": "Quota-driven" }],
          "areas": [],
          "freshwater": {
            "species": [{ "species": "Rainbow Trout", "bestMonths": [1] }],
            "byCounty": {
              "Skagit": [{ "species": "Chinook Salmon", "bestMonths": [1] }]
            }
          }
        }
        """.data(using: .utf8)!
        let guide = try FisheryLoader.guide(from: byCounty)
        let fishery = try #require(guide.freshwater?.fishery(county: "Skagit"))
        let chinook = try #require(fishery.species.first { $0.species == "Chinook Salmon" })
        #expect(chinook.riskMonths == [1, 2])
        #expect(chinook.riskReason == "Quota-driven")
    }

    @Test func missingAreasKeyThrows() {
        let noAreas = """
        {
          "updated": "2026-08-31", "disclaimer": "d", "wdfwURL": "u"
        }
        """.data(using: .utf8)!
        #expect(throws: (any Error).self) {
            try FisheryLoader.guide(from: noAreas)
        }
    }
}

struct ShippedSeasonRiskTests {
    func loadShipped() throws -> FisheryGuide {
        let url = try #require(Bundle.main.url(forResource: "fisheries", withExtension: "json"))
        return try FisheryLoader.guide(from: Data(contentsOf: url))
    }

    @Test func shippedGuideCarriesATable() throws {
        #expect(try !loadShipped().seasonRisk.isEmpty)
    }

    @Test func everyRowHasMonthsAndAReason() throws {
        for row in try loadShipped().seasonRisk {
            #expect(!row.months.isEmpty, "\(row.match) has no months")
            #expect(!row.reason.isEmpty, "\(row.match) has no reason")
            #expect(row.months.allSatisfy { (1...12).contains($0) }, "\(row.match) month out of range")
        }
    }

    /// Matches the date idioms the shipped prose actually uses: `Mon-Mon` (e.g.
    /// "Mar-Apr"), `Month day` (e.g. "May 1"), and `mid-Month` (e.g. "mid-June").
    /// An en dash or `\d{1,2}/\d{1,2}` catches neither — this file writes hyphenated
    /// month ranges, never slash dates — so those idioms alone let every possible
    /// reason string pass. Proven below against a known-bad and a known-good sample.
    private static let monthNames = "Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec|January|February|March|April|June|July|August|September|October|November|December"
    private static let datePattern = try! Regex(
        #"(\#(monthNames))\s*-\s*(\#(monthNames))|(\#(monthNames))\s+\d{1,2}|mid-(\#(monthNames))"#,
        as: (Substring, Substring?, Substring?, Substring?, Substring?).self
    ).ignoresCase()

    @Test func dateDetectorFiresOnKnownBadSample() {
        #expect(try "Open May 1-Jun 15".firstMatch(of: Self.datePattern) != nil)
        #expect(try "mid-June closure".firstMatch(of: Self.datePattern) != nil)
        #expect(try "Season runs Mar-Apr".firstMatch(of: Self.datePattern) != nil)
    }

    @Test func dateDetectorDoesNotFireOnKnownGoodSample() {
        #expect(try "Season dates set annually".firstMatch(of: Self.datePattern) == nil)
        #expect(try "Quota-driven summer fishery; confirm before you go".firstMatch(of: Self.datePattern) == nil)
    }

    @Test func noReasonStatesADate() throws {
        // The reason explains why to verify; it must not read as a season date.
        for row in try loadShipped().seasonRisk {
            #expect(try row.reason.firstMatch(of: Self.datePattern) == nil,
                    "\(row.match) reason contains a date")
        }
    }

    @Test func noSpeciesNoteStatesADate() throws {
        // SiteDetailSheet renders species.note on the same card as the risk
        // badge; a note that states a closure window as fact undermines it.
        let guide = try loadShipped()
        var allSpecies: [SpeciesSeason] = guide.areas.flatMap(\.species)
        if let freshwater = guide.freshwater {
            allSpecies += freshwater.species
            for overrides in (freshwater.byCounty ?? [:]).values {
                allSpecies += overrides
            }
        }
        for species in allSpecies {
            guard let note = species.note else { continue }
            #expect(try note.firstMatch(of: Self.datePattern) == nil,
                    "\(species.species) note contains a date: \(note)")
        }
    }

    @Test func freshwaterStaplesAreNotFlagged() throws {
        // Categories, not four literal names: any species whose name contains one
        // of these words is a year-round-ish freshwater staple and must never
        // carry a risk clamp, wherever it appears in the shipped guide.
        let staple = ["Trout", "Bass", "Walleye", "Kokanee", "Catfish"]
        let guide = try loadShipped()

        var allSpecies: [SpeciesSeason] = guide.areas.flatMap(\.species)
        if let freshwater = guide.freshwater {
            allSpecies += freshwater.species
            let byCounty: [String: [SpeciesSeason]] = freshwater.byCounty ?? [:]
            for overrides in byCounty.values {
                allSpecies += overrides
            }
        }

        for species in allSpecies {
            guard staple.contains(where: { species.species.localizedCaseInsensitiveContains($0) }) else { continue }
            #expect(species.riskMonths.isEmpty, "\(species.species) is a freshwater staple and should stay unflagged")
        }
    }

    @Test func salmonAndShellfishAreFlagged() throws {
        let guide = try loadShipped()
        for name in ["Chinook Salmon", "Coho Salmon (ocean)", "Dungeness Crab", "Lingcod"] {
            #expect(guide.seasonRisk.contains { $0.matches(name) }, "\(name) should be flagged")
        }
    }

    @Test func noRowFlagsEveryMonth() throws {
        for row in try loadShipped().seasonRisk {
            #expect(Set(row.months).count < 12, "\(row.match) flags every month — that is a blanket cap")
        }
    }
}
