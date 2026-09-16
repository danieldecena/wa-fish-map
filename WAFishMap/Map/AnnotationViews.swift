import MapKit
import SwiftUI

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

    /// A boat for a launch, an angler for a shore-only site, a fish for a pier;
    /// tint is the rating colour, neutral gray when unrated. `anchor.fill` (the
    /// original SwiftUI `Marker` glyph) is not a real SF Symbol — it resolves to
    /// nil and MapKit silently falls back to a default pin.
    private func apply(_ annotation: MKAnnotation?) {
        guard let site = annotation as? SiteAnnotation else { return }
        Self.paint(self, tint: UIColor(site.rating?.color ?? .gray), outlined: site.closurePlausible)
        glyphImage = UIImage(systemName: Self.symbol(for: site.kind))
    }

    /// Outlined = a pale balloon with the rating colour moved to the glyph, so a
    /// "season may be closed, verify" spot keeps its colour and its tap target.
    /// Both branches set both tints: views are reused across annotations.
    static func paint(_ view: MKMarkerAnnotationView, tint: UIColor, outlined: Bool) {
        view.markerTintColor = outlined ? .systemBackground : tint
        view.glyphTintColor = outlined ? tint : .white
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

    private func apply(_ annotation: MKAnnotation?) {
        guard let cluster = annotation as? MKClusterAnnotation else { return }
        let members = cluster.memberAnnotations.compactMap { $0 as? SiteAnnotation }
        SiteMarkerView.paint(self, tint: UIColor(Self.bestRating(of: members)?.color ?? .gray),
                             outlined: Self.closurePlausible(of: members))
        glyphText = "\(cluster.memberAnnotations.count)"
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
