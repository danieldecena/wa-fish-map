import Foundation
import Testing
@testable import WAFishMap

/// The flow strip's position function.
///
/// The strip replaces a sentence, and the sentence was never wrong -- it just
/// could not show *how far* into a tail a reading was. The one thing the strip
/// must not do is imply more-is-better: `flowRating` is deliberately
/// non-monotonic, because a river is unfishable bony and unfishable blowing
/// out, so this returns a position on a distribution and never a score.
/// A plausible skewed day: the top of the range is 8x the bottom.
/// File scope, not a static on the suite, so the test bodies can call it
/// unqualified.
private let skewedDay: [Double] = [100, 180, 400, 900, 1600]

private func pos(_ d: Double) -> Double? {
    RiverFlowStats.trackPosition(discharge: d, percentiles: skewedDay)
}

struct RiverFlowTrackTests {

    @Test func eachPercentileLandsOnItsOwnStop() throws {
        #expect(try #require(pos(100)) == 0.10)
        #expect(abs(try #require(pos(180)) - 0.25) < 0.0001)
        #expect(abs(try #require(pos(400)) - 0.50) < 0.0001)
        #expect(abs(try #require(pos(900)) - 0.75) < 0.0001)
        #expect(abs(try #require(pos(1600)) - 0.90) < 0.0001)
    }

    /// The reason for interpolating through the percentiles rather than along
    /// the cfs axis. The median is 400 of a 1600 range, so a linear cfs axis
    /// would put the median a quarter of the way along instead of halfway.
    @Test func theAxisIsThePercentilesNotTheRawFlow() throws {
        let median = try #require(pos(400))
        #expect(abs(median - 0.5) < 0.0001)
        #expect(median > 400 / 1600)
    }

    @Test func aBoneDryRiverSitsHardLeftRatherThanAtTheFirstStop() throws {
        #expect(try #require(pos(0)) == 0)
        #expect(try #require(pos(50)) < 0.10)
    }

    @Test func aBlownOutRiverSaturatesInsteadOfSquashingTheStrip() throws {
        #expect(try #require(pos(2400)) > 0.90)
        #expect(try #require(pos(3200)) == 1.0)
        // Ten times the 90th and twice it are both simply blown out.
        #expect(try #require(pos(16000)) == 1.0)
    }

    @Test func positionRisesWithFlowEverywhereOnTheStrip() throws {
        let samples = [0.0, 50, 100, 140, 180, 300, 400, 650, 900, 1200, 1600, 2000, 3200]
        let positions = try samples.map { try #require(pos($0)) }
        #expect(zip(positions, positions.dropFirst()).allSatisfy { $0 <= $1 })
        #expect(positions.allSatisfy { (0...1).contains($0) })
    }

    /// A short record can repeat a percentile row. Dividing by that zero span
    /// would produce a NaN position, which draws the marker nowhere at all.
    @Test func repeatedPercentilesDoNotProduceANaN() throws {
        let flat: [Double] = [100, 100, 100, 100, 100]
        let position = try #require(RiverFlowStats.trackPosition(discharge: 100, percentiles: flat))
        #expect(!position.isNaN)
        #expect((0...1).contains(position))
    }

    /// Unusable input renders as no strip, never as a marker at zero.
    @Test func missingOrMalformedPercentilesGiveNoPosition() {
        #expect(RiverFlowStats.trackPosition(discharge: 400, percentiles: []) == nil)
        #expect(RiverFlowStats.trackPosition(discharge: 400, percentiles: [1, 2, 3]) == nil)
        #expect(RiverFlowStats.trackPosition(discharge: 400, percentiles: [0, 180, 400, 900, 1600]) == nil)
    }
}

/// The strip's spoken value. It is the whole content for a blind reader --
/// the visual is spatial and conveys nothing through VoiceOver on its own.
struct FlowRangeStripSpokenTests {

    @Test func eachBandOfTheStripSaysSomethingDifferent() {
        let said = [0.02, 0.18, 0.50, 0.82, 0.96]
            .map { FlowRangeStrip.spoken(position: $0, discharge: 400) }
        #expect(Set(said).count == 5, "Each band must read differently: \(said)")
        #expect(said.allSatisfy { $0.contains("400 cfs") })
    }

    @Test func theMiddleOfTheStripReadsAsNormalAndTheTailsDoNot() {
        #expect(FlowRangeStrip.spoken(position: 0.5, discharge: 400).contains("within the normal range"))
        #expect(FlowRangeStrip.spoken(position: 0.01, discharge: 12).contains("well below"))
        #expect(FlowRangeStrip.spoken(position: 1.0, discharge: 9000).contains("well above"))
    }

    /// Both tails are unfishable, and neither may read as good or bad -- the
    /// rating is non-monotonic and the strip must not smuggle a direction in.
    @Test func neitherTailIsDescribedAsBetterThanTheOther() {
        let low = FlowRangeStrip.spoken(position: 0.01, discharge: 12)
        let high = FlowRangeStrip.spoken(position: 1.0, discharge: 9000)
        for word in ["good", "bad", "best", "worse", "poor", "great"] {
            #expect(!low.lowercased().contains(word))
            #expect(!high.lowercased().contains(word))
        }
    }
}

/// The seam's stand-in reading. It exists so the strip can be looked at; if it
/// silently returned nil the sheet would render its error state and a frame of
/// that error would ship, which is what used to happen.
struct FixtureFlowTests {

    @Test func theFixtureReadingLandsInsideTheRiversOwnRange() throws {
        let bundle = try #require(FixtureBundle.loader)
        let url = try #require(bundle.url(forResource: "river_stats", withExtension: "json"))
        let all = try RiverFlowStatsLoader.stats(from: Data(contentsOf: url))
        let stats = try #require(all.values.first { $0.percentiles(month: 8, day: 15) != nil })
        let flow = try #require(FishingMapModel.fixtureFlow(stats: stats))
        let discharge = try #require(flow.discharge)
        let row = try #require(stats.percentiles(month: 8, day: 15))

        #expect(discharge == row[3], "The stand-in is the river's own p75.")
        let position = try #require(
            RiverFlowStats.trackPosition(discharge: discharge, percentiles: row))
        // Off centre on purpose: a marker pinned at the median would hide an
        // axis that was not being applied at all.
        #expect(position > 0.5)
        #expect(position < 0.9)
    }

    @Test func noStatsMeansNoStandInRatherThanAFabricatedReading() {
        #expect(FishingMapModel.fixtureFlow(stats: nil) == nil)
    }
}
