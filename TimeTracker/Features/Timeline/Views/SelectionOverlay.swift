import SwiftUI

/// The translucent range shown while dragging; anchors the project picker popover afterwards.
struct SelectionOverlay: View {
    let viewModel: TimelineViewModel

    var body: some View {
        if let selection = viewModel.selection {
            let frame = viewModel.geometry.frame(for: selection.start, end: selection.end)
            RoundedRectangle(cornerRadius: 5)
                .fill(Color.accentColor.opacity(0.25))
                .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.accentColor, lineWidth: 1.5))
                .overlay(alignment: .topLeading) {
                    Text(selection.label)
                        .font(.caption.weight(.semibold).monospacedDigit())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                }
                .frame(height: max(frame.height, 2))
                .offset(y: frame.y)
                .popover(isPresented: pickerBinding, arrowEdge: .leading) {
                    if let picker = viewModel.picker { ProjectPickerPopover(viewModel: picker) }
                }
                .allowsHitTesting(false)
        }
    }

    private var pickerBinding: Binding<Bool> {
        Binding(get: { viewModel.picker != nil },
                set: { if !$0 { viewModel.cancelRegistration() } })
    }
}
