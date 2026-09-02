// Generates WAFishMap/Assets.xcassets/AppIcon.appiconset/icon_1024.png.
//
//     swift scripts/make_icon.swift
//
// CoreGraphics rather than an SVG pipeline: this Mac has no rasterizer
// (rsvg/inkscape/magick/cairosvg are all absent) but the Xcode toolchain is
// already a hard requirement for the project, so /usr/bin/swift always works.
//
// The mark is drawn in its own coordinate space centred on (0,0) and placed on
// the canvas by one transform, so the composition is fixed by construction.
// Nothing is written until the three checks at the bottom pass against the
// rendered bitmap.

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
let out = root.appendingPathComponent(
    "WAFishMap/Assets.xcassets/AppIcon.appiconset/icon_1024.png")
let dest = CGImageDestinationCreateWithURL(out as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(dest, ctx.makeImage()!, nil)
guard CGImageDestinationFinalize(dest) else {
    FileHandle.standardError.write("could not write \(out.path)\n".data(using: .utf8)!)
    exit(1)
}
print("wrote \(out.path)")
