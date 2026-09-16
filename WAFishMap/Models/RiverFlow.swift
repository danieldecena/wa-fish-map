import Foundation

/// One gauge's latest reading. Discharge and water temperature are separate
/// series on the same gauge and arrive with their own timestamps, so they are
/// kept apart rather than folded into one "as of" — a gauge can report flow
/// every 15 minutes and temperature hourly, and pretending otherwise would
/// date one of them wrongly.
struct RiverFlow: Equatable, Sendable {
    let gauge: String
    let gaugeName: String
    /// Cubic feet per second.
    let discharge: Double?
    let dischargeAt: Date?
    /// Degrees Celsius, as USGS reports it.
    let waterTempC: Double?
    let waterTempAt: Date?

    var waterTempF: Double? {
        waterTempC.map { $0 * 9 / 5 + 32 }
    }
}

/// The USGS instantaneous-values payload. Only the fields the app reads are
/// declared; the response carries a great deal more.
struct USGSInstantaneousValues: Decodable {
    let value: Body

    struct Body: Decodable {
        let timeSeries: [Series]
    }

    struct Series: Decodable {
        let sourceInfo: SourceInfo
        let variable: Variable
        let values: [ValueBlock]
    }

    struct SourceInfo: Decodable {
        let siteName: String
        let siteCode: [Code]
    }

    struct Code: Decodable {
        let value: String
    }

    struct Variable: Decodable {
        let variableCode: [Code]
    }

    struct ValueBlock: Decodable {
        let value: [Sample]
    }

    struct Sample: Decodable {
        let value: String
        let dateTime: String
    }
}
