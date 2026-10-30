#if DEBUG
import AppKit

/// Captures the app's own windows. No Screen Recording permission is needed for a process's own windows.
enum WindowSnapshot {
    private typealias CreateImage = @convention(c) (CGRect, UInt32, UInt32, UInt32) -> Unmanaged<CGImage>?

    /// `CGWindowListCreateImage`, looked up at runtime: the Swift overlay marks it obsolete (in favour of
    /// ScreenCaptureKit, which always asks for permission), but the function still works.
    private static let createImage: CreateImage? = {
        guard let handle = dlopen("/System/Library/Frameworks/CoreGraphics.framework/CoreGraphics", RTLD_NOW),
              let symbol = dlsym(handle, "CGWindowListCreateImage") else { return nil }
        return unsafeBitCast(symbol, to: CreateImage.self)
    }()

    /// The window at full (Retina) resolution, without the system shadow.
    static func image(of window: NSWindow) -> CGImage? {
        let includingWindow: UInt32 = 1 << 3
        let ignoreFraming: UInt32 = 1 << 0, bestResolution: UInt32 = 1 << 3
        return createImage?(.null, includingWindow, UInt32(window.windowNumber), ignoreFraming | bestResolution)?
            .takeRetainedValue()
    }

    /// The windows (bottom first) drawn at their screen positions on one transparent image;
    /// windows above the first get a shadow, like on screen.
    static func combined(_ windows: [NSWindow]) -> CGImage? {
        let layers = windows.compactMap { window in image(of: window).map { (frame: window.frame, image: $0) } }
        guard let base = layers.first else { return nil }
        let scale = CGFloat(base.image.width) / base.frame.width
        let bounds = layers.dropFirst().reduce(base.frame) { $0.union($1.frame) }
        guard let context = CGContext(data: nil, width: Int(bounds.width * scale), height: Int(bounds.height * scale),
                                      bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        for (index, layer) in layers.enumerated() {
            let rect = CGRect(x: (layer.frame.minX - bounds.minX) * scale, y: (layer.frame.minY - bounds.minY) * scale,
                              width: layer.frame.width * scale, height: layer.frame.height * scale)
            context.saveGState()
            if index > 0 {
                context.setShadow(offset: CGSize(width: 0, height: -10 * scale), blur: 36 * scale,
                                  color: CGColor(gray: 0, alpha: 0.3))
            }
            context.draw(layer.image, in: rect)
            context.restoreGState()
        }
        return context.makeImage()
    }

    static func writePNG(_ image: CGImage, to url: URL) throws {
        guard let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else {
            throw CocoaError(.fileWriteUnknown)
        }
        try data.write(to: url)
    }
}
#endif
