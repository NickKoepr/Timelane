#if os(iOS)
import SwiftUI

/// Day navigation for touch: ‹ date › and Today on the first line, the registered total under it.
/// (Swiping the timeline sideways also changes the day.)
struct IOSDayBar: View {
    let viewModel: TimelineViewModel

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                Button { viewModel.goToPreviousDay() } label: { Image(systemName: "chevron.left").frame(width: 36, height: 36) }
                    .accessibilityLabel("Previous day")
                HStack(spacing: 2) {
                    Text(viewModel.shortTitle).font(.headline).lineLimit(1).minimumScaleFactor(0.8)
                    DayDatePicker(viewModel: viewModel)
                }
                Button { viewModel.goToNextDay() } label: { Image(systemName: "chevron.right").frame(width: 36, height: 36) }
                    .accessibilityLabel("Next day")
                Spacer(minLength: 8)
                Button("Today") { viewModel.goToToday() }
                    .buttonStyle(.bordered)
                    .disabled(viewModel.isToday)
            }
            HStack {
                Text("Registered").foregroundStyle(.secondary)
                Text(DurationFormatter.hoursMinutes(viewModel.registeredTotal)).fontWeight(.semibold)
                Spacer()
            }
            .font(.callout.monospacedDigit())
            .padding(.leading, 8)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
    }
}

#Preview {
    let environment = AppEnvironment.preview()
    IOSDayBar(viewModel: TimelineViewModel(environment: environment))
}
#endif
