import Foundation

/// Decodes the bundled curated fishing guide. Static, offline data — no network.
enum FisheryLoader {
    static func guide(from data: Data) throws -> FisheryGuide {
        try JSONDecoder().decode(FisheryGuide.self, from: data)
    }
}
