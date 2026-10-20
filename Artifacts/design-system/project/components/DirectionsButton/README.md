The one full-width action on a site sheet: driving directions in Apple Maps.

Hand-written from `WAFishMap/SiteDetailSheet.swift` (`struct DirectionsButton`).

A bordered-prominent button with a `car.fill` glyph, stretched to the sheet's
full width because it is the only thing on the sheet a person taps to act. It
opens a `maps.apple.com` link rather than an `MKMapItem` — the coordinate
initializer is iOS 26 only and the placemark one is deprecated there, while the
app targets iOS 18.

**Consumer supplies:** the spot's name and coordinate.

**Glyphs.** `car.fill` on the button, `exclamationmark.shield` on the WDFW link.
The preview draws stand-ins; the symbol names are the contract.

One primary action per sheet. Anything else — the WDFW link, an MPA detail
link — is a plain text link at the `supporting` role, not a second button.
