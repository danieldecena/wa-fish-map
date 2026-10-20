A small capsule that states a rating in words and in colour at the same time.

Hand-written from `WAFishMap/SiteDetailSheet.swift` (`struct RatingBadge`).

The label is the rating's own word — Prime, Good, Fair, Slow — or "No data" when
there is no curated season for the spot's area. The colour is the ramp token for
that rating: the text at full strength, the background the same colour at
`badge-fill` (20%), and a 1px stroke of it around a `radius-pill` capsule.

**Consumer supplies:** the rating (or nothing, for "No data"). Nothing else.

**Use it** wherever a rating is named on a sheet — beside a species, at the head
of a site card. **Do not** use it for any other kind of status; the ramp means
one thing in this product.

**Contrast:** Fair on its own 20% wash does not reach 4.5:1. Carried from the
source unchanged; flagged in the README's accessibility notes as the first pair
to fix.
