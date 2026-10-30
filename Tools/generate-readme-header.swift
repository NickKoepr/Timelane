#!/usr/bin/env swift
// Draws the README header (docs/header.png): app icon, name, tagline and key features on the left, the Timeline
// window with the menu bar panel on the right, in the style of the App Store images (flat icon blue, white text).
// Usage: swift Tools/generate-readme-header.swift <raw-dir> <app-icon-1024.png> <output.png>
// <raw-dir> holds the captures of Tools/make-app-store-screenshots.sh (timeline.png, menuBar.png).
import AppKit

let size = CGSize(width: 2400, height: 1000)
let cornerRadius: CGFloat = 48
let backgroundHex: UInt32 = 0x2F6BEA   // same as Tools/generate-app-icon.swift

let tagline = ["Register your working hours", "per project on your Mac."]
let features = [
    "Automatic timeline of the apps you work in",
    "Drag over the timeline to log hours",
    "Monthly totals, yearly overview, export",
    "Lives in your menu bar, stays on your Mac",
]

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

func loadImage(_ url: URL) throws -> CGImage {
    guard let image = NSImage(contentsOf: url)?.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
        throw CocoaError(.fileReadNoSuchFile, userInfo: [NSFilePathErrorKey: url.path])
    }
    return image
}

func text(_ string: String, size: CGFloat, weight: NSFont.Weight, alpha: CGFloat = 1) -> NSAttributedString {
    NSAttributedString(string: string, attributes: [
        .font: NSFont.systemFont(ofSize: size, weight: weight),
        .foregroundColor: NSColor.white.withAlphaComponent(alpha),
        .kern: -0.5,
    ])
}

/// Rounded card in icon blue with a barely visible lighter top; everything after this is clipped to the card.
func drawBackground(in ctx: CGContext) {
    ctx.addPath(CGPath(roundedRect: CGRect(origin: .zero, size: size), cornerWidth: cornerRadius,
                       cornerHeight: cornerRadius, transform: nil))
    ctx.clip()
    ctx.setFillColor(color(backgroundHex))
    ctx.fill(CGRect(origin: .zero, size: size))
    let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                              colors: [color(0xFFFFFF, 0.12), color(0xFFFFFF, 0)] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: size.height), end: CGPoint(x: 0, y: size.height * 0.4), options: [])
}

func drawShadowed(_ image: CGImage, in rect: CGRect, ctx: CGContext) {
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -20), blur: 70, color: color(0x0A1F5C, 0.5))
    ctx.interpolationQuality = .high
    ctx.draw(image, in: rect)
    ctx.restoreGState()
}

/// Icon + name on one line, tagline below it, then the feature list with white dots.
func drawText(icon: CGImage, in ctx: CGContext) {
    let left: CGFloat = 120
    let iconSize: CGFloat = 190
    let iconRect = CGRect(x: left - 14, y: size.height - 110 - iconSize, width: iconSize, height: iconSize)
    drawShadowed(icon, in: iconRect, ctx: ctx)

    let name = text("Timelane", size: 150, weight: .bold)
    let nameSize = name.size()
    name.draw(at: CGPoint(x: iconRect.maxX + 30, y: iconRect.midY - nameSize.height / 2 + 4))

    var y = iconRect.minY - 70
    for line in tagline {
        let string = text(line, size: 60, weight: .semibold)
        y -= string.size().height
        string.draw(at: CGPoint(x: left, y: y))
    }

    y -= 40
    ctx.setFillColor(color(0xFFFFFF, 0.9))
    for feature in features {
        let string = text(feature, size: 40, weight: .regular, alpha: 0.9)
        let height = string.size().height
        y -= height + 22
        ctx.fillEllipse(in: CGRect(x: left + 4, y: y + height / 2 - 8, width: 16, height: 16))
        string.draw(at: CGPoint(x: left + 44, y: y))
    }
}

/// Timeline window bleeding off the right and bottom edge, menu bar panel overlapping its lower-left corner.
func drawScreens(timeline: CGImage, panel: CGImage, in ctx: CGContext) {
    let windowScale: CGFloat = 0.58
    let windowRect = CGRect(x: 1200, y: size.height - 90 - CGFloat(timeline.height) * windowScale,
                            width: CGFloat(timeline.width) * windowScale, height: CGFloat(timeline.height) * windowScale)
    drawShadowed(timeline, in: windowRect, ctx: ctx)

    let panelScale: CGFloat = 0.66
    let panelSize = CGSize(width: CGFloat(panel.width) * panelScale, height: CGFloat(panel.height) * panelScale)
    let panelRect = CGRect(x: windowRect.minX - 150, y: -60, width: panelSize.width, height: panelSize.height)
    drawShadowed(panel, in: panelRect, ctx: ctx)
}

guard CommandLine.arguments.count == 4 else {
    FileHandle.standardError.write(Data("usage: generate-readme-header.swift <raw-dir> <app-icon-1024.png> <output.png>\n".utf8))
    exit(1)
}
let raw = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let timeline = try loadImage(raw.appendingPathComponent("timeline.png"))
let panel = try loadImage(raw.appendingPathComponent("menuBar.png"))
let icon = try loadImage(URL(fileURLWithPath: CommandLine.arguments[2]))

// With alpha: the corners outside the card stay transparent on both light and dark GitHub themes.
let ctx = CGContext(data: nil, width: Int(size.width), height: Int(size.height), bitsPerComponent: 8, bytesPerRow: 0,
                    space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
drawBackground(in: ctx)
drawScreens(timeline: timeline, panel: panel, in: ctx)
drawText(icon: icon, in: ctx)
NSGraphicsContext.current = nil
try NSBitmapImageRep(cgImage: ctx.makeImage()!).representation(using: .png, properties: [:])!
    .write(to: URL(fileURLWithPath: CommandLine.arguments[3]))
print("Wrote \(CommandLine.arguments[3])")
