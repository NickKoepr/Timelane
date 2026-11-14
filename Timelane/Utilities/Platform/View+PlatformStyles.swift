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

    /// A checkbox on the Mac; the standard switch on iOS.
    func checkboxToggleStyle() -> some View {
        #if os(macOS)
        toggleStyle(.checkbox)
        #else
        toggleStyle(.switch)
        #endif
    }

    /// A borderless menu button on the Mac; the default menu button on iOS.
    func borderlessMenuStyle() -> some View {
        #if os(macOS)
        menuStyle(.borderlessButton)
        #else
        menuStyle(.button)
        #endif
    }
}
