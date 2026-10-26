import SwiftUI

/// Calendar button next to the day title; opens a month calendar to jump to any day.
struct DayDatePicker: View {
    let viewModel: TimelineViewModel
    @State private var isPresented = false

    var body: some View {
        Button { isPresented.toggle() } label: { Image(systemName: "calendar") }
            .buttonStyle(.borderless)
            .help("Choose a day")
            .accessibilityLabel("Choose a day")
            .fixedSize()
            .popover(isPresented: $isPresented, arrowEdge: .bottom) {
                DatePicker("Day", selection: selection, displayedComponents: .date)
                    .labelsHidden()
                    .datePickerStyle(.graphical)
                    .padding(12)
            }
    }

    /// Picking a day shows it and closes the calendar.
    private var selection: Binding<Date> {
        Binding(get: { viewModel.day.start },
                set: { viewModel.go(to: $0); isPresented = false })
    }
}
