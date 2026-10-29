import AppKit
import SwiftUI
import Testing
@testable import Timelane

@MainActor
struct InfoPopoverTextTests {
    @Test func popoverFitsTheFullWrappedText() {
        let text = "Hours are logged automatically to this project while you use the app. Changing it only affects new hours."
        // The info icon sits in a List section header, which limits text to one line.
        let hosting = NSHostingView(rootView: InfoPopoverText(text: text).lineLimit(1))
        let size = hosting.fittingSize

        let font = NSFont.preferredFont(forTextStyle: .callout)
        let rect = (text as NSString).boundingRect(
            with: NSSize(width: InfoPopoverText.width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font])

        #expect(size.width == InfoPopoverText.width + 2 * InfoPopoverText.padding)
        #expect(size.height >= rect.height.rounded(.down) + 2 * InfoPopoverText.padding)
    }
}
