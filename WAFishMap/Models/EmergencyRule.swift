import Foundation

/// One item from WDFW's "Sportfishing Rules Updates" feed
/// (`https://wdfw.wa.gov/fishing/regulations/emergency-rules/rss`).
///
/// The feed is semi-structured, not structured. Every item's description is a
/// run of `<strong>Label:</strong> value` paragraphs, but WDFW writes the
/// labels by hand and they vary: `Location` and `Locations`, `Effective date`
/// and `Effective dates`, and one-off headings like
/// `Location and effective dates` or `Updated effective dates by location`
/// that fuse two fields into one. On 2026-09-20, 11 of 31 items carried no
/// canonical location field and 6 carried no canonical effective-date field.
///
/// So a field this app does not recognise is kept, never dropped: an item with
/// no `Location` is present and flagged, with its real labels in
/// `unrecognizedFields`. A closure the parser cannot classify is still a
/// closure, and losing it is the failure this type exists to prevent.
struct EmergencyRule: Identifiable, Equatable, Sendable {
    /// WDFW's `<guid>`, falling back to the link when absent.
    let id: String
    let title: String
    let link: URL?
    let published: Date?

    /// WDFW's own sentence, verbatim. Present on all 31 items checked.
    let action: String?
    let speciesAffected: String?
    /// Text of a `Location` / `Locations` field, or nil when the item has none
    /// and puts the geography in its title.
    let locationText: String?
    /// Text of an `Effective date` / `Effective dates` field, kept as WDFW's
    /// words. Not parsed into dates: "Immediately through Oct. 31, 2026" and
    /// "until further notice" have no honest `Date` to become.
    let effectiveDatesText: String?

    /// Every label this parser does not recognise, with its text, in feed
    /// order. This is where a fused `Location and effective dates` heading and
    /// its body live, and it is what a later slice reads to resolve geography.
    let unrecognizedFields: [(label: String, text: String)]

    var hasLocationField: Bool { locationText != nil }
    var hasEffectiveDateField: Bool { effectiveDatesText != nil }

    static func == (lhs: EmergencyRule, rhs: EmergencyRule) -> Bool {
        lhs.id == rhs.id && lhs.title == rhs.title && lhs.link == rhs.link
            && lhs.published == rhs.published && lhs.action == rhs.action
            && lhs.speciesAffected == rhs.speciesAffected
            && lhs.locationText == rhs.locationText
            && lhs.effectiveDatesText == rhs.effectiveDatesText
            && lhs.unrecognizedFields.map(\.label) == rhs.unrecognizedFields.map(\.label)
            && lhs.unrecognizedFields.map(\.text) == rhs.unrecognizedFields.map(\.text)
    }
}

enum EmergencyRuleFeedError: Error, Equatable {
    case malformedXML(String)
}

/// Turns the RSS body into `EmergencyRule`s, one per `<item>`, always.
///
/// There is deliberately no path that skips an item. Field recognition can
/// fail — and does, for a third of the feed — but recognition failure lands in
/// `unrecognizedFields`, not in a `continue`.
enum EmergencyRuleFeed {

    static func parse(_ data: Data) throws -> [EmergencyRule] {
        let parser = XMLParser(data: data)
        let sink = ItemSink()
        parser.delegate = sink
        guard parser.parse() else {
            throw EmergencyRuleFeedError.malformedXML(
                parser.parserError?.localizedDescription ?? "unknown XMLParser failure")
        }
        return sink.items.map(rule(from:))
    }

    /// The labels this app reads. Everything else is preserved verbatim rather
    /// than guessed at: `Locations and rules` names a location, but its body is
    /// a location *and* a rule and splitting it here would be the app writing
    /// the regulation in its own words.
    private static let actionLabels: Set<String> = ["action"]
    private static let speciesLabels: Set<String> = ["species affected"]
    private static let locationLabels: Set<String> = ["location", "locations"]
    private static let effectiveLabels: Set<String> = ["effective date", "effective dates"]

    private static func rule(from item: RawItem) -> EmergencyRule {
        var action: String?
        var species: String?
        var location: String?
        var effective: String?
        var unrecognized: [(label: String, text: String)] = []

        for field in fields(inDescription: item.description) {
            let key = field.label.lowercased()
            if actionLabels.contains(key), action == nil { action = field.text }
            else if speciesLabels.contains(key), species == nil { species = field.text }
            else if locationLabels.contains(key), location == nil { location = field.text }
            else if effectiveLabels.contains(key), effective == nil { effective = field.text }
            else { unrecognized.append(field) }
        }

        return EmergencyRule(
            id: item.guid ?? item.link ?? item.title,
            title: item.title,
            link: item.link.flatMap(URL.init(string:)),
            published: item.pubDate.flatMap(rfc822.date(from:)),
            action: action,
            speciesAffected: species,
            locationText: location,
            effectiveDatesText: effective,
            unrecognizedFields: unrecognized)
    }

    /// Splits the item's HTML body at its `<strong>` headings. A field's text
    /// runs from the end of its heading to the start of the next one, so a
    /// heading followed by a `<ul>` of dates keeps the list as its value —
    /// which is how WDFW writes multi-area items.
    static func fields(inDescription html: String) -> [(label: String, text: String)] {
        let headings = headingRanges(in: html)
        var out: [(label: String, text: String)] = []
        for (index, heading) in headings.enumerated() {
            let end = index + 1 < headings.count ? headings[index + 1].range.lowerBound : html.endIndex
            let body = plainText(String(html[heading.range.upperBound..<end]))
            out.append((heading.label, trimLeadingColon(body)))
        }
        return out
    }

    private struct Heading { let label: String; let range: Range<String.Index> }

    private static func headingRanges(in html: String) -> [Heading] {
        var out: [Heading] = []
        var cursor = html.startIndex
        while let open = html.range(of: "<strong>", range: cursor..<html.endIndex),
              let close = html.range(of: "</strong>", range: open.upperBound..<html.endIndex) {
            let label = plainText(String(html[open.upperBound..<close.lowerBound]))
                .trimmingCharacters(in: CharacterSet(charactersIn: ": "))
            // WDFW emits bare `<strong> </strong>` inside body text. An empty
            // heading is not a field boundary; leaving it in would cut a value
            // in half.
            if !label.isEmpty {
                out.append(Heading(label: label, range: open.lowerBound..<close.upperBound))
            }
            cursor = close.upperBound
        }
        return out
    }

    private static func trimLeadingColon(_ s: String) -> String {
        s.drop(while: { $0 == ":" || $0 == " " }).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Tags out, entities in, whitespace collapsed. The descriptions carry
    /// `&nbsp;` and nothing else today; the XML-level escaping is already gone
    /// by the time `XMLParser` hands the body over.
    static func plainText(_ html: String) -> String {
        var text = ""
        var depth = 0
        for character in html {
            if character == "<" { depth += 1 }
            else if character == ">" { if depth > 0 { depth -= 1; text.append(" ") } }
            else if depth == 0 { text.append(character) }
        }
        return decodeEntities(text)
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
    }

    private static func decodeEntities(_ s: String) -> String {
        guard s.contains("&") else { return s }
        var out = s
        for (entity, replacement) in [("&nbsp;", " "), ("&lt;", "<"), ("&gt;", ">"),
                                      ("&quot;", "\""), ("&#39;", "'"), ("&amp;", "&")] {
            out = out.replacingOccurrences(of: entity, with: replacement)
        }
        return out
    }

    private static let rfc822: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
        return f
    }()
}

// MARK: - XML

private struct RawItem {
    var title = ""
    var link: String?
    var guid: String?
    var pubDate: String?
    var description = ""
}

private final class ItemSink: NSObject, XMLParserDelegate {
    var items: [RawItem] = []
    private var current: RawItem?
    private var element = ""
    private var text = ""

    func parser(_ parser: XMLParser, didStartElement name: String, namespaceURI: String?,
                qualifiedName: String?, attributes: [String: String]) {
        element = name
        text = ""
        if name == "item" { current = RawItem() }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) { text += string }

    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
        text += String(decoding: CDATABlock, as: UTF8.self)
    }

    func parser(_ parser: XMLParser, didEndElement name: String, namespaceURI: String?,
                qualifiedName: String?) {
        defer { element = ""; text = "" }
        guard current != nil else { return }
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        switch name {
        case "title": current?.title = value
        case "link": current?.link = value
        case "guid": current?.guid = value
        case "pubDate": current?.pubDate = value
        case "description": current?.description = value
        case "item":
            items.append(current!)
            current = nil
        default: break
        }
    }
}
