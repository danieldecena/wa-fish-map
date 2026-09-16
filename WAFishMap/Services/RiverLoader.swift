import Foundation

/// Decodes the bundled river geometry. Static, offline data — no network, and so
/// no `exceededTransferLimit` guard to run: bundling is what removes that whole
/// failure mode, which is half the reason the geometry is not fetched.
enum RiverLoader {
    static func rivers(from data: Data) throws -> [River] {
        try JSONDecoder()
            .decode(GeoJSONFeatureCollection<River.Properties>.self, from: data)
            .features
            .compactMap(River.init(feature:))
    }
}
