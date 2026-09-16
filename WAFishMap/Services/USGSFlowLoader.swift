import Foundation

/// Live river conditions from USGS Water Services. One call returns every
/// active Washington gauge's latest discharge and water temperature, so this
/// is a single request rather than one per river.
///
/// Free and keyless, like the NOAA tide and NDBC buoy loaders it sits beside.
enum USGSFlowLoader {
    static let discharge = "00060"
    static let waterTemp = "00010"

    static var url: URL {
        var components = URLComponents(
            string: "https://waterservices.usgs.gov/nwis/iv/"
        )!
        components.queryItems = [
            URLQueryItem(name: "format", value: "json"),
            URLQueryItem(name: "stateCd", value: "wa"),
            URLQueryItem(name: "parameterCd", value: "\(discharge),\(waterTemp)"),
            URLQueryItem(name: "siteStatus", value: "active"),
        ]
        return components.url!
    }

    /// Keyed by gauge id, so a river finds its reading through the gauge its
    /// bundled history names.
    static func flows(from data: Data) throws -> [String: RiverFlow] {
        let payload = try JSONDecoder().decode(USGSInstantaneousValues.self, from: data)

        struct Partial {
            var name = ""
            var discharge: Double?
            var dischargeAt: Date?
            var tempC: Double?
            var tempAt: Date?
        }
        var partials: [String: Partial] = [:]

        for series in payload.value.timeSeries {
            guard let gauge = series.sourceInfo.siteCode.first?.value,
                  let parameter = series.variable.variableCode.first?.value,
                  let sample = series.values.compactMap(\.value.last).last else { continue }
            // USGS marks a gauge that is offline or ice-affected with a sentinel
            // rather than omitting it. Reading -999999 as a discharge would put
            // every such river at the bottom of its own distribution and paint
            // it Slow, which is a fabricated observation, not a missing one.
            guard let reading = Double(sample.value), reading > -1000 else { continue }
            let at = ISO8601DateFormatter.usgs.date(from: sample.dateTime)

            var partial = partials[gauge] ?? Partial()
            partial.name = series.sourceInfo.siteName
            switch parameter {
            case discharge:
                partial.discharge = reading
                partial.dischargeAt = at
            case waterTemp:
                partial.tempC = reading
                partial.tempAt = at
            default:
                break
            }
            partials[gauge] = partial
        }

        return partials.reduce(into: [:]) { result, entry in
            let (gauge, partial) = entry
            result[gauge] = RiverFlow(
                gauge: gauge,
                gaugeName: partial.name,
                discharge: partial.discharge,
                dischargeAt: partial.dischargeAt,
                waterTempC: partial.tempC,
                waterTempAt: partial.tempAt
            )
        }
    }
}

private extension ISO8601DateFormatter {
    /// USGS stamps its samples with a numeric offset and fractional seconds
    /// ("2026-09-03T20:30:00.000-07:00"), which the default configuration rejects.
    /// `nonisolated(unsafe)`: configured once here and only read after, and
    /// ISO8601DateFormatter is documented as thread-safe.
    nonisolated(unsafe) static let usgs: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}
