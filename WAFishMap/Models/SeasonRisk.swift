import Foundation

/// One curated "this fishery's season moves" flag, matched to species by name.
///
/// Deliberately coarse: it marks months in which a closure is *plausible* so the
/// rating can stop short of Prime. It is not a season date and must never be
/// presented as one.
struct SeasonRisk: Decodable, Equatable, Sendable {
    /// Case-insensitive substring tested against `SpeciesSeason.species`, so one
    /// row covers "Chinook Salmon", "(ocean)", "(Tulalip)" and "Resident Chinook".
    let match: String
    /// Months 1–12 in which a closure is plausible.
    let months: [Int]
    /// Short phrase shown to the user. Says why to verify, never a date.
    let reason: String

    func matches(_ speciesName: String) -> Bool {
        speciesName.range(of: match, options: .caseInsensitive) != nil
    }
}
