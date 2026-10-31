import AppKit

/// Timelane ▸ About Timelane: the standard About panel with links to the website, source and issue tracker.
enum AboutPanel {
    static let links: [(title: String, url: URL)] = [
        ("Website", URL(string: "https://timelane.nickkoepr.nl")!),
        ("GitHub", URL(string: "https://github.com/NickKoepr/Timelane")!),
        ("Report an issue", URL(string: "https://github.com/NickKoepr/Timelane/issues")!),
    ]

    @MainActor static func show() {
        NSApp.activate()
        NSApp.orderFrontStandardAboutPanel(options: [.credits: credits()])
    }

    /// One centred line per link, in the panel's small system font.
    static func credits() -> NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.paragraphSpacing = 4
        let font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        let text = NSMutableAttributedString()
        for (index, link) in links.enumerated() {
            if index > 0 { text.append(NSAttributedString(string: "\n")) }
            text.append(NSAttributedString(string: link.title, attributes: [.link: link.url, .font: font]))
        }
        text.addAttribute(.paragraphStyle, value: paragraph, range: NSRange(location: 0, length: text.length))
        return text
    }
}
