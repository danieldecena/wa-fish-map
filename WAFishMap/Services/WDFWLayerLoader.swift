import Foundation

enum WDFWLayerError: Error, Equatable {
    case badHTTPStatus(Int)
    case missingBundleResource(String)
    /// ArcGIS answers a malformed `where=` with HTTP 200 and an error body.
    /// Verified 2026-08-18: `where=BogusField IN ('13')` -> 200 + code 400.
    case serviceError(code: Int, message: String)
    case emptyResult(String)
}

/// Without this the 200-with-an-error-body case is indistinguishable from having
/// no network, and `MapScope` is the one file this plan tells the next session to edit.
private struct ArcGISErrorEnvelope: Decodable {
    struct Payload: Decodable { let code: Int; let message: String }
    let error: Payload
}

enum WDFWLayerLoader {
    static func rejectingServiceError(_ data: Data) throws -> Data {
        if let envelope = try? JSONDecoder().decode(ArcGISErrorEnvelope.self, from: data) {
            throw WDFWLayerError.serviceError(
                code: envelope.error.code,
                message: envelope.error.message
            )
        }
        return data
    }

    static func marineAreas(from data: Data) throws -> [MarineArea] {
        let collection = try JSONDecoder().decode(
            GeoJSONFeatureCollection<MarineArea.Properties>.self,
            from: try rejectingServiceError(data)
        )
        return collection.features.compactMap(MarineArea.init(feature:))
    }

    static func accessSites(from data: Data) throws -> [AccessSite] {
        let collection = try JSONDecoder().decode(
            GeoJSONFeatureCollection<AccessSite.Properties>.self,
            from: try rejectingServiceError(data)
        )
        return collection.features.compactMap(AccessSite.init(feature:))
    }
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
