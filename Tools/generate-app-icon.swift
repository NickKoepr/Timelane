#!/usr/bin/env swift
// Generates the Timelane app icon at every macOS size, and optionally the menu bar icon and the clock mark
// (the same clock as template images: a PNG for the menu bar, an SVG for in-app use), so they all match.
// Usage: swift Tools/generate-app-icon.swift <appiconset-dir> [<menubar-imageset-dir> [<clockmark-imageset-dir>]]
import AppKit

let canvas: CGFloat = 1024
let sizes = [16, 32, 64, 128, 256, 512, 1024]

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

/// Flat background colour of the icon body. Change this to recolour the icon.
let backgroundHex: UInt32 = 0x2F6BEA
let clockHex: UInt32 = 0xFFFFFF

/// Draws the icon on a 1024 x 1024 canvas (origin bottom-left): flat colour body, white clock.
/// `scale` is the CTM scale to the output size: shadow offset and blur are in device space and ignore the CTM.
func draw(in ctx: CGContext, scale: CGFloat = 1) {
    let body = CGRect(x: 100, y: 100, width: 824, height: 824)
    let bodyPath = CGPath(roundedRect: body, cornerWidth: 185, cornerHeight: 185, transform: nil)

    // Flat body with a soft drop shadow (no gradient, no sheen).
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -12 * scale), blur: 28 * scale, color: color(0x000000, 0.35))
    ctx.setFillColor(color(backgroundHex))
    ctx.addPath(bodyPath)
    ctx.fillPath()
    ctx.restoreGState()

    drawClock(in: ctx, color: color(clockHex))
}

/// Clock geometry on the 1024 canvas, shared by the bitmap drawing and the SVG.
let clockCenter = CGPoint(x: 512, y: 512)
let ringWidth: CGFloat = 60
let outerRadius: CGFloat = 280
/// Hands at 10:10 (angles counter-clockwise from 3 o'clock): hour hand towards 10, minute hand towards 2.
let clockHands: [(angle: CGFloat, length: CGFloat, width: CGFloat)] = [
    (.pi / 2 + .pi / 3, 125, 50),
    (.pi / 2 - .pi / 3, 170, 44),
]
/// Large enough to cover the joint of both hands, so the centre reads as one smooth dot.
let centreDotRadius: CGFloat = 42

/// The clock alone, centred on (512, 512) with an outer radius of 280.
func drawClock(in ctx: CGContext, color clock: CGColor) {
    let center = clockCenter
    ctx.setStrokeColor(clock)
    ctx.setLineWidth(ringWidth)
    ctx.strokeEllipse(in: CGRect(x: center.x - outerRadius + ringWidth / 2, y: center.y - outerRadius + ringWidth / 2,
                                 width: (outerRadius - ringWidth / 2) * 2, height: (outerRadius - ringWidth / 2) * 2))

    // Hands with round caps, plus centre dot.
    ctx.setLineCap(.round)
    for hand in clockHands {
        ctx.setLineWidth(hand.width)
        ctx.move(to: center)
        ctx.addLine(to: CGPoint(x: center.x + cos(hand.angle) * hand.length, y: center.y + sin(hand.angle) * hand.length))
        ctx.strokePath()
    }
    ctx.setFillColor(clock)
    ctx.fillEllipse(in: CGRect(x: center.x - centreDotRadius, y: center.y - centreDotRadius,
                               width: centreDotRadius * 2, height: centreDotRadius * 2))
}

/// The clock as a black SVG cropped to its outer circle (y flipped: SVG's origin is top-left).
func clockSVG() -> Data {
    func n(_ value: CGFloat) -> String { String(format: "%.2f", value) }
    let c = CGPoint(x: clockCenter.x, y: canvas - clockCenter.y)
    let hands = clockHands.map { hand in
        "<line x1=\"\(n(c.x))\" y1=\"\(n(c.y))\" x2=\"\(n(c.x + cos(hand.angle) * hand.length))\" "
            + "y2=\"\(n(c.y - sin(hand.angle) * hand.length))\" stroke-width=\"\(n(hand.width))\"/>"
    }
    let svg = """
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="\(n(c.x - outerRadius)) \(n(c.y - outerRadius)) \(n(outerRadius * 2)) \(n(outerRadius * 2))">
      <g stroke="#000" fill="none" stroke-linecap="round">
        <circle cx="\(n(c.x))" cy="\(n(c.y))" r="\(n(outerRadius - ringWidth / 2))" stroke-width="\(n(ringWidth))"/>
        \(hands.joined(separator: "\n    "))
      </g>
      <circle cx="\(n(c.x))" cy="\(n(c.y))" r="\(n(centreDotRadius))"/>
    </svg>

    """
    return Data(svg.utf8)
}

func render(pixels: Int, drawing: (CGContext) -> Void) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    let context = NSGraphicsContext(bitmapImageRep: rep)!
    context.cgContext.interpolationQuality = .high
    drawing(context.cgContext)
    return rep.representation(using: .png, properties: [:])!
}

/// App icon at `pixels` x `pixels`.
func appIcon(pixels: Int) -> Data {
    render(pixels: pixels) { ctx in
        let scale = CGFloat(pixels) / canvas
        ctx.scaleBy(x: scale, y: scale)
        draw(in: ctx, scale: scale)
    }
}

/// Menu bar template image: the clock in black on transparent, 16 of 18 points tall.
func menuBarIcon(pixels: Int) -> Data {
    render(pixels: pixels) { ctx in
        let scale = CGFloat(pixels) * 16 / 18 / 560
        ctx.translateBy(x: CGFloat(pixels) / 2, y: CGFloat(pixels) / 2)
        ctx.scaleBy(x: scale, y: scale)
        ctx.translateBy(x: -512, y: -512)
        drawClock(in: ctx, color: color(0x000000))
    }
}

guard (2...4).contains(CommandLine.arguments.count) else {
    FileHandle.standardError.write(Data(
        "usage: generate-app-icon.swift <appiconset-dir> [<menubar-imageset-dir> [<clockmark-imageset-dir>]]\n".utf8))
    exit(1)
}
let output = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
for size in sizes {
    try appIcon(pixels: size).write(to: output.appendingPathComponent("icon_\(size).png"))
}
print("Wrote \(sizes.count) icons to \(output.path)")

if CommandLine.arguments.count >= 3 {
    let menuBar = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
    try FileManager.default.createDirectory(at: menuBar, withIntermediateDirectories: true)
    try menuBarIcon(pixels: 18).write(to: menuBar.appendingPathComponent("menubar_18.png"))
    try menuBarIcon(pixels: 36).write(to: menuBar.appendingPathComponent("menubar_36.png"))
    print("Wrote menu bar icon to \(menuBar.path)")
}

if CommandLine.arguments.count == 4 {
    let clockMark = URL(fileURLWithPath: CommandLine.arguments[3], isDirectory: true)
    try FileManager.default.createDirectory(at: clockMark, withIntermediateDirectories: true)
    try clockSVG().write(to: clockMark.appendingPathComponent("clockmark.svg"))
    let contents = """
    {
      "images" : [
        { "filename" : "clockmark.svg", "idiom" : "universal" }
      ],
      "info" : { "author" : "xcode", "version" : 1 },
      "properties" : { "preserves-vector-representation" : true, "template-rendering-intent" : "template" }
    }

    """
    try Data(contents.utf8).write(to: clockMark.appendingPathComponent("Contents.json"))
    print("Wrote clock mark to \(clockMark.path)")
}
