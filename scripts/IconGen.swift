import AppKit

// Draws the Halo app icon (a glassy ring of dots around a center) to a PNG.
// Usage: swift scripts/IconGen.swift <output.png>

let size = 1024.0
let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()
guard let ctx = NSGraphicsContext.current?.cgContext else { fatalError("no context") }

let margin = 92.0
let content = size - 2 * margin
let rect = CGRect(x: margin, y: margin, width: content, height: content)
let corner = content * 0.235

// Rounded-square mask
ctx.addPath(CGPath(roundedRect: rect, cornerWidth: corner, cornerHeight: corner, transform: nil))
ctx.clip()

// Diagonal gradient background
let bg = CGGradient(
    colorsSpace: CGColorSpaceCreateDeviceRGB(),
    colors: [
        NSColor(srgbRed: 0.35, green: 0.29, blue: 1.00, alpha: 1).cgColor,
        NSColor(srgbRed: 0.72, green: 0.28, blue: 1.00, alpha: 1).cgColor,
    ] as CFArray,
    locations: [0, 1]
)!
ctx.drawLinearGradient(bg, start: CGPoint(x: rect.minX, y: rect.maxY),
                       end: CGPoint(x: rect.maxX, y: rect.minY), options: [])

// Soft top highlight
let glow = CGGradient(
    colorsSpace: CGColorSpaceCreateDeviceRGB(),
    colors: [NSColor.white.withAlphaComponent(0.28).cgColor,
             NSColor.white.withAlphaComponent(0).cgColor] as CFArray,
    locations: [0, 1]
)!
ctx.drawRadialGradient(glow, startCenter: CGPoint(x: size / 2, y: size * 0.72), startRadius: 0,
                       endCenter: CGPoint(x: size / 2, y: size * 0.72), endRadius: content * 0.6,
                       options: [])

let center = CGPoint(x: size / 2, y: size / 2)
let ringRadius = content * 0.30
let dot = content * 0.072

// Faint connecting ring
ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.16).cgColor)
ctx.setLineWidth(content * 0.012)
ctx.strokeEllipse(in: CGRect(x: center.x - ringRadius, y: center.y - ringRadius,
                             width: ringRadius * 2, height: ringRadius * 2))

// Ring of dots (top one accented)
for i in 0..<8 {
    let angle = Double(i) / 8.0 * 2 * .pi - .pi / 2
    let p = CGPoint(x: center.x + cos(angle) * ringRadius, y: center.y + sin(angle) * ringRadius)
    ctx.setFillColor(NSColor.white.withAlphaComponent(i == 0 ? 1.0 : 0.55).cgColor)
    ctx.fillEllipse(in: CGRect(x: p.x - dot, y: p.y - dot, width: dot * 2, height: dot * 2))
}

// Center hub
let hub = content * 0.135
ctx.setFillColor(NSColor.white.withAlphaComponent(0.96).cgColor)
ctx.fillEllipse(in: CGRect(x: center.x - hub, y: center.y - hub, width: hub * 2, height: hub * 2))

image.unlockFocus()

let outPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon_1024.png"
if let tiff = image.tiffRepresentation,
   let rep = NSBitmapImageRep(data: tiff),
   let png = rep.representation(using: .png, properties: [:]) {
    try! png.write(to: URL(fileURLWithPath: outPath))
    print("wrote \(outPath)")
}
