#!/usr/bin/env swift
// Generates the Timelane app icon at every macOS size, and optionally the menu bar icon
// (the same clock as a template image, so the menu bar and the app icon match).
// Usage: swift Tools/generate-app-icon.swift <appiconset-dir> [<menubar-imageset-dir>]
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

/// The clock alone, centred on (512, 512) with an outer radius of 280.
func drawClock(in ctx: CGContext, color clock: CGColor) {
    let center = CGPoint(x: 512, y: 512)
    let ringWidth: CGFloat = 60
    let outerRadius: CGFloat = 280
    ctx.setStrokeColor(clock)
    ctx.setLineWidth(ringWidth)
    ctx.strokeEllipse(in: CGRect(x: center.x - outerRadius + ringWidth / 2, y: center.y - outerRadius + ringWidth / 2,
                                 width: (outerRadius - ringWidth / 2) * 2, height: (outerRadius - ringWidth / 2) * 2))

    // Hands at 10:10 with round caps, plus centre dot.
    ctx.setLineCap(.round)
    func hand(angle: CGFloat, length: CGFloat, width: CGFloat) {
        ctx.setLineWidth(width)
        ctx.move(to: center)
        ctx.addLine(to: CGPoint(x: center.x + cos(angle) * length, y: center.y + sin(angle) * length))
        ctx.strokePath()
    }
    hand(angle: .pi / 2 + .pi / 3, length: 125, width: 50)  // hour hand towards 10
    hand(angle: .pi / 2 - .pi / 3, length: 170, width: 44)  // minute hand towards 2
    ctx.setFillColor(clock)
    // Large enough to cover the joint of both hands, so the centre reads as one smooth dot.
    ctx.fillEllipse(in: CGRect(x: center.x - 42, y: center.y - 42, width: 84, height: 84))
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

guard (2...3).contains(CommandLine.arguments.count) else {
    FileHandle.standardError.write(Data("usage: generate-app-icon.swift <appiconset-dir> [<menubar-imageset-dir>]\n".utf8))
    exit(1)
}
let output = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
for size in sizes {
    try appIcon(pixels: size).write(to: output.appendingPathComponent("icon_\(size).png"))
}
print("Wrote \(sizes.count) icons to \(output.path)")

if CommandLine.arguments.count == 3 {
    let menuBar = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
    try FileManager.default.createDirectory(at: menuBar, withIntermediateDirectories: true)
    try menuBarIcon(pixels: 18).write(to: menuBar.appendingPathComponent("menubar_18.png"))
    try menuBarIcon(pixels: 36).write(to: menuBar.appendingPathComponent("menubar_36.png"))
    print("Wrote menu bar icon to \(menuBar.path)")
}
