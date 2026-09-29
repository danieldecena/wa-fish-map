import Testing
@testable import WAFishMap

/// The ribbon replaces "Best months: Jun, Jul, Aug", which loses the shape of
/// a season. These assert the shape survives, and that the rotation does what
/// it was chosen for.
struct SeasonRibbonTests {

    /// riskMonths is stamped at load rather than decoded, so it is set after
    /// construction here too.
    static func season(best: [Int], good: [Int] = [], risk: [Int] = []) -> SpeciesSeason {
        var s = SpeciesSeason(species: "Coho Salmon", bestMonths: best, goodMonths: good)
        s.riskMonths = risk
        return s
    }

    @Test func theRibbonIsTwelveCellsStartingAtTheCurrentMonth() {
        let cells = SeasonRibbon.cells(for: Self.season(best: [9, 10]), current: 7)
        #expect(cells.count == 12)
        #expect(cells.first?.month == 7)
        #expect(cells.map(\.month) == [7, 8, 9, 10, 11, 12, 1, 2, 3, 4, 5, 6])
        #expect(cells.first?.isCurrent == true)
        #expect(cells.dropFirst().allSatisfy { !$0.isCurrent })
    }

    /// The reason the strip rotates. On a fixed Jan-Dec strip a Nov-Feb season
    /// is two blobs at opposite ends; rotated, it is one run.
    @Test func aWinterSeasonReadsAsOneRunRatherThanTwoBlobs() {
        let cells = SeasonRibbon.cells(for: Self.season(best: [11, 12, 1, 2]), current: 11)
        let peaks = cells.enumerated().filter { $0.element.rating == .excellent }.map(\.offset)
        #expect(peaks == [0, 1, 2, 3], "Peak months must be contiguous from the left, got \(peaks)")
    }

    @Test func theSameSeasonOnAJanuaryStripWouldHaveBeenSplit() {
        // The control for the test above: this is the layout that was rejected.
        let season = Self.season(best: [11, 12, 1, 2])
        let januaryOrder = (1...12).map { season.rating(inMonth: $0) }
        let peaks = januaryOrder.enumerated().filter { $0.element == .excellent }.map(\.offset)
        #expect(peaks == [0, 1, 10, 11], "A fixed strip splits this season, which is why it was not used.")
    }

    @Test func everyMonthCarriesItsOwnRating() {
        let cells = SeasonRibbon.cells(for: Self.season(best: [9], good: [8]), current: 8)
        #expect(cells.first { $0.month == 9 }?.rating == .excellent)
        #expect(cells.first { $0.month == 8 }?.rating == .good)
    }

    /// Risk rides a shape, not a shade: colour is already spent on the rating.
    @Test func riskMonthsAreFlaggedSeparatelyFromTheirRating() {
        let cells = SeasonRibbon.cells(for: Self.season(best: [9, 10], risk: [10]), current: 9)
        #expect(cells.first { $0.month == 10 }?.isRisk == true)
        #expect(cells.first { $0.month == 9 }?.isRisk == false)
    }

    @Test func rotatingNeverLosesOrRepeatsAMonth() {
        for current in 1...12 {
            let months = SeasonRibbon.cells(for: Self.season(best: [6]), current: current).map(\.month)
            #expect(Set(months).count == 12, "current=\(current) produced \(months)")
            #expect(Set(months) == Set(1...12))
        }
    }

    @Test func theSpokenValueNamesNowAndThePeaks() {
        let cells = SeasonRibbon.cells(for: Self.season(best: [9, 10]), current: 9)
        let said = SeasonRibbon.spoken(cells)
        #expect(said.contains("now rated Prime"))
        #expect(said.contains("S"))

        let quiet = SeasonRibbon.cells(for: Self.season(best: []), current: 3)
        #expect(SeasonRibbon.spoken(quiet).contains("no peak months"))
    }

    @Test func theCaptionAnchorsTheLeftEndAsNow() {
        let cells = SeasonRibbon.cells(for: Self.season(best: [9]), current: 7)
        #expect(SeasonRibbon.caption(cells).hasPrefix("Now (J)"))
    }
}

import MapKit
import SwiftUI
import UIKit

/// The risk mark sits on a ribbon cell, which is a rating colour, so it has
/// the same contrast problem the map glyph had -- and it shipped white on
/// first draft, which measures 1.51:1 on the Fair stop.
struct SeasonRibbonInkTests {

    @Test(arguments: [UIUserInterfaceStyle.light, .dark])
    func theRiskMarkUsesTheSameInkRuleAsTheMapGlyph(style: UIUserInterfaceStyle) {
        func ink(_ r: FishingRating) -> UIColor {
            SiteMarkerView.glyphTint(on: UIColor(r.color))
                .resolvedColor(with: UITraitCollection(userInterfaceStyle: style))
        }
        let white = UIColor.white.resolvedColor(with: UITraitCollection(userInterfaceStyle: style))
        let black = UIColor.black.resolvedColor(with: UITraitCollection(userInterfaceStyle: style))

        // Fair is the cell that made this necessary.
        #expect(ink(.fair) == black)
        #expect(ink(.good) == black)
        #expect(ink(.excellent) == white)
        #expect(ink(.poor) == white)
    }
}
