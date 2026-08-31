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
