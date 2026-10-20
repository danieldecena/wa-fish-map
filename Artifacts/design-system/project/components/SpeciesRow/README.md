One species card inside "What's biting" — the densest block in the app.

Hand-written from `WAFishMap/SiteDetailSheet.swift` (`struct BitingNowView`).

A `RatingBadge`, the species name at the `itemTitle` role, and — where a typical
size is known — a `FishSilhouette` with its range beneath it, right-aligned in a
fixed 56×36 box so the names stay in a column. Under that, only the lines that
have something to say: a "Season varies — verify" caution, best months, best
time, the reason behind the caution, bait, and a free note. All of them at
`meta` or `fineprint` in `text-secondary`.

The card is `space-10` padding on `surface-species-row` at
`radius-species-row`.

**Consumer supplies:** the species season for the picked month.

**Glyphs.** Each detail line is a `Label` with an SF Symbol: `calendar` for best
months, `clock` for best time, `fish` for bait, `exclamationmark.triangle` for
the season caution. The preview draws stand-ins for these at the same optical
weight — SF Pro's symbol set is not on the web, so treat the shapes as
placeholders and the names as the contract.

The silhouettes are body plans, not species — ten forms cover every finfish in
the guide, so a salmon and a halibut read differently at a glance.
