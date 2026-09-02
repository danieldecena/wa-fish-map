import Foundation

enum WDFWLayerError: Error, Equatable {
    case badHTTPStatus(Int)
    case missingBundleResource(String)
    /// The server hit its transfer limit and silently dropped features; treating the
    /// partial layer as complete would be worse than falling back.
    case truncatedResponse
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
        try collection(MarineArea.Properties.self, from: data)
            .features.compactMap(MarineArea.init(feature:))
    }

    static func accessSites(from data: Data) throws -> [AccessSite] {
        try collection(AccessSite.Properties.self, from: data)
            .features.compactMap(AccessSite.init(feature:))
    }

    static func protectedAreas(from data: Data) throws -> [ProtectedArea] {
        try collection(ProtectedArea.Properties.self, from: data)
            .features.compactMap(ProtectedArea.init(feature:))
    }

    static func piers(from data: Data) throws -> [FishingPier] {
        try collection(FishingPier.Properties.self, from: data)
            .features.compactMap(FishingPier.init(feature:))
    }

    /// Decodes a layer response, refusing truncated ones — a silently partial layer
    /// would render as complete.
    private static func collection<P: Decodable>(
        _ properties: P.Type, from data: Data
    ) throws -> GeoJSONFeatureCollection<P> {
        let collection = try JSONDecoder().decode(GeoJSONFeatureCollection<P>.self, from: data)
        guard !collection.isTruncated else { throw WDFWLayerError.truncatedResponse }
        return collection
    }
}
