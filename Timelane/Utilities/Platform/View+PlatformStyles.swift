import SwiftUI

/// Small per-platform differences of otherwise shared views.
extension View {
    /// Radio buttons on the Mac; the inline list on iOS.
    func exportFormatPickerStyle() -> some View {
        #if os(macOS)
        pickerStyle(.radioGroup)
        #else
        pickerStyle(.inline)
        #endif
    }

    /// The resize cursor over the top/bottom edge of an entry; touch screens have no pointer.
    func rowResizePointer() -> some View {
        #if os(macOS)
        pointerStyle(.rowResize)
        #else
        self
        #endif
    }
}
