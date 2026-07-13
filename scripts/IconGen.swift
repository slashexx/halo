import AppKit

// Draws the Halo app icon: a luminous ring (a halo) with one brilliant point of
// light on it — the solar-eclipse "diamond ring" — on a deep dark sky.
// Usage: swift scripts/IconGen.swift <output.png>

let size = 1024.0
let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()
guard let ctx = NSGraphicsContext.current?.cgContext else { fatalError("no context") }

let margin = 92.0
let content = size - 2 * margin
let rect = CGRect(x: margin, y: margin, width: content, height: content)
let corner = content * 0.235
let center = CGPoint(x: size / 2, y: size / 2)

// Squircle mask
ctx.addPath(CGPath(roundedRect: rect, cornerWidth: corner, cornerHeight: corner, transform: nil))
ctx.clip()

// Deep-space background: indigo core fading to near-black.
let bg = CGGradient(
    colorsSpace: CGColorSpaceCreateDeviceRGB(),
    colors: [
        NSColor(srgbRed: 0.16, green: 0.13, blue: 0.34, alpha: 1).cgColor,
        NSColor(srgbRed: 0.05, green: 0.04, blue: 0.09, alpha: 1).cgColor,
    ] as CFArray,
    locations: [0, 1]
)!
ctx.drawRadialGradient(bg, startCenter: center, startRadius: 0,
                       endCenter: center, endRadius: content * 0.72, options: [.drawsAfterEndLocation])

// All light is additive so overlaps bloom.
ctx.setBlendMode(.plusLighter)

let ringRadius = content * 0.30
let ringRect = CGRect(x: center.x - ringRadius, y: center.y - ringRadius,
                      width: ringRadius * 2, height: ringRadius * 2)

// Glowing ring: wide-faint → narrow-bright passes build a soft bloom.
let ringPasses: [(CGFloat, CGFloat)] = [
    (content * 0.065, 0.10),
    (content * 0.038, 0.18),
    (content * 0.020, 0.45),
    (content * 0.009, 0.95),
]
for (width, alpha) in ringPasses {
    ctx.setStrokeColor(NSColor(srgbRed: 0.85, green: 0.88, blue: 1.0, alpha: alpha).cgColor)
    ctx.setLineWidth(width)
    ctx.strokeEllipse(in: ringRect)
}

// The diamond: one brilliant point of light on the ring (upper-right).
let angle = 52.0 * .pi / 180.0
let diamond = CGPoint(x: center.x + cos(angle) * ringRadius,
                      y: center.y + sin(angle) * ringRadius)

// Bloom halo around the point.
let bloom = CGGradient(
    colorsSpace: CGColorSpaceCreateDeviceRGB(),
    colors: [NSColor.white.withAlphaComponent(0.95).cgColor,
             NSColor.white.withAlphaComponent(0).cgColor] as CFArray,
    locations: [0, 1]
)!
ctx.drawRadialGradient(bloom, startCenter: diamond, startRadius: 0,
                       endCenter: diamond, endRadius: content * 0.17, options: [])

// Four-point sparkle spikes.
func spike(dx: CGFloat, dy: CGFloat, length: CGFloat, half: CGFloat) {
    let tip = CGPoint(x: diamond.x + dx * length, y: diamond.y + dy * length)
    // perpendicular for the base width
    let px = -dy, py = dx
    let p = CGMutablePath()
    p.move(to: CGPoint(x: diamond.x + px * half, y: diamond.y + py * half))
    p.addLine(to: tip)
    p.addLine(to: CGPoint(x: diamond.x - px * half, y: diamond.y - py * half))
    p.closeSubpath()
    ctx.addPath(p)
    ctx.setFillColor(NSColor.white.withAlphaComponent(0.8).cgColor)
    ctx.fillPath()
}
let spikeLen = content * 0.28
let spikeHalf = content * 0.016
spike(dx: 1, dy: 0, length: spikeLen, half: spikeHalf)
spike(dx: -1, dy: 0, length: spikeLen, half: spikeHalf)
spike(dx: 0, dy: 1, length: spikeLen, half: spikeHalf)
spike(dx: 0, dy: -1, length: spikeLen, half: spikeHalf)

// Bright core.
let core = content * 0.030
ctx.setFillColor(NSColor.white.cgColor)
ctx.fillEllipse(in: CGRect(x: diamond.x - core, y: diamond.y - core, width: core * 2, height: core * 2))

image.unlockFocus()

let outPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon_1024.png"
if let tiff = image.tiffRepresentation,
   let rep = NSBitmapImageRep(data: tiff),
   let png = rep.representation(using: .png, properties: [:]) {
    try! png.write(to: URL(fileURLWithPath: outPath))
    print("wrote \(outPath)")
}
