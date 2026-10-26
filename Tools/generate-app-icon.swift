#!/usr/bin/env swift
// Generates the TimeTracker app icon at every macOS size.
// Usage: swift Tools/generate-app-icon.swift <output-dir>
import AppKit

let canvas: CGFloat = 1024
let sizes = [16, 32, 64, 128, 256, 512, 1024]

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

/// Draws the icon on a 1024 x 1024 canvas (origin bottom-left).
func draw(in ctx: CGContext) {
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    let body = CGRect(x: 100, y: 100, width: 824, height: 824)
    let bodyPath = CGPath(roundedRect: body, cornerWidth: 185, cornerHeight: 185, transform: nil)

    // Drop shadow under the body.
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: color(0x000000, 0.35))
    ctx.setFillColor(color(0x2B5BD7))
    ctx.addPath(bodyPath)
    ctx.fillPath()
    ctx.restoreGState()

    // Background gradient: indigo (top) to teal (bottom).
    ctx.saveGState()
    ctx.addPath(bodyPath)
    ctx.clip()
    let gradient = CGGradient(colorsSpace: space, colors: [color(0x1FB5C4), color(0x2D6BE0), color(0x4A3FC9)] as CFArray,
                              locations: [0, 0.5, 1])!
    ctx.drawLinearGradient(gradient, start: CGPoint(x: 512, y: 100), end: CGPoint(x: 512, y: 924), options: [])
    // Soft top highlight.
    let sheen = CGGradient(colorsSpace: space, colors: [color(0xFFFFFF, 0.18), color(0xFFFFFF, 0)] as CFArray,
                           locations: [0, 1])!
    ctx.drawLinearGradient(sheen, start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 560), options: [])
    ctx.restoreGState()

    // Clock face.
    let center = CGPoint(x: 400, y: 512)
    let radius: CGFloat = 215
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -8), blur: 20, color: color(0x0A1A4A, 0.35))
    ctx.setFillColor(color(0xFFFFFF))
    ctx.fillEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
    ctx.restoreGState()

    // Hour ticks at 12, 3, 6, 9.
    ctx.setStrokeColor(color(0xB9C4E0))
    ctx.setLineWidth(12)
    ctx.setLineCap(.round)
    for i in 0..<4 {
        let angle = CGFloat(i) * .pi / 2
        let from = CGPoint(x: center.x + cos(angle) * (radius - 22), y: center.y + sin(angle) * (radius - 22))
        let to = CGPoint(x: center.x + cos(angle) * (radius - 52), y: center.y + sin(angle) * (radius - 52))
        ctx.move(to: from)
        ctx.addLine(to: to)
        ctx.strokePath()
    }

    // Hands: hour hand towards 10, minute hand towards 2.
    ctx.setStrokeColor(color(0x1E2F73))
    ctx.setLineCap(.round)
    func hand(angle: CGFloat, length: CGFloat, width: CGFloat) {
        ctx.setLineWidth(width)
        ctx.move(to: center)
        ctx.addLine(to: CGPoint(x: center.x + cos(angle) * length, y: center.y + sin(angle) * length))
        ctx.strokePath()
    }
    hand(angle: .pi / 2 + .pi / 3, length: 105, width: 26)
    hand(angle: .pi / 2 - .pi / 3, length: 150, width: 20)
    ctx.setFillColor(color(0x1E2F73))
    ctx.fillEllipse(in: CGRect(x: center.x - 20, y: center.y - 20, width: 40, height: 40))

    // Timeline blocks on the right.
    let bars: [(y: CGFloat, width: CGFloat, hex: UInt32)] = [
        (610, 150, 0xFFB547), (500, 200, 0x5BE0A5), (390, 120, 0xFF7A8A),
    ]
    for bar in bars {
        let rect = CGRect(x: 660, y: bar.y, width: bar.width, height: 70)
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: -5), blur: 10, color: color(0x0A1A4A, 0.3))
        ctx.setFillColor(color(bar.hex))
        ctx.addPath(CGPath(roundedRect: rect, cornerWidth: 22, cornerHeight: 22, transform: nil))
        ctx.fillPath()
        ctx.restoreGState()
    }
}

func render(pixels: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    let context = NSGraphicsContext(bitmapImageRep: rep)!
    context.cgContext.interpolationQuality = .high
    context.cgContext.scaleBy(x: CGFloat(pixels) / canvas, y: CGFloat(pixels) / canvas)
    draw(in: context.cgContext)
    return rep.representation(using: .png, properties: [:])!
}

guard CommandLine.arguments.count == 2 else {
    FileHandle.standardError.write(Data("usage: generate-app-icon.swift <output-dir>\n".utf8))
    exit(1)
}
let output = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
for size in sizes {
    try render(pixels: size).write(to: output.appendingPathComponent("icon_\(size).png"))
}
print("Wrote \(sizes.count) icons to \(output.path)")
