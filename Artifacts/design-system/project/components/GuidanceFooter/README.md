The "Before you go" block that closes every detail sheet.

Hand-written from `WAFishMap/SiteDetailSheet.swift` (`struct GuidanceFooter`).

A heading, a shield-glyph link to the WDFW rules for that area, the area's own
disclaimer, the fixed line *"Not for navigation or safety decisions."*, and a
"Guidance updated" stamp in `text-tertiary`. `space-12` padding,
`radius-advisory`, on `surface-advisory`.

**Consumer supplies:** the area's fishery guide — its WDFW URL, disclaimer and
updated date. Everything else is fixed copy.

**This block is not optional.** Overlays in this app are geography, not the
rulebook, and every sheet has to say so before the reader leaves it.

**Why neutral, not yellow.** It was a flat `.yellow.opacity(0.12)` wash until
2026-09-20. Yellow is *also* the Fair rating, and both appear on the same sheet,
so a reader had no way to tell a caution from a rating. The shield glyph
(`exclamationmark.shield`) and the heading carry the caution on their own. The
app now fills it with `DS.Surface.advisory` and this preview matches.
