import Testing
@testable import WAFishMap

/// `LonLat.groupRings(_:)` — the pure outer/hole classification the map
/// overlay builder uses to render a genuine hole as a cutout instead of an
/// opaque fill. `contains(_:)` stays flat across all rings; this is purely
/// about how the rings get grouped for rendering.
struct LonLatTests {
    private let bigSquare = [
        LonLat(longitude: -10, latitude: -10), LonLat(longitude: 10, latitude: -10),
        LonLat(longitude: 10, latitude: 10), LonLat(longitude: -10, latitude: 10),
    ]

    private let smallSquare = [
        LonLat(longitude: -2, latitude: -2), LonLat(longitude: 2, latitude: -2),
        LonLat(longitude: 2, latitude: 2), LonLat(longitude: -2, latitude: 2),
    ]

    private let farSquare = [
        LonLat(longitude: 20, latitude: 20), LonLat(longitude: 22, latitude: 20),
        LonLat(longitude: 22, latitude: 22), LonLat(longitude: 20, latitude: 22),
    ]

    @Test func disjointRingsAreBothOuters() {
        let groups = LonLat.groupRings([bigSquare, farSquare])
        #expect(groups.count == 2)
        #expect(groups.allSatisfy { $0.holes.isEmpty })
    }

    @Test func aRingInsideAnotherBecomesItsHole() {
        let groups = LonLat.groupRings([bigSquare, smallSquare])
        #expect(groups.count == 1)
        let outer = try? #require(groups.first)
        #expect(outer?.outer == bigSquare)
        #expect(outer?.holes == [smallSquare])
    }

    /// The known-good control: a single ring has nothing to classify against,
    /// so it is its own outer with no holes.
    @Test func aSingleRingIsAnOuterWithNoHoles() {
        let groups = LonLat.groupRings([bigSquare])
        #expect(groups.count == 1)
        #expect(groups.first?.outer == bigSquare)
        #expect(groups.first?.holes.isEmpty == true)
    }

    @Test func emptyRingsProduceNoGroups() {
        #expect(LonLat.groupRings([]).isEmpty)
    }
}
