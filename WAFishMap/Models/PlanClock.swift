import Foundation

/// The plan-date month/day every detail sheet reads a rating by — Pacific-local
/// regardless of the device's own time zone, honoring the same UI-test seam the
/// map uses. Extracted so the rule (and the seam) live in exactly one place
/// instead of being reimplemented per sheet with `Calendar.current`, which reads
/// the wrong month for a device outside the Pacific zone.
enum PlanClock {
    static func month(for planDate: Date) -> Int {
        UITestSeam.planMonth ?? Calendar.pacific.component(.month, from: planDate)
    }

    static func day(for planDate: Date) -> Int {
        Calendar.pacific.component(.day, from: planDate)
    }

    /// Year for an odd/even-year species (Pink Salmon), same Pacific-local rule
    /// as `month`/`day` — a device outside the Pacific zone must not roll the
    /// year over at the wrong instant.
    static func year(for planDate: Date) -> Int {
        UITestSeam.planYear ?? Calendar.pacific.component(.year, from: planDate)
    }
}
