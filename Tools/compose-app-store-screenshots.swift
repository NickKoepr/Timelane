#!/usr/bin/env swift
// Puts the captures of Tools/make-app-store-screenshots.sh on 2880 x 1800 App Store images in the style of the
// app icon: flat icon blue, the icon's white clock and one short title.
// Usage: swift Tools/compose-app-store-screenshots.swift <raw-dir> <output-dir>
import AppKit

let size = CGSize(width: 2880, height: 1800)
let backgroundHex: UInt32 = 0x2F6BEA   // same as Tools/generate-app-icon.swift

/// Scene, file name and title, in App Store order.
let shots: [(scene: String, file: String, title: String)] = [
    ("timeline", "01-timeline", "See where your working day went"),
    ("entryForm", "02-log-hours", "Log your hours in seconds"),
    ("menuBar", "03-menu-bar", "Always at hand in the menu bar"),   // drawn on two lines, see drawMenuBarScene
    ("projects", "04-projects", "Monthly totals for every project"),
    ("overview", "05-overview", "Your year at a glance"),
    ("trackedApps", "06-tracked-apps", "You decide which apps are tracked"),
    ("settings", "07-icloud-backup", "Backed up to your own iCloud"),
]

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

/// The icon's clock (ring + hands at 10:10), centred on `center`, `radius` = outer radius.
func drawClock(in ctx: CGContext, center: CGPoint, radius: CGFloat, color clock: CGColor) {
    let scale = radius / 280
    let ring = 60 * scale
    ctx.saveGState()
    ctx.setStrokeColor(clock)
    ctx.setFillColor(clock)
    ctx.setLineWidth(ring)
    ctx.strokeEllipse(in: CGRect(x: center.x - radius + ring / 2, y: center.y - radius + ring / 2,
                                 width: (radius - ring / 2) * 2, height: (radius - ring / 2) * 2))
    ctx.setLineCap(.round)
    for (angle, length, width) in [(CGFloat.pi / 2 + .pi / 3, 125.0, 50.0), (.pi / 2 - .pi / 3, 170, 44)] {
        ctx.setLineWidth(width * scale)
        ctx.move(to: center)
        ctx.addLine(to: CGPoint(x: center.x + cos(angle) * length * scale, y: center.y + sin(angle) * length * scale))
        ctx.strokePath()
    }
    ctx.fillEllipse(in: CGRect(x: center.x - 42 * scale, y: center.y - 42 * scale, width: 84 * scale, height: 84 * scale))
    ctx.restoreGState()
}

func titleString(_ text: String, size: CGFloat) -> NSAttributedString {
    NSAttributedString(string: text, attributes: [
        .font: NSFont.systemFont(ofSize: size, weight: .semibold),
        .foregroundColor: NSColor.white,
        .kern: -0.5,
    ])
}

/// Clock + title as one line, centred horizontally, with its vertical middle at `midY`.
func drawTitle(_ text: String, in ctx: CGContext, centerX: CGFloat, midY: CGFloat) {
    let title = titleString(text, size: 96)
    let textSize = title.size()
    let clock: CGFloat = 46, gap: CGFloat = 34
    let width = clock * 2 + gap + textSize.width
    let left = centerX - width / 2
    drawClock(in: ctx, center: CGPoint(x: left + clock, y: midY), radius: clock, color: .white)
    title.draw(at: CGPoint(x: left + clock * 2 + gap, y: midY - textSize.height / 2 + 6))
}

/// `image` scaled to fit `box` (centred horizontally, aligned to the top of the box), with a soft shadow.
func drawWindow(_ image: CGImage, in ctx: CGContext, box: CGRect) {
    let scale = min(box.width / CGFloat(image.width), box.height / CGFloat(image.height))
    let width = CGFloat(image.width) * scale, height = CGFloat(image.height) * scale
    let rect = CGRect(x: box.midX - width / 2, y: box.maxY - height, width: width, height: height)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -24), blur: 80, color: color(0x0A1F5C, 0.45))
    ctx.interpolationQuality = .high
    ctx.draw(image, in: rect)
    ctx.restoreGState()
}

/// Flat icon blue with a barely visible lighter top, so large areas don't look dull.
func drawBackground(in ctx: CGContext) {
    ctx.setFillColor(color(backgroundHex))
    ctx.fill(CGRect(origin: .zero, size: size))
    let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                              colors: [color(0xFFFFFF, 0.10), color(0xFFFFFF, 0)] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: size.height), end: CGPoint(x: 0, y: size.height * 0.45), options: [])
}

/// Menu bar image: a slim menu bar with the clock icon highlighted, the panel hanging under it, title on the left.
func drawMenuBarScene(_ panel: CGImage, in ctx: CGContext) {
    let barHeight: CGFloat = 72
    ctx.setFillColor(color(0xFFFFFF, 0.22))
    ctx.fill(CGRect(x: 0, y: size.height - barHeight, width: size.width, height: barHeight))

    let panelScale: CGFloat = 1.25
    let panelWidth = CGFloat(panel.width) * panelScale, panelHeight = CGFloat(panel.height) * panelScale
    let iconX: CGFloat = 2050
    let iconY = size.height - barHeight / 2
    ctx.setFillColor(color(0xFFFFFF, 0.3))
    ctx.addPath(CGPath(roundedRect: CGRect(x: iconX - 40, y: iconY - 26, width: 80, height: 52),
                       cornerWidth: 12, cornerHeight: 12, transform: nil))
    ctx.fillPath()
    drawClock(in: ctx, center: CGPoint(x: iconX, y: iconY), radius: 19, color: .white)

    let panelRect = CGRect(x: iconX - panelWidth / 2, y: size.height - barHeight - 14 - panelHeight,
                           width: panelWidth, height: panelHeight)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -24), blur: 80, color: color(0x0A1F5C, 0.45))
    ctx.interpolationQuality = .high
    ctx.draw(panel, in: panelRect)
    ctx.restoreGState()

    // Title on the left, two lines, vertically centred on the panel.
    let lines = ["Always at hand", "in the menu bar"]
    let font: CGFloat = 112
    let clock: CGFloat = 56
    let left: CGFloat = 240
    let lineHeight = font * 1.2
    let blockTop = panelRect.midY + (clock * 2 + 60 + lineHeight * CGFloat(lines.count)) / 2
    drawClock(in: ctx, center: CGPoint(x: left + clock, y: blockTop - clock), radius: clock, color: .white)
    for (index, line) in lines.enumerated() {
        let string = titleString(line, size: font)
        string.draw(at: CGPoint(x: left, y: blockTop - clock * 2 - 60 - lineHeight * CGFloat(index + 1)))
    }
}

func compose(scene: String, title: String, raw: URL) throws -> Data {
    guard let source = NSImage(contentsOf: raw.appendingPathComponent("\(scene).png"))?
        .cgImage(forProposedRect: nil, context: nil, hints: nil) else {
        throw CocoaError(.fileReadNoSuchFile, userInfo: [NSFilePathErrorKey: "\(scene).png"])
    }
    // RGB without alpha: App Store Connect rejects screenshots with an alpha channel.
    let ctx = CGContext(data: nil, width: Int(size.width), height: Int(size.height), bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
    drawBackground(in: ctx)
    if scene == "menuBar" {
        drawMenuBarScene(source, in: ctx)
    } else {
        drawTitle(title, in: ctx, centerX: size.width / 2, midY: size.height - 170)
        drawWindow(source, in: ctx, box: CGRect(x: 200, y: 110, width: size.width - 400, height: size.height - 110 - 330))
    }
    NSGraphicsContext.current = nil
    return NSBitmapImageRep(cgImage: ctx.makeImage()!).representation(using: .png, properties: [:])!
}

guard CommandLine.arguments.count == 3 else {
    FileHandle.standardError.write(Data("usage: compose-app-store-screenshots.swift <raw-dir> <output-dir>\n".utf8))
    exit(1)
}
let raw = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let output = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
for shot in shots {
    try compose(scene: shot.scene, title: shot.title, raw: raw).write(to: output.appendingPathComponent("\(shot.file).png"))
    print("Wrote \(shot.file).png")
}
