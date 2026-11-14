#if os(iOS)
import SwiftUI

/// The calendar behind the day bar's calendar button on iOS: a titled sheet with the month calendar at the top
/// (a popover becomes a sheet on iPhone anyway, and then showed the bare calendar centred without context).
struct IOSDayPickerSheet: View {
    @Binding var selection: Date
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                Text("Pick a day to show its hours on the timeline.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                DatePicker("Day", selection: $selection, displayedComponents: .date)
                    .labelsHidden()
                    .datePickerStyle(.graphical)
                Spacer(minLength: 0)
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .navigationTitle("Go to Day")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", systemImage: "xmark") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
    }
}

#Preview {
    @Previewable @State var day = Date.now
    Text("Timeline").sheet(isPresented: .constant(true)) { IOSDayPickerSheet(selection: $day) }
}
#endif
