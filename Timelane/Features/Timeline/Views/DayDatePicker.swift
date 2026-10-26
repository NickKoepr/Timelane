import SwiftUI

struct DayDatePicker: View {
    let viewModel: TimelineViewModel

    var body: some View {
        DatePicker("Day", selection: Binding(get: { viewModel.day.start }, set: { viewModel.go(to: $0) }),
                   displayedComponents: .date)
            .labelsHidden()
            .datePickerStyle(.compact)
            .fixedSize()
    }
}
