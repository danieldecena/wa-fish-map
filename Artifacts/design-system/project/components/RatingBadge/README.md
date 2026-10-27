A small capsule that states a rating in words and in colour at the same time.

Hand-written from `WAFishMap/SiteDetailSheet.swift` (`struct RatingBadge`).

The label is the rating's own word — Prime, Good, Fair, Slow — or "No data" when
there is no curated season for the spot's area. The colour is the ramp token for
that rating: the background at `badge-fill` (20%) and a 1px stroke at full
strength around a `radius-pill` capsule. The label is `text-primary`, not the
rating colour.

`ClosedBadge` on a pier sheet is built the same way: an
`xmark.octagon.fill` and the word "Closed" in primary ink on a 20%
`rating-unrated` wash with a gray stroke (white on solid gray measured about
3.3:1).

**Consumer supplies:** the rating (or nothing, for "No data"). Nothing else.

**Use it** wherever a rating is named on a sheet — beside a species, at the head
of a site card. **Do not** use it for any other kind of status; the ramp means
one thing in this product.

**Contrast:** the label used to be the rating colour on its own wash, which
put both sides of the ratio on the same slider and failed 4.5:1 in light for
every state (Fair 1.38:1). Primary ink fixed it; `RatingBadgeContrastTests`
holds the numbers.
