import Foundation
import Testing
@testable import WAFishMap

/// The fixture is WDFW's live feed as served on 2026-09-20, byte for byte:
///
///     curl -sS https://wdfw.wa.gov/fishing/regulations/emergency-rules/rss \
///       -o WAFishMap/Resources/emergency-rules.sample.xml
///
/// The feed does not paginate. `?page=N` returns a byte-identical body, there
/// is no `rel="next"`, and the HTML listing page at
/// `/fishing/regulations/emergency-rules` links the same 31 rules and no more.
/// So 31 is the whole list on that date, not one page of it, and asserting the
/// count here is asserting that the parser keeps every rule WDFW published.
struct EmergencyRuleTests {

    static func fixture() throws -> Data {
        let bundle = try #require(FixtureBundle.loader)
        let url = try #require(bundle.url(forResource: "emergency-rules.sample", withExtension: "xml"))
        return try Data(contentsOf: url)
    }

    static func rules() throws -> [EmergencyRule] {
        try EmergencyRuleFeed.parse(fixture())
    }

    // MARK: The count

    /// The guard this slice exists for. A parser change that starts dropping
    /// the items it cannot classify fails here.
    @Test func theFixtureParsesToEveryRuleWDFWPublished() throws {
        #expect(try Self.rules().count == 31)
    }

    /// And 31 is not a number typed from memory: it is the number of `<item>`
    /// elements in the fixture. If the fixture is ever refreshed, these two
    /// assertions disagree in a way that names the cause.
    @Test func theCountMatchesTheItemsInTheFeedItself() throws {
        let raw = String(decoding: try Self.fixture(), as: UTF8.self)
        let items = raw.components(separatedBy: "<item>").count - 1
        #expect(try Self.rules().count == items)
    }

    // MARK: What is missing, and present anyway

    /// 11 items name no `Location` field at all and put the geography in the
    /// title. They are flagged, not dropped.
    @Test func theElevenItemsWithNoLocationFieldComeThroughFlagged() throws {
        let rules = try Self.rules()
        let unlocated = rules.filter { !$0.hasLocationField }

        #expect(unlocated.count == 11)
        #expect(unlocated.allSatisfy { !$0.title.isEmpty })
        #expect(unlocated.allSatisfy { $0.action?.isEmpty == false })
        #expect(unlocated.contains { $0.title.contains("marine areas 8-2 and 9") })
    }

    /// 6 items carry no effective-date field. Same contract.
    @Test func theSixItemsWithNoEffectiveDateFieldComeThroughFlagged() throws {
        let rules = try Self.rules()
        let undated = rules.filter { !$0.hasEffectiveDateField }

        #expect(undated.count == 6)
        #expect(undated.allSatisfy { !$0.title.isEmpty })
        #expect(undated.contains { $0.title.contains("Puget Sound shrimp fishery update") })
    }

    /// The control for the two tests above. A flag that fires on everything
    /// would pass them both; this is the known-good input that separates a
    /// working detector from one that always flags.
    @Test func anItemThatDoesCarryBothFieldsIsNotFlagged() throws {
        let lakeWashington = try #require(
            try Self.rules().first { $0.title == "Lake Washington reopens for salmon fishing" })

        #expect(lakeWashington.hasLocationField)
        #expect(lakeWashington.hasEffectiveDateField)
        #expect(lakeWashington.locationText?.hasPrefix(
            "Lake Washington (King County) north of Highway 520 Bridge") == true)
        #expect(lakeWashington.effectiveDatesText == "Immediately through Oct. 31, 2026.")
    }

    // MARK: Fields the parser does not recognise

    /// WDFW fuses fields into one-off headings. Those are kept verbatim so a
    /// later slice can read the geography out of them, rather than being lost
    /// because they did not match a known label.
    @Test func anUnrecognisedHeadingIsKeptRatherThanDiscarded() throws {
        let fused = try #require(
            try Self.rules().first { $0.title.contains("marine areas 8-2 and 9") })

        #expect(!fused.hasLocationField)
        #expect(!fused.hasEffectiveDateField)
        let labels = fused.unrecognizedFields.map(\.label)
        #expect(labels.contains("Location and effective dates"))

        let fusedText = try #require(
            fused.unrecognizedFields.first { $0.label == "Location and effective dates" }?.text)
        #expect(fusedText.contains("Marine Area 8-2 (Port Susan and Port Gardner)"))
        #expect(fusedText.contains("Marine Area 9 (Admiralty Inlet)"))
    }

    // MARK: The fields that are always there

    @Test func everyRuleCarriesAnActionAndTheSpeciesAffected() throws {
        let rules = try Self.rules()
        #expect(rules.allSatisfy { $0.action?.isEmpty == false })
        #expect(rules.allSatisfy { $0.speciesAffected?.isEmpty == false })
    }

    @Test func everyRuleCarriesAnIdentityALinkAndAPublishedDate() throws {
        let rules = try Self.rules()
        #expect(rules.allSatisfy { !$0.id.isEmpty })
        #expect(Set(rules.map(\.id)).count == rules.count)
        #expect(rules.allSatisfy { $0.link?.host() == "wdfw.wa.gov" })
        #expect(rules.allSatisfy { $0.published != nil })
    }

    @Test func theNewestRuleIsTheOneAtTheTopOfTheFeed() throws {
        let first = try #require(try Self.rules().first)
        #expect(first.title == "Puget Sound marine areas 8-2 and 9 salmon fishing update")
        #expect(first.action == "Reduces the salmon daily limit to one effective Monday, Sept. 21.")
        #expect(first.speciesAffected == "Salmon.")

        // Fri, 18 Sep 2026 14:43:15 -0700
        let published = try #require(first.published)
        #expect(abs(published.timeIntervalSince1970 - 1_789_767_795) < 1)
    }

    // MARK: Failure renders as failure

    @Test func aBodyThatIsNotXMLThrowsRatherThanParsingToNothing() {
        #expect(throws: EmergencyRuleFeedError.self) {
            try EmergencyRuleFeed.parse(Data("<rss><channel><item>".utf8))
        }
    }

    @Test func aFeedWithNoItemsParsesToNoRulesRatherThanThrowing() throws {
        let empty = Data("""
        <?xml version="1.0" encoding="utf-8"?>
        <rss version="2.0"><channel><title>x</title></channel></rss>
        """.utf8)
        #expect(try EmergencyRuleFeed.parse(empty).isEmpty)
    }

    // MARK: Segmentation

    @Test func aHeadingFollowedByAListKeepsTheListAsItsValue() {
        let fields = EmergencyRuleFeed.fields(inDescription:
            "<p><strong>Location:</strong></p><ul><li>Marine Area 9</li><li>Marine Area 10</li></ul>"
            + "<p><strong>Action:</strong> Closes.</p>")

        #expect(fields.count == 2)
        #expect(fields[0].label == "Location")
        #expect(fields[0].text == "Marine Area 9 Marine Area 10")
        #expect(fields[1].label == "Action")
        #expect(fields[1].text == "Closes.")
    }

    /// WDFW emits bare `<strong> </strong>` inside body text. Treating it as a
    /// heading would cut the value it sits in half.
    @Test func anEmptyBoldRunIsNotAFieldBoundary() {
        let fields = EmergencyRuleFeed.fields(inDescription:
            "<p><strong>Action:</strong> Closes the fishery<strong> </strong>on Sept. 21.</p>")

        #expect(fields.count == 1)
        #expect(fields[0].text == "Closes the fishery on Sept. 21.")
    }
}
