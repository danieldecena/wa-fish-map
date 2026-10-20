# Logos

The app icon and its two source shapes, exactly as they ship in
`WAFishMap/WAFishMap.icon/` and `icon/`.

The mark is a white fish — `icon-body.svg` (body, with the eye cut out by
even-odd fill) and `icon-tail.svg` (a plain triangle) — composed as two layers
over a vertical linear gradient from `brand-icon-start` to `brand-icon-end`.
Both SVGs are drawn white on a 1024 box; the icon's `icon.json` supplies the
fill, so the files carry no colour of their own.

Use `app-icon.png` wherever a rendered icon is needed (listings, docs, a
favicon). Compose the two SVGs only when rebuilding the icon itself — the layer
order is tail, then body.

Do not put the gradient behind anything else. It is the icon's, not the
product's.
