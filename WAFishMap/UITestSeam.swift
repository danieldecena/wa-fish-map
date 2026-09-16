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
/// `-planMonth n` pins the month the ratings are computed for, and `-planYear n`
/// the year (odd-year species rate by it).
///
/// Deliberately not a general test harness: three arguments, read in few places.
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

    /// Year from `-planYear n`, or `nil` when unset or not a number, so a test
    /// that pins `-planMonth` can pin the year an odd-year species rates by.
    static var planYear: Int? {
        planYear(from: ProcessInfo.processInfo.arguments)
    }

    static func planYear(from args: [String]) -> Int? {
        guard let flag = args.firstIndex(of: "-planYear") else { return nil }
        return Int(args[safe: flag + 1] ?? "")
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
