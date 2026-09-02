import Testing
import UIKit
@testable import WAFishMap

/// Guards against a repeat of `anchor.fill`: a plausible-looking SF Symbol name
/// that is not real, so `UIImage(systemName:)` returned nil and MapKit silently
/// fell back to its default pin instead of erroring.
struct SiteMarkerGlyphTests {
    @Test func everyKindResolvesToARealSymbol() {
        for kind in SiteAnnotation.Kind.allCases {
            let name = SiteMarkerView.symbol(for: kind)
            #expect(UIImage(systemName: name) != nil, "\(kind) maps to \"\(name)\", which is not a real SF Symbol")
        }
    }
}
