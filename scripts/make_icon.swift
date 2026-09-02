// Draws the app mark once and emits both forms of it:
//
//     swift scripts/make_icon.swift
//
//   icon/icon_1024.png        the flat mark, outside the app target
//   WAFishMap/WAFishMap.icon  the layered bundle the build actually consumes
//
// One set of constants and one set of CGPaths feed both, so they cannot drift.
// CoreGraphics rather than an SVG pipeline because this Mac has no rasterizer
// (rsvg/inkscape/magick/cairosvg are all absent) but the Xcode toolchain is
// already a hard requirement for the project, so /usr/bin/swift always works.
//
// The mark is drawn in its own coordinate space centred on (0,0) and placed by
// one transform, so the composition is fixed by construction. Nothing is
// written until the checks pass: the raster is asserted against its own bitmap,
// and the SVGs are read back and rasterised so what is asserted is what a
// renderer draws.
//
// To see what the layered bundle looks like in any appearance (Default, Dark,
// TintedLight, TintedDark, ClearLight, ClearDark):
//
//     "/Applications/Xcode-beta.app/Contents/Applications/Icon Composer.app/Contents/Executables/ictool" \
//       WAFishMap/WAFishMap.icon --export-image --output-file /tmp/icon.png \
//       --platform iOS --rendition Default --width 1024 --height 1024 --scale 1
//
// Note that is *not* the ictool shim in Developer/usr/bin, which rejects these
// arguments.

import AppKit
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

// MARK: - Tunables

let canvas = 1024.0

let gradientTop = (r: 0x17 / 255.0, g: 0x97 / 255.0, b: 0xAE / 255.0)
let gradientBottom = (r: 0x00 / 255.0, g: 0x4A / 255.0, b: 0x79 / 255.0)
let eyeColor = (r: 0x05 / 255.0, g: 0x53 / 255.0, b: 0x7E / 255.0)

let bodyLength = 600.0   // nose to peduncle
let bodyHeight = 115.0   // half-height at the widest point
let tailLength = 175.0   // behind the peduncle
let tailSpread = 150.0   // half-height of the trailing edge
let tailOverlap = 145.0  // how far the tail's apex sits *inside* the body
let eyeX = 190.0
let eyeY = 10.0
let eyeRadius = 34.0
let markWidthFraction = 0.62

// MARK: - Mark geometry

let noseX = bodyLength / 2
let peduncleX = -bodyLength / 2

// The body is two mirrored cubics. Control points at 4/3 the half-height put
// the curve's extreme exactly at ±bodyHeight.
let bodyPath: CGPath = {
    let p = CGMutablePath()
    let c = bodyHeight * 4 / 3
    p.move(to: CGPoint(x: peduncleX, y: 0))
    p.addCurve(to: CGPoint(x: noseX, y: 0),
               control1: CGPoint(x: peduncleX / 3, y: c),
               control2: CGPoint(x: noseX / 3, y: c))
    p.addCurve(to: CGPoint(x: peduncleX, y: 0),
               control1: CGPoint(x: noseX / 3, y: -c),
               control2: CGPoint(x: peduncleX / 3, y: -c))
    p.closeSubpath()
    return p
}()

let tailApexX = peduncleX + tailOverlap
let tailPath: CGPath = {
    let p = CGMutablePath()
    let back = peduncleX - tailLength
    p.move(to: CGPoint(x: tailApexX, y: 0))
    p.addLine(to: CGPoint(x: back, y: tailSpread))
    p.addLine(to: CGPoint(x: back, y: -tailSpread))
    p.closeSubpath()
    return p
}()

// One transform centres the union of body+tail on the canvas at the intended
// width. Composition is therefore derived, never nudged.
let markBounds = bodyPath.boundingBoxOfPath.union(tailPath.boundingBoxOfPath)
let scale = canvas * markWidthFraction / markBounds.width
let place = CGAffineTransform(translationX: canvas / 2, y: canvas / 2)
    .scaledBy(x: scale, y: scale)
    .translatedBy(x: -markBounds.midX, y: -markBounds.midY)

// MARK: - Render

let size = Int(canvas)
let space = CGColorSpaceCreateDeviceRGB()
guard let ctx = CGContext(data: nil, width: size, height: size,
                          bitsPerComponent: 8, bytesPerRow: size * 4,
                          space: space,
                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
else { fatalError("could not create bitmap context") }

let gradient = CGGradient(colorsSpace: space, colors: [
    CGColor(red: gradientBottom.r, green: gradientBottom.g, blue: gradientBottom.b, alpha: 1),
    CGColor(red: gradientTop.r, green: gradientTop.g, blue: gradientTop.b, alpha: 1),
] as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(gradient,
                       start: CGPoint(x: 0, y: 0),
                       end: CGPoint(x: 0, y: canvas),
                       options: [])

ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
// Tail first, body over it, same white: the overlap makes one silhouette.
ctx.addPath(tailPath.copy(using: [place])!)
ctx.fillPath()
ctx.addPath(bodyPath.copy(using: [place])!)
ctx.fillPath()

ctx.setFillColor(CGColor(red: eyeColor.r, green: eyeColor.g, blue: eyeColor.b, alpha: 1))
let eyeRect = CGRect(x: eyeX - eyeRadius, y: eyeY - eyeRadius,
                     width: eyeRadius * 2, height: eyeRadius * 2)
ctx.addPath(CGPath(ellipseIn: eyeRect, transform: [place]))
ctx.fillPath()

// MARK: - Checks against the rendered bitmap

let buffer = ctx.data!.bindMemory(to: UInt8.self, capacity: size * size * 4)

/// `y` is in CoreGraphics coordinates (origin bottom-left).
func isWhite(_ x: Int, _ y: Int) -> Bool {
    guard x >= 0, y >= 0, x < size, y < size else { return false }
    let i = ((size - 1 - y) * size + x) * 4
    return buffer[i] > 200 && buffer[i + 1] > 200 && buffer[i + 2] > 200
}

var failures: [String] = []

// 1. The eye is inside the head: every pixel on a ring just outside it is body.
let eyeCentre = CGPoint(x: eyeX, y: eyeY).applying(place)
let ringRadius = eyeRadius * scale + 8
var offRing = 0
for step in 0..<720 {
    let a = Double(step) * .pi / 360
    let x = Int((eyeCentre.x + cos(a) * ringRadius).rounded())
    let y = Int((eyeCentre.y + sin(a) * ringRadius).rounded())
    if !isWhite(x, y) { offRing += 1 }
}
if offRing > 0 {
    failures.append("eye: \(offRing)/720 ring samples fall outside the body")
}

// 2. The tail is attached: white must be one connected region, so a flood fill
// from inside the trailing edge has to reach the nose.
let tailSeed = CGPoint(x: peduncleX - tailLength + 20, y: 0).applying(place)
let noseSeed = CGPoint(x: noseX - 30, y: 0).applying(place)
var seen = [Bool](repeating: false, count: size * size)
var queue = [(Int(tailSeed.x.rounded()), Int(tailSeed.y.rounded()))]
seen[(size - 1 - queue[0].1) * size + queue[0].0] = true
var head = 0
while head < queue.count {
    let (x, y) = queue[head]; head += 1
    for (dx, dy) in [(1, 0), (-1, 0), (0, 1), (0, -1)] {
        let nx = x + dx, ny = y + dy
        guard nx >= 0, ny >= 0, nx < size, ny < size else { continue }
        let idx = (size - 1 - ny) * size + nx
        if !seen[idx] && isWhite(nx, ny) {
            seen[idx] = true
            queue.append((nx, ny))
        }
    }
}
let noseIdx = (size - 1 - Int(noseSeed.y.rounded())) * size + Int(noseSeed.x.rounded())
if !isWhite(Int(tailSeed.x.rounded()), Int(tailSeed.y.rounded())) {
    failures.append("tail: seed pixel is not on the tail")
} else if !seen[noseIdx] {
    failures.append("tail: not connected to the body (flood fill from the tail never reached the nose)")
}

// 3. The mark is centred at the intended width.
var minX = size, maxX = -1, minY = size, maxY = -1
for y in 0..<size {
    for x in 0..<size where isWhite(x, y) {
        minX = min(minX, x); maxX = max(maxX, x)
        minY = min(minY, y); maxY = max(maxY, y)
    }
}
let centreX = Double(minX + maxX) / 2, centreY = Double(minY + maxY) / 2
let width = Double(maxX - minX)
if abs(centreX - canvas / 2) > 8 || abs(centreY - canvas / 2) > 8 {
    failures.append(String(format: "centring: mark centre is (%.1f, %.1f), want (512, 512) ±8", centreX, centreY))
}
if width < 600 || width > 660 {
    failures.append(String(format: "width: mark is %.0fpx wide, want 600-660", width))
}

guard failures.isEmpty else {
    FileHandle.standardError.write((failures.joined(separator: "\n") + "\n").data(using: .utf8)!)
    exit(1)
}
print("eye enclosed, tail connected, mark centred " +
      String(format: "(%.0f, %.0f) at %.0fpx wide", centreX, centreY, width))

// MARK: - Write

let root = URL(fileURLWithPath: CommandLine.arguments[0])
    .deletingLastPathComponent().deletingLastPathComponent()
// Outside the app target: the .icon bundle supplies every size the build
// needs, legacy ones included. This raster is the shareable flat mark, and the
// bitmap the geometry checks above are asserted against.
try! FileManager.default.createDirectory(at: root.appendingPathComponent("icon"),
                                         withIntermediateDirectories: true)
let out = root.appendingPathComponent("icon/icon_1024.png")
let dest = CGImageDestinationCreateWithURL(out as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(dest, ctx.makeImage()!, nil)
guard CGImageDestinationFinalize(dest) else {
    FileHandle.standardError.write("could not write \(out.path)\n".data(using: .utf8)!)
    exit(1)
}
print("wrote \(out.path)")

// MARK: - Layer SVGs for the Icon Composer bundle

// Same paths, same transform, so the layered icon and the flat PNG cannot
// describe different shapes. SVG's y axis points down, so the placement
// transform is composed with a flip about the canvas mid-line.
let svgPlace = place.concatenating(
    CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: canvas))

func svgPathData(_ path: CGPath) -> String {
    var d = ""
    func f(_ v: CGFloat) -> String { String(format: "%.2f", v) }
    path.copy(using: [svgPlace])!.applyWithBlock { element in
        let p = element.pointee.points
        switch element.pointee.type {
        case .moveToPoint: d += "M\(f(p[0].x)) \(f(p[0].y))"
        case .addLineToPoint: d += "L\(f(p[0].x)) \(f(p[0].y))"
        case .addQuadCurveToPoint:
            d += "Q\(f(p[0].x)) \(f(p[0].y)) \(f(p[1].x)) \(f(p[1].y))"
        case .addCurveToPoint:
            d += "C\(f(p[0].x)) \(f(p[0].y)) \(f(p[1].x)) \(f(p[1].y)) \(f(p[2].x)) \(f(p[2].y))"
        case .closeSubpath: d += "Z"
        @unknown default: break
        }
    }
    return d
}

let svgHeader = """
<svg xmlns="http://www.w3.org/2000/svg" width="\(Int(canvas))" height="\(Int(canvas))" \
viewBox="0 0 \(Int(canvas)) \(Int(canvas))">
"""

// The background is the document's own `fill`, not a layer: only a document
// fill is substituted for the Dark, Tinted and Clear appearances, so a
// background drawn as a foreground group would fight the system instead of
// letting it recolour the icon.
func srgb(_ c: (r: Double, g: Double, b: Double)) -> String {
    String(format: "extended-srgb:%.5f,%.5f,%.5f,1.00000", c.r, c.g, c.b)
}

let iconJSON = """
{
  "fill" : {
    "linear-gradient" : [
      "\(srgb(gradientTop))",
      "\(srgb(gradientBottom))"
    ]
  },
  "groups" : [
    { "layers" : [ { "image-name" : "tail.svg", "fill" : { "solid" : "extended-srgb:1.00000,1.00000,1.00000,1.00000" } } ] },
    { "layers" : [ { "image-name" : "body.svg", "fill" : { "solid" : "extended-srgb:1.00000,1.00000,1.00000,1.00000" } } ] }
  ],
  "supported-platforms" : {
    "squares" : [ "iOS" ]
  }
}

"""

let tailSVG = """
\(svgHeader)
<path fill="#FFFFFF" d="\(svgPathData(tailPath))"/>
</svg>

"""

// The eye is a hole punched through the body rather than its own dark layer:
// the system recolours foreground layers for the tinted and clear appearances,
// where a dark dot would vanish but a punch-out still reads.
let bodySVG = """
\(svgHeader)
<path fill="#FFFFFF" fill-rule="evenodd" \
d="\(svgPathData(bodyPath))\(svgPathData(CGPath(ellipseIn: eyeRect, transform: nil)))"/>
</svg>

"""

let iconBundle = root.appendingPathComponent("WAFishMap/WAFishMap.icon")
let assets = iconBundle.appendingPathComponent("Assets")
try! FileManager.default.createDirectory(at: assets, withIntermediateDirectories: true)
try! iconJSON.data(using: .utf8)!
    .write(to: iconBundle.appendingPathComponent("icon.json"))
var svgURLs: [String: URL] = [:]
for (name, svg) in [("tail", tailSVG), ("body", bodySVG)] {
    let url = assets.appendingPathComponent("\(name).svg")
    try! svg.data(using: .utf8)!.write(to: url)
    svgURLs[name] = url
}

// MARK: - Checks against the rendered SVGs

// The files are read back and rasterised, so what is asserted is what a
// renderer actually draws - not what the generator meant to write. This is the
// only check on the y-flip: get it wrong and the fish is mirrored, which moves
// the eye below the centreline and the punch-out sample lands on white.
func rasterise(_ url: URL) -> NSBitmapImageRep {
    guard let image = NSImage(contentsOf: url) else {
        FileHandle.standardError.write("could not load \(url.path)\n".data(using: .utf8)!)
        exit(1)
    }
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                               isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: size * 4, bitsPerPixel: 32)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    image.draw(in: NSRect(x: 0, y: 0, width: canvas, height: canvas))
    NSGraphicsContext.restoreGraphicsState()
    return rep
}

// Expectations are expressed against the canvas independently of `svgPlace`,
// so a wrong placement transform is caught rather than cancelled out: sampling
// a drawing through the same transform that drew it can never disagree with it.
// `markBounds` and `scale` come from the paths, not from the transform.
func expectedX(_ markX: Double) -> Double { canvas / 2 + scale * (markX - markBounds.midX) }
func expectedY(_ markY: Double) -> Double { canvas / 2 - scale * markY }  // SVG y points down

/// Bounding box of the pixels matching `test`, in top-down raster coordinates.
func boundingBox(_ rep: NSBitmapImageRep, within region: CGRect? = nil,
                 where test: (NSColor) -> Bool) -> CGRect? {
    let area = region ?? CGRect(x: 0, y: 0, width: canvas, height: canvas)
    var minX = size, maxX = -1, minY = size, maxY = -1
    for y in Int(area.minY)..<Int(area.maxY) {
        for x in Int(area.minX)..<Int(area.maxX) where test(rep.colorAt(x: x, y: y)!) {
            minX = min(minX, x); maxX = max(maxX, x)
            minY = min(minY, y); maxY = max(maxY, y)
        }
    }
    guard maxX >= minX else { return nil }
    return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
}

func check(_ label: String, _ got: Double, _ want: Double, tolerance: Double = 4) {
    if abs(got - want) > tolerance {
        svgFailures.append(String(format: "%@: %.0f, want %.0f ±%.0f", label, got, want, tolerance))
    }
}

var svgFailures: [String] = []

func isOpaque(_ c: NSColor) -> Bool { c.alphaComponent > 0.99 && c.redComponent > 0.99 }
func isClear(_ c: NSColor) -> Bool { c.alphaComponent < 0.01 }

let tailRep = rasterise(svgURLs["tail"]!)
if let box = boundingBox(tailRep, where: isOpaque) {
    check("tail.svg trailing edge", box.minX, expectedX(peduncleX - tailLength))
    check("tail.svg apex", box.maxX, expectedX(tailApexX))
    check("tail.svg top lobe", box.minY, expectedY(tailSpread))
    check("tail.svg bottom lobe", box.maxY, expectedY(-tailSpread))
} else {
    svgFailures.append("tail.svg: nothing is drawn")
}

let bodyRep = rasterise(svgURLs["body"]!)
guard let bodyBox = boundingBox(bodyRep, where: isOpaque) else {
    FileHandle.standardError.write("body.svg: nothing is drawn\n".data(using: .utf8)!)
    exit(1)
}
check("body.svg peduncle", bodyBox.minX, expectedX(peduncleX))
check("body.svg nose", bodyBox.maxX, expectedX(noseX))
check("body.svg back", bodyBox.minY, expectedY(bodyHeight))
check("body.svg belly", bodyBox.maxY, expectedY(-bodyHeight))

// The eye is a hole, so it is transparency *enclosed* by the silhouette - not
// merely transparency inside the bounding box, most of which is the background
// either side of the almond. Flooding the clear pixels inward from the box edge
// leaves only the enclosed ones. Measuring where the hole actually landed is
// what catches a mirrored or missing punch-out; asking whether one predicted
// pixel is clear would not.
var outside = Set<Int>()
var flood: [(Int, Int)] = []
for x in Int(bodyBox.minX)...Int(bodyBox.maxX) {
    for y in [Int(bodyBox.minY), Int(bodyBox.maxY)] where isClear(bodyRep.colorAt(x: x, y: y)!) {
        if outside.insert(y * size + x).inserted { flood.append((x, y)) }
    }
}
for y in Int(bodyBox.minY)...Int(bodyBox.maxY) {
    for x in [Int(bodyBox.minX), Int(bodyBox.maxX)] where isClear(bodyRep.colorAt(x: x, y: y)!) {
        if outside.insert(y * size + x).inserted { flood.append((x, y)) }
    }
}
var cursor = 0
while cursor < flood.count {
    let (x, y) = flood[cursor]; cursor += 1
    for (dx, dy) in [(1, 0), (-1, 0), (0, 1), (0, -1)] {
        let nx = x + dx, ny = y + dy
        guard bodyBox.contains(CGPoint(x: nx, y: ny)) else { continue }
        if isClear(bodyRep.colorAt(x: nx, y: ny)!), outside.insert(ny * size + nx).inserted {
            flood.append((nx, ny))
        }
    }
}
var holeMinX = size, holeMaxX = -1, holeMinY = size, holeMaxY = -1
for y in Int(bodyBox.minY)...Int(bodyBox.maxY) {
    for x in Int(bodyBox.minX)...Int(bodyBox.maxX)
    where isClear(bodyRep.colorAt(x: x, y: y)!) && !outside.contains(y * size + x) {
        holeMinX = min(holeMinX, x); holeMaxX = max(holeMaxX, x)
        holeMinY = min(holeMinY, y); holeMaxY = max(holeMaxY, y)
    }
}
if holeMaxX >= holeMinX {
    check("body.svg eye centre x", Double(holeMinX + holeMaxX) / 2, expectedX(eyeX))
    check("body.svg eye centre y", Double(holeMinY + holeMaxY) / 2, expectedY(eyeY))
    check("body.svg eye diameter", Double(holeMaxX - holeMinX), eyeRadius * 2 * scale, tolerance: 6)
} else {
    svgFailures.append("body.svg: the eye is filled, not punched through")
}

if !isClear(bodyRep.colorAt(x: 30, y: 30)!) {
    svgFailures.append("body.svg: the layer is not transparent outside the mark")
}

guard svgFailures.isEmpty else {
    FileHandle.standardError.write((svgFailures.joined(separator: "\n") + "\n").data(using: .utf8)!)
    exit(1)
}
print("tail and body layers placed, eye punched through")
print("wrote \(iconBundle.path)")
