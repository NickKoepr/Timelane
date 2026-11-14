#if os(iOS)
import SwiftUI

/// The welcome carousel for iOS (full screen, swipeable). Same pages source and view model as the Mac; the pages are
/// filtered for the platform in `OnboardingPage`.
struct IOSOnboardingView: View {
    @State var viewModel: OnboardingViewModel
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button("Skip") { close() }
                    .opacity(viewModel.isLast ? 0 : 1)
                    .disabled(viewModel.isLast)
            }
            .padding()
            TabView(selection: Binding(get: { viewModel.currentIndex }, set: { viewModel.go(to: $0) })) {
                ForEach(Array(viewModel.pages.enumerated()), id: \.element.id) { index, page in
                    OnboardingPageView(page: page).tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            Button { viewModel.isLast ? close() : viewModel.next() } label: {
                Text(viewModel.isLast ? "Get Started" : "Next").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding([.horizontal, .bottom], 24)
        }
        .interactiveDismissDisabled()
    }

    private func close() {
        viewModel.finish()
        onClose()
    }
}

#Preview {
    IOSOnboardingView(viewModel: OnboardingViewModel(store: .temporary()), onClose: {})
}
#endif
