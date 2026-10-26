import SwiftUI

struct ProjectsTotalFooter: View {
    @Binding var showArchived: Bool
    let total: TimeInterval

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            HStack {
                Toggle("Show archived", isOn: $showArchived)
                    .toggleStyle(.checkbox)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 8)
            HStack {
                Text("Total").font(.headline)
                Spacer()
                Text(DurationFormatter.hoursMinutes(total))
                    .font(.headline.monospacedDigit())
            }
            .padding()
        }
        .background(.bar)
    }
}

#Preview {
    ProjectsTotalFooter(showArchived: .constant(false), total: 66 * 3600 + 45 * 60)
}
