import Foundation

/// An NDBC buoy, from the bundled catalog. Same shape as `TideStation`: a static
/// list picked at build time, not a runtime catalog fetch.
struct BuoyStation: Decodable, Equatable, Sendable, Identifiable {
    let id: String
    let name: String
    let lat: Double
    let lon: Double

    var coordinate: LonLat { LonLat(longitude: lon, latitude: lat) }
}

/// The two numbers this app asks a buoy for. Depth is deliberately absent — a
/// buoy's own depth says nothing about where an angler is standing.
///
/// Each value carries its own timestamp because the feed reports them
/// independently: the newest row of station 46088 has a wave height and `MM` for
/// water temperature, with the real temperature one row older. Collapsing that
/// into a single "latest observation" would either drop the temperature or
/// silently date it to the wrong minute.
struct BuoyObservation: Equatable, Sendable {
    struct Reading<Value: Equatable & Sendable>: Equatable, Sendable {
        let value: Value
        let observed: Date
    }

    let stationID: String
    let waveHeightMeters: Reading<Double>?
    let waterTempCelsius: Reading<Double>?

    /// True when the station reported neither number. Rendered as "no reading",
    /// never as calm water at ambient temperature.
    var isEmpty: Bool { waveHeightMeters == nil && waterTempCelsius == nil }
}
