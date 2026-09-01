import Foundation
import Testing
@testable import WAFishMap

/// A note attached to the statewide or county tier is shown at every site in
/// that scope. Naming one waterbody there is a claim about a place the reader
/// is not standing in: the King County Yellow Perch note read "Lake Washington;
/// huge population" and rendered at Lake Dolloff in Federal Way, twenty miles
/// away, on 2026-09-01.
///
/// The area tier is deliberately exempt. A WDFW marine area IS a place, so
/// "Elliott Bay / Central Sound spring selective fishery" on area 10 is correct.
struct NoteScopeTests {

    /// A proper noun immediately followed by a waterbody word. Matches
    /// "Lake Washington", "Green River", and "Rufus Woods"; does not match the
    /// generic "Lowland lakes" or "warm-water bite", which are true anywhere.
    /// "Potholes" cannot be prose-matched — that one is on the data editor.
    static let waterbodyPattern = /\b([A-Z][a-z]+)\s+(Lake|River|Bay|Sound|Creek|Reservoir|Woods)\b|\b(Lake|Mount)\s+[A-Z][a-z]+/

    private func offenders(in species: [SpeciesSeason], scope: String) -> [String] {
        species.compactMap { s in
            guard let note = s.note,
                  note.firstMatch(of: Self.waterbodyPattern) != nil else { return nil }
            return "\(scope) / \(s.species): \(note)"
        }
    }

    private func bundledGuide() throws -> FisheryGuide {
        let bundle = try #require(FixtureBundle.loader)
        let url = try #require(bundle.url(forResource: "fisheries", withExtension: "json"))
        return try FisheryLoader.guide(from: Data(contentsOf: url))
    }

    @Test func statewideNotesNameNoWaterbody() throws {
        let freshwater = try #require(bundledGuide().freshwater)
        let bad = offenders(in: freshwater.species, scope: "statewide")
        #expect(bad.isEmpty, "statewide notes must hold anywhere in WA:\n\(bad.joined(separator: "\n"))")
    }

    @Test func countyNotesNameNoWaterbody() throws {
        let freshwater = try #require(bundledGuide().freshwater)
        var bad: [String] = []
        for (county, species) in (freshwater.byCounty ?? [:]).sorted(by: { $0.key < $1.key }) {
            bad += offenders(in: species, scope: county)
        }
        #expect(bad.isEmpty, "county notes must hold anywhere in the county:\n\(bad.joined(separator: "\n"))")
    }

    /// Proves the pattern fires, so a passing suite means the data is clean
    /// rather than the regex being broken.
    @Test func patternCatchesAWaterbodyAndSparesGenericProse() {
        #expect("Lake Washington; huge population".firstMatch(of: Self.waterbodyPattern) != nil)
        #expect("Green River hatchery run".firstMatch(of: Self.waterbodyPattern) != nil)
        #expect("Rufus Woods; trophy triploids".firstMatch(of: Self.waterbodyPattern) != nil)
        #expect("Lowland lakes; many open year-round.".firstMatch(of: Self.waterbodyPattern) == nil)
        #expect("Warm-water bite late spring through summer.".firstMatch(of: Self.waterbodyPattern) == nil)
    }
}
