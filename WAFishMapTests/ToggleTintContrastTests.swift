import SwiftUI
import Testing
import UIKit
@testable import WAFishMap

/// A layer toggle that is on is a filled capsule with its label over it, so
/// the fill must carry white text at 4.5:1 in both appearances.
struct ToggleTintContrastTests {
    typealias Contrast = RatingBadgeContrastTests

    static let fills: [(name: String, color: Color)] = [
        ("Rivers", DS.Chrome.riversOn), ("Heat", DS.Chrome.heatOn),
    ]

    @Test(arguments: [UIUserInterfaceStyle.light, .dark])
    func whiteLabelReadsOnEveryOnStateFill(style: UIUserInterfaceStyle) {
        let white = Contrast.components(.white, style)
        for fill in Self.fills {
            let measured = Contrast.ratio(white, Contrast.components(fill.color, style))
            #expect(measured >= 4.5,
                    "\(fill.name) on-state is \(String(format: "%.2f", measured)):1 in \(style == .light ? "light" : "dark"); needs 4.5:1.")
        }
    }

    /// The control, and the reason Heat does not reuse the overlay token:
    /// the overlay's dark value is lightened to read on a dark map, which
    /// leaves it too light to carry white text.
    @Test func whiteOnTheDarkOverlayVioletFails() {
        let white = Contrast.components(.white, .dark)
        let violet = Contrast.components(DS.Overlay.density, .dark)
        #expect(Contrast.ratio(white, violet) < 4.5)
    }
}
