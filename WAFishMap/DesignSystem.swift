import SwiftUI
import UIKit

/// The app's design tokens.
///
/// Two rules hold this together:
///
/// 1. **A view names a role, never a raw value.** `DS.Rating.prime`, not
///    `Color(red: 0.94, ...)`; `DS.TypeScale.legend`, not `.caption2`. When a
///    decision changes it changes here, once, instead of being hunted across
///    three view files.
/// 2. **Defer to the platform wherever the platform is already right.** The
///    Apple foundations define a complete Light *and* Dark value for every
///    system colour, and `Color.blue` and friends already resolve to them per
///    appearance. Re-typing those hex values here would mean owning a palette
///    that Apple maintains for free — and owning it badly, since a hardcoded
///    `Color(red:green:blue:)` cannot follow the appearance at all.
///
/// That second rule is why so little below is a literal. A token that just
/// forwards to a system colour is not indirection for its own sake: it names
/// *why* this app uses that colour, so the reason survives the next redesign.
enum DS {

    // MARK: - Rating ramp

    /// The thermal ramp, cold to hot, one step per `FishingRating`.
    ///
    /// The four-stop design is unchanged and deliberate — see the decision log:
    /// sampling a continuous blue-to-red line ran the midtones through magenta,
    /// which reads as some other scale rather than as heat, so the stops are
    /// stated explicitly.
    ///
    /// What changed is the anchors. Each stop was a hand-mixed literal sitting
    /// near an Apple system colour without matching it — Slow was 7 units off
    /// `systemBlue`, Fair 5 off `systemYellow`. At that distance nobody reads a
    /// deliberate choice; it reads as a colour that failed to load, especially
    /// beside a real system control. Anchoring on the system colours keeps the
    /// blue → yellow → orange → red ramp exactly, and gains the dark-appearance
    /// variants the literals could never have.
    ///
    /// The ramp keeps deferring to the platform, and that was measured rather
    /// than assumed. The plan for this work expected Apple's stops to be too
    /// close in lightness and budgeted for hand-picked literals with an
    /// explicit platform-deference exception. Resolving the tokens on device
    /// said otherwise: every adjacent pair clears ΔL* 12 in both appearances,
    /// so the exception was not needed and was not taken.
    ///
    /// `RampLightnessTests` holds the numbers and fails the build if a later
    /// change closes the gap. Two things it deliberately does not cover, both
    /// live questions for the map rather than for these tokens: `prime` and
    /// `slow` are within half an L* of each other, so red and blue pins differ
    /// by hue alone, and `unrated` grey sits between them. Adjacency in the
    /// ramp is not adjacency on screen.
    enum Rating {
        /// Nothing notable in season.
        static let slow = Color.blue
        /// Shoulder of a season.
        static let fair = Color.yellow
        /// A species is in a good stretch.
        static let good = Color.orange
        /// A species is at its peak.
        static let prime = Color.red
        /// A site with no curated season data — inland launches match no marine
        /// area by design, so this is a normal state, not a failure.
        static let unrated = Color.gray
    }

    // MARK: - Overlay

    enum Overlay {
        /// Hue for the heat overlay's density bands.
        ///
        /// The one colour here that is genuinely custom, for two reasons that
        /// both still hold. It must not be mistakable for a rating, which is why
        /// it is violet — the hue the rating ramp gave up. And it is tuned
        /// against a *muted* basemap: a translucent fill takes its apparent
        /// colour from whatever sits beneath it, so before the basemap was
        /// drained one band read pink over city, brown over forest and violet
        /// over water. Do not migrate this to `systemPurple` and do not drop the
        /// muting; they are a pair.
        ///
        /// The light value is the tuned original. The dark value is lightened so
        /// it still reads against a dark muted basemap, and is the one token
        /// here that wants confirming on a device.
        static let density = DS.adaptive(light: 0x7A29B8, dark: 0xA86FD6)
    }

    // MARK: - Chrome

    enum Chrome {
        /// Fill behind the Rivers toggle when on.
        ///
        /// The button toggle style fills with its tint and puts the label
        /// over it, so this has to carry white text. System teal does not
        /// (about 2.6:1 by calculation), so this is a literal: a deep teal
        /// between the app icon's two gradient stops. One value for both
        /// appearances because the label on it is white in both.
        static let riversOn = Color(red: 0x00 / 255, green: 0x7C / 255, blue: 0x9E / 255)

        /// Fill behind the Heat toggle when on: the overlay violet's light
        /// value, in both appearances. The overlay's own dark value is
        /// lightened for a dark map and cannot carry white text.
        static let heatOn = Color(red: 0x7A / 255, green: 0x29 / 255, blue: 0xB8 / 255)
    }

    // MARK: - Surfaces

    enum Surface {
        /// Floating chrome over the map — the legend and control bars.
        static let chromeRadius: CGFloat = 14

        /// The "Before you go" advisory block on a detail sheet.
        ///
        /// Was a flat `.yellow` wash, which collided head-on with the ramp:
        /// yellow is *also* the Fair rating, and both appear on the same sheet,
        /// so a reader had no way to tell a caution from a rating. A neutral
        /// system fill removes the collision and adapts by appearance; the
        /// shield glyph and the heading carry the caution on their own.
        static let advisory = Color(.secondarySystemFill)
        static let advisoryRadius: CGFloat = 12

        /// A species row inside "What's biting".
        static let speciesRow = Color(.quaternarySystemFill)
        static let speciesRowRadius: CGFloat = 10
    }

    // MARK: - Ink

    enum Ink {
        /// Disclaimers, attributions, "updated" stamps, axis words.
        ///
        /// Was `.tertiary`, about 1.7:1 on white: below any floor, and it
        /// carried a season-risk reason, which is safety-relevant. It is the
        /// secondary label colour so that size, not lightness, separates fine
        /// print from the supporting text above it.
        static let fineprint = Color(uiColor: .secondaryLabel)
    }

    // MARK: - Type

    /// Roles from the SF Pro ramp.
    ///
    /// Each role is bound to the step the app uses today, so adopting these is a
    /// rename with no visual change. That is the point: once every call site
    /// names a role, moving a role up the ramp is one edit here rather than
    /// twenty across the views.
    ///
    /// Worth knowing before that edit: of 48 type calls in the app, 31 sit on
    /// the two smallest steps and `.body` — the step the whole ramp is built
    /// around — is never used. `control` and `legend` are the roles most likely
    /// to want promoting; they label things a person reads outdoors, at arm's
    /// length, in the wind.
    enum TypeScale {
        /// Section heading inside a sheet.
        static let sectionTitle = Font.headline
        /// A species name, a site name — the subject of its row.
        static let itemTitle = Font.subheadline.weight(.semibold)
        /// Supporting sentence under a title.
        static let supporting = Font.subheadline
        /// Label on a map control or a time-of-day readout.
        static let control = Font.caption2.weight(.semibold)
        /// Legend entries and axis labels on the map chrome.
        static let legend = Font.caption2
        /// A marine-area name drawn on the map itself, not in the chrome.
        static let mapLabel = Font.caption2.weight(.semibold)
        /// Secondary detail on a row: bait, best months.
        static let meta = Font.caption
        /// Disclaimers, "updated" stamps, attribution.
        static let fineprint = Font.caption2
        /// Count inside a cluster mark.
        static let clusterCount = Font.caption2.bold()
        /// Rating capsule.
        static let badge = Font.caption.bold()

        /// A tide extreme's time and height. Monospaced digits so the column of
        /// times and the column of feet stay aligned down the table.
        static let tideValue = Font.subheadline.monospacedDigit()

        /// A tide row's label. The next extreme after the plan time is the one
        /// the reader is actually looking for, so it carries the weight.
        static func tideRow(isNext: Bool) -> Font {
            Font.subheadline.weight(isNext ? .semibold : .regular)
        }
    }

    // MARK: - Appearance plumbing

    /// A colour that resolves per appearance, for the few values the platform
    /// does not already provide. Prefer a system colour over calling this.
    static func adaptive(light: UInt32, dark: UInt32) -> Color {
        Color(UIColor { traits in
            UIColor(rgb: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

private extension UIColor {
    /// 0xRRGGBB, opaque.
    convenience init(rgb: UInt32) {
        self.init(
            red: CGFloat((rgb >> 16) & 0xFF) / 255,
            green: CGFloat((rgb >> 8) & 0xFF) / 255,
            blue: CGFloat(rgb & 0xFF) / 255,
            alpha: 1
        )
    }
}

/// A layer switch in the map's control bar: a solid `onFill` with a white
/// label when on, a neutral capsule when off.
///
/// The system button toggle style was tried first and draws a pale wash with
/// tinted text instead, which is nearly unreadable in dark appearance. This
/// draws the fill itself so `ToggleTintContrastTests` measures what is on
/// screen. It stays a `Toggle`, and `isSelected` is what makes assistive tech
/// hear the state.
struct LayerToggleStyle: ToggleStyle {
    let onFill: Color

    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            configuration.label
                .foregroundStyle(configuration.isOn ? Color.white : Color.primary)
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(configuration.isOn ? onFill : Color(.tertiarySystemFill), in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(configuration.isOn ? .isSelected : [])
    }
}
