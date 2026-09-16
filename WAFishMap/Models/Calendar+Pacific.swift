import Foundation

extension Calendar {
    /// The app's fishing data (tides, daylight, plan date) is all Pacific-local
    /// regardless of the device's own time zone — a trip planned from out of
    /// state must still key off the WA day, not the machine's.
    static let pacific: Calendar = {
        var c = Calendar.current
        c.timeZone = TimeZone(identifier: "America/Los_Angeles") ?? .current
        return c
    }()
}
