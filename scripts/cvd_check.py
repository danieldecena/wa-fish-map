#!/usr/bin/env python3
"""Simulate colour-vision deficiency over the pinned ramp-check frames.

Reads docs/design/ramp-check/ramp-{light,dark}.png and writes
ramp-{light,dark}-{deuteranopia,protanopia}.png beside them, so the rating ramp
can be looked at the way a deuteranope or protanope sees it.

Stdlib only, like the other scripts here. Handles exactly one PNG shape (colour
type 6, bit depth 8, non-interlaced) because that is what simctl writes, and
refuses anything else rather than guessing.

Simulator screenshots may be Display P3 tagged; this treats them as sRGB. That
skews chromaticity slightly but cannot flip a verdict that three warm hues
collapse. Exact numbers come from WAFishMapTests/CVDSeparationTests.swift, which
resolves the real colours; keep the two sets of numbers distinct in any log.

Controls run before any frame is touched. A detector gets a known-bad input
(red/green must collapse) and a known-good one (blue/yellow must not) before its
output is trusted.
"""

import math
import struct
import sys
import zlib
from pathlib import Path

# Machado, Oliveira, Fernandes 2009, severity 1.0, applied in linear RGB.
MATRICES = {
    "deuteranopia": (
        (0.367322, 0.860646, -0.227968),
        (0.280085, 0.672501, 0.047413),
        (-0.011820, 0.042940, 0.968881),
    ),
    "protanopia": (
        (0.152286, 1.052583, -0.204868),
        (0.114503, 0.786281, 0.099216),
        (-0.003882, -0.048116, 1.051998),
    ),
}
IDENTITY = ((1, 0, 0), (0, 1, 0), (0, 0, 1))

FRAMES = Path(__file__).resolve().parent.parent / "docs" / "design" / "ramp-check"


def to_linear(v):
    c = v / 255
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def from_linear(c):
    c = min(1.0, max(0.0, c))
    v = 12.92 * c if c <= 0.0031308 else 1.055 * c ** (1 / 2.4) - 0.055
    return round(v * 255)


def simulate(rgb, matrix):
    lin = [to_linear(v) for v in rgb]
    return tuple(from_linear(sum(m * c for m, c in zip(row, lin))) for row in matrix)


def lab(rgb):
    r, g, b = (to_linear(v) for v in rgb)
    x = (0.4124564 * r + 0.3575761 * g + 0.1804375 * b) / 0.95047
    y = 0.2126729 * r + 0.7151522 * g + 0.0721750 * b
    z = (0.0193339 * r + 0.1191920 * g + 0.9503041 * b) / 1.08883

    def f(t):
        return t ** (1 / 3) if t > 0.008856 else 7.787 * t + 16 / 116

    fx, fy, fz = f(x), f(y), f(z)
    return 116 * fy - 16, 500 * (fx - fy), 200 * (fy - fz)


def delta_e(a, b):
    return math.dist(lab(a), lab(b))


def hue_gap(a, b):
    ha = math.degrees(math.atan2(lab(a)[2], lab(a)[1]))
    hb = math.degrees(math.atan2(lab(b)[2], lab(b)[1]))
    d = abs(ha - hb) % 360
    return min(d, 360 - d)


def run_controls(matrices):
    """Returns a list of failure strings; empty means every control held."""
    failures = []
    if simulate((10, 100, 200), IDENTITY) != (10, 100, 200):
        failures.append("identity matrix does not round-trip (10,100,200)")
    red, green = (255, 0, 0), (0, 255, 0)
    blue, yellow = (0, 0, 255), (255, 255, 0)
    if hue_gap(red, green) <= 90:
        failures.append(
            f"red/green unsimulated hue gap {hue_gap(red, green):.1f} <= 90"
        )
    if hue_gap(blue, yellow) <= 90:
        failures.append(
            f"blue/yellow unsimulated hue gap {hue_gap(blue, yellow):.1f} <= 90"
        )
    for name, m in matrices.items():
        # Hue, not delta E: pure red/green keep a real lightness gap under a
        # correct simulation, so a delta E assertion would fail a working one.
        rg = hue_gap(simulate(red, m), simulate(green, m))
        if rg >= 15:
            failures.append(
                f"{name}: red/green hue gap {rg:.1f} >= 15 after simulation"
            )
        by_hue = hue_gap(simulate(blue, m), simulate(yellow, m))
        by_de = delta_e(simulate(blue, m), simulate(yellow, m))
        if by_hue <= 90 or by_de <= 40:
            failures.append(
                f"{name}: blue/yellow collapsed (hue {by_hue:.1f}, dE {by_de:.1f})"
            )
    return failures


def read_png(path):
    return decode_png(path.read_bytes(), path)


def decode_png(data, path):
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        sys.exit(f"{path}: not a PNG")
    pos, idat, ihdr = 8, [], None
    while pos < len(data):
        n, kind = struct.unpack(">I4s", data[pos : pos + 8])
        body = data[pos + 8 : pos + 8 + n]
        if kind == b"IHDR":
            ihdr = struct.unpack(">IIBBBBB", body)
        elif kind == b"IDAT":
            idat.append(body)
        pos += 12 + n
    if ihdr is None:
        sys.exit(f"{path}: no IHDR chunk")
    w, h, depth, ctype, _, _, interlace = ihdr
    if (depth, ctype, interlace) != (8, 6, 0):
        sys.exit(
            f"{path}: need 8-bit RGBA non-interlaced, got depth={depth} type={ctype} interlace={interlace}"
        )
    raw = zlib.decompress(b"".join(idat))
    stride = w * 4
    if len(raw) != h * (stride + 1):
        sys.exit(f"{path}: pixel data is {len(raw)} bytes, expected {h * (stride + 1)}")
    rows, prev = [], bytearray(stride)
    for y in range(h):
        off = y * (stride + 1)
        ft, line = raw[off], bytearray(raw[off + 1 : off + 1 + stride])
        if ft == 1:
            for i in range(4, stride):
                line[i] = (line[i] + line[i - 4]) & 255
        elif ft == 2:
            line = bytearray((a + b) & 255 for a, b in zip(line, prev))
        elif ft == 3:
            for i in range(stride):
                left = line[i - 4] if i >= 4 else 0
                line[i] = (line[i] + ((left + prev[i]) >> 1)) & 255
        elif ft == 4:
            for i in range(stride):
                a = line[i - 4] if i >= 4 else 0
                b = prev[i]
                c = prev[i - 4] if i >= 4 else 0
                p = a + b - c
                pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                pred = a if pa <= pb and pa <= pc else (b if pb <= pc else c)
                line[i] = (line[i] + pred) & 255
        elif ft != 0:
            sys.exit(f"{path}: unknown filter {ft} on row {y}")
        rows.append(bytes(line))
        prev = line
    return w, h, rows


def filtered_png(rows, filters):
    """Forward-filter rows (one filter type per row) into a PNG, for the control."""
    stride = len(rows[0])
    prev = bytes(stride)
    raw = b""
    for row, ft in zip(rows, filters):
        out = bytearray()
        for i in range(stride):
            a = row[i - 4] if i >= 4 else 0
            b = prev[i]
            c = prev[i - 4] if i >= 4 else 0
            if ft == 4:
                p = a + b - c
                pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                pred = a if pa <= pb and pa <= pc else (b if pb <= pc else c)
            else:
                pred = (0, a, b, (a + b) >> 1)[ft]
            out.append((row[i] - pred) & 255)
        raw += bytes([ft]) + bytes(out)
        prev = row

    def chunk(kind, body):
        c = struct.pack(">I", len(body)) + kind + body
        return c + struct.pack(">I", zlib.crc32(kind + body))

    return (
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", struct.pack(">IIBBBBB", stride // 4, len(rows), 8, 6, 0, 0, 0))
        + chunk(b"IDAT", zlib.compress(raw))
        + chunk(b"IEND", b"")
    )


def png_control():
    """Known-good input for the reader: every filter type must decode back to the source."""
    rows = [
        bytes((x * 37 + y * 91 + x * y) % 256 for x in range(28)) for y in range(10)
    ]
    w, h, got = decode_png(
        filtered_png(rows, [0, 1, 2, 3, 4, 4, 3, 2, 1, 0]), "control"
    )
    if (w, h) != (7, 10) or got != rows:
        sys.exit("controls failed: PNG reader does not round-trip filter types 0-4")


def write_png(path, w, h, rows):
    raw = b"".join(b"\x00" + r for r in rows)

    def chunk(kind, body):
        c = struct.pack(">I", len(body)) + kind + body
        return c + struct.pack(">I", zlib.crc32(kind + body))

    path.write_bytes(
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
        + chunk(b"IDAT", zlib.compress(raw, 1))
        + chunk(b"IEND", b"")
    )


def simulate_frame(src, dst, matrix):
    w, h, rows = read_png(src)
    cache = {}
    out = []
    for row in rows:
        px = [row[i : i + 4] for i in range(0, len(row), 4)]
        for p in set(px) - cache.keys():
            cache[p] = bytes(simulate((p[0], p[1], p[2]), matrix)) + p[3:4]
        out.append(b"".join(cache[p] for p in px))
    write_png(dst, w, h, out)
    # Observe the written file, not the write: same size, and not a copy.
    w2, h2, back = read_png(dst)
    if (w2, h2) != (w, h) or back == rows:
        sys.exit(f"{dst}: output is the wrong size or identical to {src}")


def main():
    png_control()
    failures = run_controls(MATRICES)
    if failures:
        sys.exit("controls failed, no frame touched:\n  " + "\n  ".join(failures))
    print(
        "controls: png filters, identity round-trip, red/green collapse, blue/yellow separate: ok"
    )
    for look in ("light", "dark"):
        src = FRAMES / f"ramp-{look}.png"
        for name, m in MATRICES.items():
            dst = FRAMES / f"ramp-{look}-{name}.png"
            simulate_frame(src, dst, m)
            print(f"wrote {dst.relative_to(FRAMES.parent.parent.parent)}")


if __name__ == "__main__":
    main()
