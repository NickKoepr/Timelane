import SwiftUI

/// One weekday in Settings ▸ Notifications: a checkbox with the day's name, and the time of its reminder.
struct ReminderDayRow: View {
    let name: String
    @Binding var isOn: Bool
    @Binding var time: Date

    var body: some View {
        HStack {
            Toggle(name, isOn: $isOn)
                .toggleStyle(.checkbox)
            Spacer()
            DatePicker("Reminder time on \(name)", selection: $time, displayedComponents: .hourAndMinute)
                .labelsHidden()
                .disabled(!isOn)
        }
    }
}

#Preview {
    @Previewable @State var monday = true
    @Previewable @State var sunday = false
    @Previewable @State var time = Calendar.current.date(bySettingHour: 17, minute: 0, second: 0, of: .now) ?? .now
    Form {
        ReminderDayRow(name: "Monday", isOn: $monday, time: $time)
        ReminderDayRow(name: "Sunday", isOn: $sunday, time: $time)
    }
    .formStyle(.grouped)
    .frame(width: 460)
}
