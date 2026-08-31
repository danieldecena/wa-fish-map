import Foundation

/// Coarse time-of-day bucket used for a "best light" fishing hint. We don't have
/// hour-resolved species data, so this drives an informational hint only — the month
/// (from the selected date) is what actually changes the ratings on the map.
enum TimeOfDay: String, Sendable, Equatable {
    case dawn, day, dusk, night

    init(hour: Int) {
        switch hour {
        case 4..<8: self = .dawn
        case 8..<17: self = .day
        case 17..<21: self = .dusk
        default: self = .night
        }
    }

    /// Classifies against real sun times: dawn/dusk are the hour either side of
    /// sunrise/sunset, matching the low-light bite window the hint describes.
    init(date: Date, solar: SolarTimes) {
        let window: TimeInterval = 3600
        if abs(date.timeIntervalSince(solar.sunrise)) <= window {
            self = .dawn
        } else if abs(date.timeIntervalSince(solar.sunset)) <= window {
            self = .dusk
        } else if solar.sunrise < date, date < solar.sunset {
            self = .day
        } else {
            self = .night
        }
    }

    var label: String {
        switch self {
        case .dawn: "Dawn"
        case .day: "Midday"
        case .dusk: "Dusk"
        case .night: "Night"
        }
    }

    var symbol: String {
        switch self {
        case .dawn: "sunrise"
        case .day: "sun.max"
        case .dusk: "sunset"
        case .night: "moon.stars"
        }
    }

    var isPrimeLight: Bool { self == .dawn || self == .dusk }

    var lightHint: String {
        switch self {
        case .dawn, .dusk: "Prime light — low-light bite"
        case .day: "Bright — bite often slows midday"
        case .night: "Night — some species feed after dark"
        }
    }
}
