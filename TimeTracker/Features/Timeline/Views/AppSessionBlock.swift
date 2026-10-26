import SwiftUI

struct AppSessionBlock: View {
    let block: AppSessionBlockModel
    let height: CGFloat
    let width: CGFloat
    let selectionDrag: SelectionDragGesture
    let onSelect: (AppSessionBlockModel) -> Void

    private var tint: Color { StableColor.color(for: block.bundleIdentifier) }
    private var style: SessionLabelStyle { .style(forHeight: height, width: width) }

    var body: some View {
        AppSessionBlockLabel(block: block, style: style, height: height)
        .padding(.leading, 7)
        .padding(.trailing, 4)
        .frame(maxWidth: .infinity, minHeight: height, maxHeight: height, alignment: .topLeading)
        .background(tint.opacity(0.28), in: RoundedRectangle(cornerRadius: 5))
        .overlay(alignment: .leading) { Rectangle().fill(tint).frame(width: 3).clipShape(RoundedRectangle(cornerRadius: 2)) }
        .clipped()
        .contentShape(Rectangle())
        .onTapGesture { onSelect(block) }
        .simultaneousGesture(selectionDrag)   // a drag starting here selects a range; a click assigns the session
        .help("\(block.appName)\n\(block.start.formatted(date: .omitted, time: .shortened)) – \(block.end.formatted(date: .omitted, time: .shortened))")
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(block.appName), \(DurationFormatter.short(block.duration))")
    }
}
