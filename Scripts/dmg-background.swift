// Draws the DMG window background: a dark slate chalkboard with a
// hand-drawn chalk arrow from the app icon to the Applications alias, and
// a chalk hint underneath.
//
//   swift Scripts/dmg-background.swift <out.png> <scale>
//
// The window is 600x400 points; icons sit at (150, 190) and (450, 190) in
// Finder's top-left coordinates (see Scripts/make-dmg.sh). The randomness
// is seeded, so every build draws the same board.

import AppKit

let args = CommandLine.arguments
guard args.count == 3, let scale = Double(args[2]) else {
    FileHandle.standardError.write("usage: dmg-background.swift <out.png> <scale>\n".data(using: .utf8)!)
    exit(2)
}

let size = CGSize(width: 600, height: 400)
let iconY = size.height - 190        // icon centre line, in AppKit's bottom-left space
let gap = (left: 150.0 + 64, right: 450.0 - 64)  // between the 128-pt icons
let chalk = NSColor(srgbRed: 0.95, green: 0.94, blue: 0.90, alpha: 1)

/// SplitMix64: small, seeded, deterministic.
struct Rng {
    var state: UInt64
    mutating func next() -> Double {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return Double((z ^ (z >> 31)) >> 11) / Double(1 << 53)
    }
    mutating func range(_ lo: Double, _ hi: Double) -> Double { lo + (hi - lo) * next() }
}
var rng = Rng(state: 0x7E57_ED)

func bitmap() -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: Int(size.width * scale), pixelsHigh: Int(size.height * scale),
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = size
    return rep
}

func drawing(into rep: NSBitmapImageRep, _ body: () -> Void) {
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    body()
    NSGraphicsContext.restoreGraphicsState()
}

/// Points along a quadratic curve, so strokes can be jittered point by point.
func curve(_ a: CGPoint, _ c: CGPoint, _ b: CGPoint, steps: Int) -> [CGPoint] {
    (0...steps).map { i in
        let t = Double(i) / Double(steps), u = 1 - t
        return CGPoint(x: u * u * a.x + 2 * u * t * c.x + t * t * b.x,
                       y: u * u * a.y + 2 * u * t * c.y + t * t * b.y)
    }
}

/// A chalk line: several faint, wobbling passes over the same points, the
/// way a stick of chalk leaves an uneven, overlapping mark.
func chalkStroke(_ points: [CGPoint], width: Double) {
    for _ in 0..<7 {
        let path = NSBezierPath()
        let drift = CGPoint(x: rng.range(-1, 1), y: rng.range(-1, 1))
        for (i, p) in points.enumerated() {
            let q = CGPoint(x: p.x + drift.x + rng.range(-0.7, 0.7), y: p.y + drift.y + rng.range(-0.7, 0.7))
            i == 0 ? path.move(to: q) : path.line(to: q)
        }
        path.lineWidth = width * rng.range(0.55, 1.0)
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        chalk.withAlphaComponent(rng.range(0.22, 0.38)).setStroke()
        path.stroke()
    }
}

// The board: dark slate, a lighter haze toward the middle, old eraser
// smudges, and fine dust.
let board = bitmap()
drawing(into: board) {
    NSColor(srgbRed: 0.105, green: 0.135, blue: 0.125, alpha: 1).setFill()
    NSRect(origin: .zero, size: size).fill()
    NSGradient(colors: [NSColor(srgbRed: 0.20, green: 0.24, blue: 0.22, alpha: 1),
                        NSColor(srgbRed: 0.105, green: 0.135, blue: 0.125, alpha: 0)])!
        .draw(in: NSRect(x: -60, y: -40, width: 720, height: 480), relativeCenterPosition: NSPoint(x: 0, y: 0.1))
    for _ in 0..<14 {
        let w = rng.range(140, 320), h = rng.range(40, 90)
        let rect = NSRect(x: rng.range(-60, 560), y: rng.range(-20, 380), width: w, height: h)
        NSGradient(colors: [NSColor.white.withAlphaComponent(rng.range(0.015, 0.035)),
                            NSColor.white.withAlphaComponent(0)])!
            .draw(in: NSBezierPath(ovalIn: rect), relativeCenterPosition: .zero)
    }
    for _ in 0..<5000 {
        let r = rng.range(0.25, 0.8)
        NSColor.white.withAlphaComponent(rng.range(0.02, 0.09)).setFill()
        NSBezierPath(ovalIn: NSRect(x: rng.range(0, 600), y: rng.range(0, 400), width: r, height: r)).fill()
    }
}

// The chalk marks go on their own layer so grain can be knocked out of
// them without touching the board.
let marks = bitmap()
drawing(into: marks) {
    // A gently rounded arc, centred in the gap between the icons.
    let mid = (gap.left + gap.right) / 2
    let start = CGPoint(x: mid - 66, y: iconY - 4)
    let tip = CGPoint(x: mid + 66, y: iconY - 2)
    let arc = curve(start, CGPoint(x: mid, y: iconY + 34), tip, steps: 60)
    chalkStroke(arc, width: 5)

    // Arrowhead: two short, slightly bowed strokes back from the tip,
    // angled off the arc's final direction.
    let back = arc[arc.count - 8]
    let heading = atan2(tip.y - back.y, tip.x - back.x)
    for side in [-1.0, 1.0] {
        let angle = heading + .pi + side * 0.62
        let end = CGPoint(x: tip.x + 22 * cos(angle), y: tip.y + 22 * sin(angle))
        let bow = CGPoint(x: (tip.x + end.x) / 2 + side * 2 * sin(angle), y: (tip.y + end.y) / 2 - side * 2 * cos(angle))
        chalkStroke(curve(tip, bow, end, steps: 12), width: 5)
    }

    let hint = "drag TextEd to Applications" as NSString
    let attrs: [NSAttributedString.Key: Any] = [
        .font: NSFont(name: "Chalkduster", size: 16) ?? NSFont.systemFont(ofSize: 16),
        .foregroundColor: chalk.withAlphaComponent(0.82),
    ]
    let hintSize = hint.size(withAttributes: attrs)
    hint.draw(at: NSPoint(x: (size.width - hintSize.width) / 2, y: 58), withAttributes: attrs)

    // Grain: chalk skips over the board's texture.
    NSGraphicsContext.current!.compositingOperation = .destinationOut
    for _ in 0..<9000 {
        let r = rng.range(0.4, 1.3)
        NSColor.black.withAlphaComponent(rng.range(0.25, 0.8)).setFill()
        NSBezierPath(ovalIn: NSRect(x: rng.range(150, 450), y: rng.range(40, 260), width: r, height: r)).fill()
    }
}

drawing(into: board) {
    // NSImageRep.draw(in:) would composite with .copy and erase the board.
    marks.draw(in: NSRect(origin: .zero, size: size), from: .zero, operation: .sourceOver,
               fraction: 1, respectFlipped: false, hints: nil)
}
try! board.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: args[1]))
