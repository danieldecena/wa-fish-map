import Foundation

enum WDFWLayerError: Error, Equatable {
    case badHTTPStatus(Int)
    case missingBundleResource(String)
}

protocol HTTPGet: Sendable {
    func data(from url: URL) async throws -> Data
}

struct URLSessionHTTPGet: HTTPGet {
    func data(from url: URL) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(from: url)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200...299).contains(status) else { throw WDFWLayerError.badHTTPStatus(status) }
        return data
    }
}

enum WDFWLayerLoader {
    static func marineAreas(from data: Data) throws -> [MarineArea] {
        let collection = try JSONDecoder().decode(
            GeoJSONFeatureCollection<MarineArea.Properties>.self,
            from: data
        )
        return collection.features.compactMap(MarineArea.init(feature:))
    }

    static func accessSites(from data: Data) throws -> [AccessSite] {
        let collection = try JSONDecoder().decode(
            GeoJSONFeatureCollection<AccessSite.Properties>.self,
            from: data
        )
        return collection.features.compactMap(AccessSite.init(feature:))
    }
}
