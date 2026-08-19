import Foundation
import Testing
@testable import WAFishMap

struct FishingMapModelTests {
    @Test @MainActor func loadFromBundleKeepsBostonHarborAndArea13() async throws {
        let model = FishingMapModel()
        try model.loadFromBundle(bundle: .main)
        #expect(model.marineAreas.map(\.areaName) == ["13"])
        // The fixture has an interior ring; only the 4-vertex outer ring survives.
        #expect(model.marineAreas[0].coordinates.count == 4)
        #expect(Set(model.accessSites.map(\.facilityName)) == ["Boston Harbor", "Luhr's Landing"])
        #expect(model.statusMessage == MapScope.summary)
    }
}
