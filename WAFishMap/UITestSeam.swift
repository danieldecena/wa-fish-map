import Foundation

/// The two launch arguments a UI test may set, and nothing else.
///
/// The verify badge was shipped "proven by tests and by reading the diff, not by
/// observation" because there was no way to assert anything on screen. Observing
/// it needs the app to be deterministic at launch: real WDFW data arrives in an
/// arbitrary order and the badge only renders for a species flagged in the month
/// being planned, so a test driving the live app would be asserting against a
/// moving target.
///
/// `-uiTesting` loads the bundled fixture instead of the network and preselects
/// the first site, so the detail sheet is up without synthesising a tap.
/// `-planMonth n` pins the month the ratings are computed for.
///
/// Deliberately not a general test harness: two arguments, read in two places.
enum UITestSeam {
    static var isActive: Bool {
        ProcessInfo.processInfo.arguments.contains("-uiTesting")
    }

    /// Month 1–12 from `-planMonth n`, or `nil` when unset or out of range.
    /// An out-of-range value reads as unset rather than clamping, so a typo in a
    /// test fails on the assertion instead of quietly planning for a month the
    /// test did not ask for.
    static var planMonth: Int? {
        let args = ProcessInfo.processInfo.arguments
        guard let flag = args.firstIndex(of: "-planMonth"),
              let month = Int(args[safe: flag + 1] ?? ""),
              (1...12).contains(month)
        else { return nil }
        return month
    }

    static func planYear(from args: [String]) -> Int? {
        nil
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
