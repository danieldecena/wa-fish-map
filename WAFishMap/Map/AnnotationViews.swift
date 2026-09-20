import MapKit
import SwiftUI

/// How large a marker draws, relative to `MKMarkerAnnotationView`'s own size.
///
/// The class has no size property, so both values are applied as a transform.
/// At the default size the balloons covered the place labels they are meant to
/// sit beside at regional zoom — a map of pins rather than a map with pins on
/// it. A cluster stays a fixed step above a single pin so "13" never reads as
/// one spot.
enum MarkerMetrics {
    static let pin: CGFloat = 0.8
    static let cluster: CGFloat = 0.95

    /// Scaling happens about the view's centre, which walks the balloon's tip
    /// off its coordinate. Translating by half the height change puts it back,
    /// in either direction: the term is negative when shrinking.
    static func transform(for view: MKAnnotationView, scale: CGFloat) -> CGAffineTransform {
        let lift = view.bounds.height * (scale - 1) / 2
        return CGAffineTransform(translationX: 0, y: -lift).scaledBy(x: scale, y: scale)
    }
}

/// The marine-area "MA n" capsule. A plain annotation, deliberately outside the
/// site cluster group — labels must not merge into a site badge.
final class AreaLabelAnnotation: NSObject, MKAnnotation {
    let coordinate: CLLocationCoordinate2D
    let text: String

    init(area: MarineArea) {
        self.coordinate = area.center
        self.text = "MA \(area.areaName)"
    }
}

/// Site / pier pin. `clusteringIdentifier` is the whole point of the migration:
/// MapKit groups the views that collide and places the cluster at its members'
/// mean, so badges declutter instead of tiling a lattice.
final class SiteMarkerView: MKMarkerAnnotationView {
    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        clusteringIdentifier = "site"
        displayPriority = .defaultLow
        canShowCallout = false
        apply(annotation)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var annotation: MKAnnotation? {
        didSet {
            clusteringIdentifier = "site"
            apply(annotation)
        }
    }

    // Applied at both points: a dequeued view is not always laid out again
    // before MapKit shows it, so `layoutSubviews` alone leaves a reused marker
    // at full size on screen.
    override func layoutSubviews() {
        super.layoutSubviews()
        applyScale()
    }

    override func prepareForDisplay() {
        super.prepareForDisplay()
        applyScale()
    }

    private func applyScale() {
        let target = MarkerMetrics.transform(for: self, scale: MarkerMetrics.pin)
        if transform != target { transform = target }
    }

    /// A boat for a launch, an angler for a shore-only site, a fish for a pier;
    /// tint is the rating colour, neutral gray when unrated. `anchor.fill` (the
    /// original SwiftUI `Marker` glyph) is not a real SF Symbol — it resolves to
    /// nil and MapKit silently falls back to a default pin.
    private func apply(_ annotation: MKAnnotation?) {
        guard let site = annotation as? SiteAnnotation else { return }
        Self.paint(self, tint: UIColor(site.rating?.color ?? .gray), outlined: site.closurePlausible)
        glyphImage = UIImage(systemName: Self.symbol(for: site.kind))
        // Faded gray: still tappable, so the details stay one tap away.
        alpha = site.isClosed ? 0.55 : 1
        isAccessibilityElement = true
        accessibilityLabel = site.title
        accessibilityValue = site.spokenSummary
        accessibilityTraits = .button
    }

    /// Outlined = a pale balloon with the rating colour moved to the glyph, so a
    /// "season may be closed, verify" spot keeps its colour and its tap target.
    /// Both branches set both tints: views are reused across annotations.
    static func paint(_ view: MKMarkerAnnotationView, tint: UIColor, outlined: Bool) {
        view.markerTintColor = outlined ? .systemBackground : tint
        view.glyphTintColor = outlined ? tint : glyphTint(on: tint)
    }

    /// Ink for a glyph sitting on a filled balloon.
    ///
    /// White was used on every stop, which works on the dark end of the ramp
    /// and fails on the light end: white on Fair measured 1.51:1 in light and
    /// 1.41:1 in dark, against a 3:1 floor. Rather than hardcode which stops
    /// are light -- a list that goes stale the moment a token moves -- this
    /// picks whichever ink actually contrasts more with the balloon.
    ///
    /// Resolved inside a dynamic provider so it re-decides per appearance:
    /// the ramp's stops are themselves dynamic, so the right ink in light is
    /// not always the right ink in dark.
    static func glyphTint(on balloon: UIColor) -> UIColor {
        UIColor { traits in
            let resolved = balloon.resolvedColor(with: traits)
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            resolved.getRed(&r, green: &g, blue: &b, alpha: &a)
            func linear(_ c: CGFloat) -> Double {
                let v = Double(c)
                return v <= 0.04045 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
            }
            let luminance = 0.2126 * linear(r) + 0.7152 * linear(g) + 0.0722 * linear(b)
            // Contrast against white vs against black, same formula both sides.
            return (1.05 / (luminance + 0.05)) >= ((luminance + 0.05) / 0.05) ? .white : .black
        }
    }

    static func symbol(for kind: SiteAnnotation.Kind) -> String {
        switch kind {
        case .launch: "sailboat.fill"
        case .shore: "figure.fishing"
        case .pier: "fish.fill"
        }
    }
}

/// The cluster badge. Coloured by its best-rated member so a cluster still
/// carries the map's rating signal rather than reading as one flat red.
final class SiteClusterView: MKMarkerAnnotationView {
    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        displayPriority = .defaultHigh
        collisionMode = .circle
        canShowCallout = false
        apply(annotation)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var annotation: MKAnnotation? {
        didSet { apply(annotation) }
    }

    /// A cluster draws a fixed step larger than a single pin, so "13" does not
    /// read as one spot. `MKMarkerAnnotationView` has no size property, so the
    /// view is scaled, lifted by the growth so the balloon's tip stays on the
    /// coordinate instead of sinking below it.
    static let scale: CGFloat = MarkerMetrics.cluster

    // Applied at both points: `layoutSubviews` alone left reused cluster views
    // at single-pin size on screen, since a dequeued view is not always laid
    // out again before MapKit shows it.
    override func layoutSubviews() {
        super.layoutSubviews()
        applyScale()
    }

    override func prepareForDisplay() {
        super.prepareForDisplay()
        applyScale()
    }

    private func applyScale() {
        let target = MarkerMetrics.transform(for: self, scale: Self.scale)
        if transform != target { transform = target }
    }

    private func apply(_ annotation: MKAnnotation?) {
        guard let cluster = annotation as? MKClusterAnnotation else { return }
        let members = cluster.memberAnnotations.compactMap { $0 as? SiteAnnotation }
        SiteMarkerView.paint(self, tint: UIColor(Self.bestRating(of: members)?.color ?? .gray),
                             outlined: Self.closurePlausible(of: members))
        glyphText = "\(cluster.memberAnnotations.count)"
        isAccessibilityElement = true
        accessibilityLabel = "\(cluster.memberAnnotations.count) fishing spots"
        accessibilityValue = Self.spokenSummary(of: members)
        accessibilityTraits = .button
    }

    static func spokenSummary(of members: [SiteAnnotation]) -> String {
        guard let best = bestRating(of: members) else { return "no seasonal guidance" }
        return closurePlausible(of: members)
            ? "best rated \(best.label), season may be closed, verify with WDFW"
            : "best rated \(best.label)"
    }

    /// Pure, so it is unit-testable without a map: the strongest rating present.
    static func bestRating(of members: [SiteAnnotation]) -> FishingRating? {
        members.compactMap(\.rating).max()
    }

    /// Outlined only when every member carrying the cluster's colour is outlined;
    /// one solid member at that rating is a spot worth going to.
    static func closurePlausible(of members: [SiteAnnotation]) -> Bool {
        let best = bestRating(of: members)
        let leaders = members.filter { $0.rating == best }
        return !leaders.isEmpty && leaders.allSatisfy(\.closurePlausible)
    }
}

/// The "MA n" capsule, rebuilt in UIKit: caption2 semibold on an ultra-thin
/// material pill, matching the SwiftUI annotation it replaces.
final class AreaLabelView: MKAnnotationView {
    private let label = UILabel()
    private let blur = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterial))

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        if #available(iOS 26, *) {
            blur.effect = UIGlassEffect(style: .regular)
        }
        displayPriority = .defaultLow
        collisionMode = .circle
        canShowCallout = false
        blur.clipsToBounds = true
        label.font = .systemFont(ofSize: 11, weight: .semibold)
        label.textColor = .label
        blur.contentView.addSubview(label)
        addSubview(blur)
        apply(annotation)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var annotation: MKAnnotation? {
        didSet { apply(annotation) }
    }

    private func apply(_ annotation: MKAnnotation?) {
        guard let area = annotation as? AreaLabelAnnotation else { return }
        label.text = area.text
        label.sizeToFit()
        let size = CGSize(width: label.bounds.width + 10, height: label.bounds.height + 4)
        label.frame.origin = CGPoint(x: 5, y: 2)
        blur.frame = CGRect(origin: .zero, size: size)
        blur.layer.cornerRadius = size.height / 2
        bounds = CGRect(origin: .zero, size: size)
    }
}
