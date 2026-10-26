import SwiftUI

/// From / To pickers with the resulting duration and an inline error.
struct TimeEntryFormTimeFields: View {
    @Binding var form: TimeEntryForm

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 16) {
                DatePicker("From", selection: $form.start, displayedComponents: .hourAndMinute)
                DatePicker("To", selection: $form.end, displayedComponents: .hourAndMinute)
                Spacer(minLength: 0)
                Text(form.timeError == nil ? DurationFormatter.hoursMinutes(form.duration) : "–")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            if let error = form.timeError {
                Text(error).font(.caption).foregroundStyle(.red)
            }
        }
    }
}

#Preview {
    @Previewable @State var form = TimeEntryForm.new(range: DateRange(start: .now, end: .now.addingTimeInterval(3600)), projectId: nil)
    TimeEntryFormTimeFields(form: $form).padding().frame(width: 420)
}
