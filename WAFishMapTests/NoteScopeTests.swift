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
    nonisolated(unsafe) static let waterbodyPattern = /\b([A-Z][a-z]+)\s+(Lake|River|Bay|Sound|Creek|Reservoir|Woods)\b|\b(Lake|Mount)\s+[A-Z][a-z]+/

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

    /// The waterbody tier is exempt for the same reason the area tier is: the
    /// row IS a place, so "Baker Lake sockeye run on a WDFW quota" attached to
    /// Baker Lake is true everywhere it renders. The exemption is sound only
    /// because the tier is keyed by a curated facility list rather than by
    /// prose-matching a name — that guess is the failure this suite exists for.
    /// A key is either a curated facility list or an exact river name from
    /// rivers.json, never a substring match.
    ///
    /// What is asserted instead: every waterbody row must name a waterbody the
    /// guide can actually resolve a site to, or the note is unreachable and the
    /// tier quietly does nothing.
    @Test func everyWaterbodyRowIsReachable() throws {
        let freshwater = try #require(bundledGuide().freshwater)
        let bundle = try #require(FixtureBundle.loader)
        let url = try #require(bundle.url(forResource: "rivers", withExtension: "json"))
        let names = Set(try RiverLoader.rivers(from: Data(contentsOf: url)).map(\.name))
        #expect(names.count > 200, "rivers.json did not load; the gate would pass vacuously")
        let orphans = Self.unreachableWaterbodyKeys(in: freshwater, riverNames: names)
        #expect(orphans.isEmpty, "waterbody notes no site can reach: \(orphans.joined(separator: ", "))")
    }

    static func unreachableWaterbodyKeys(in freshwater: FreshwaterGuide, riverNames: Set<String>) -> [String] {
        let keyed = Set(freshwater.waterbodySites?.keys ?? [:].keys).union(riverNames)
        return (freshwater.byWaterbody ?? [:]).keys.filter { !keyed.contains($0) }.sorted()
    }

    /// Proves the gate fires: a misspelled river is unreachable, a real one is not.
    @Test func theReachabilityGateCatchesAMisspelledRiver() {
        let row = SpeciesSeason(species: "Redband Trout", bestMonths: [8])
        let guide = FreshwaterGuide(species: [], byWaterbody: ["Spokane River": [row], "Spokan River": [row]])
        #expect(Self.unreachableWaterbodyKeys(in: guide, riverNames: ["Spokane River"]) == ["Spokan River"])
    }

    /// The season cap must reach the new tier. A tier the resolver skips lets a
    /// closure-prone fishery render Prime, which is the whole defect the cap
    /// exists to prevent.
    @Test func waterbodyRowsAreStampedWithSeasonRisk() throws {
        let guide = try bundledGuide()
        let sockeye = guide.freshwater?.byWaterbody?["Baker Lake"]?
            .first { $0.species == "Sockeye Salmon" }
        let expected = guide.seasonRisk.first { $0.matches("Sockeye Salmon") }
        #expect(try #require(sockeye).riskMonths == expected?.months ?? [],
                "Baker Lake sockeye did not pick up the seasonRisk stamp.")
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
