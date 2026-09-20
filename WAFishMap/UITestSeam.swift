import Foundation

/// The three launch arguments a UI test may set, and nothing else.
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
/// `-uiTestingDetail site|pier|river` picks which detail sheet opens instead of
/// the site sheet. Added so "every sheet carries the disclaimer and a WDFW link"
/// can be observed on all three sheets: tapping pins on a clustered map is the
/// moving target this seam exists to avoid.
///
/// `-uiTestingRegion lat,lon,span` pins the camera so a map frame is the
/// same frame every run.
///
/// Deliberately not a general test harness: four arguments.
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

    enum Detail: String {
        case site, pier, river
    }

    /// A pinned camera from `-uiTestingRegion lat,lon,span`, or `nil`.
    ///
    /// The fourth argument, and it earned its place the same way the other
    /// three did. The regional map frames itself from the first location fix,
    /// so two screenshot runs twenty minutes apart produced different regions
    /// and different zooms and could not be compared. A gate that reads "the
    /// ratings separate at arm's length" cannot run on a frame that is a
    /// different frame every time.
    ///
    /// Returned as plain numbers so this file stays Foundation-only. Out of
    /// range reads as unset, the same rule as `planMonth`: a typo must not
    /// quietly frame somewhere the caller did not ask for.
    static var region: (latitude: Double, longitude: Double, span: Double)? {
        let args = ProcessInfo.processInfo.arguments
        guard let flag = args.firstIndex(of: "-uiTestingRegion"),
              let raw = args[safe: flag + 1] else { return nil }
        let parts = raw.split(separator: ",").compactMap { Double($0) }
        guard parts.count == 3,
              (-90...90).contains(parts[0]), (-180...180).contains(parts[1]),
              parts[2] > 0, parts[2] <= 90
        else { return nil }
        return (parts[0], parts[1], parts[2])
    }

    /// The sheet from `-uiTestingDetail`, or `nil` when unset or unrecognised,
    /// which reads as the site sheet. Same rule as `planMonth`: a typo is not
    /// quietly mapped to a sheet the test did not ask for.
    static var detail: Detail? {
        let args = ProcessInfo.processInfo.arguments
        guard let flag = args.firstIndex(of: "-uiTestingDetail") else { return nil }
        return args[safe: flag + 1].flatMap(Detail.init(rawValue:))
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
