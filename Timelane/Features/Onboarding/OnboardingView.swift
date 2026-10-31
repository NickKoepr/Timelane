import SwiftUI

/// The skippable welcome carousel, shown as a sheet on the main window.
struct OnboardingView: View {
    @State var viewModel: OnboardingViewModel
    let onClose: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var goingForward = true

    var body: some View {
        VStack(spacing: 0) {
            topBar
            ZStack {
                OnboardingPageView(page: viewModel.currentPage)
                    .id(viewModel.currentPage.id)
                    .transition(reduceMotion ? .opacity : .push(from: goingForward ? .trailing : .leading))
            }
            .clipped()
            .animation(reduceMotion ? .easeOut(duration: 0.15) : .easeInOut(duration: 0.25), value: viewModel.currentIndex)
            bottomBar
        }
        .frame(width: 520, height: 400)
        .focusable()
        .focusEffectDisabled()
        .onKeyPress(.leftArrow) { move { viewModel.back() }; return .handled }
        .onKeyPress(.rightArrow) { move { viewModel.next() }; return .handled }
    }

    private var topBar: some View {
        HStack {
            Spacer()
            Button("Skip") { close() }
                .keyboardShortcut(.cancelAction)
                .opacity(viewModel.isLast ? 0 : 1)
                .disabled(viewModel.isLast)
        }
        .padding([.top, .horizontal], 16)
        .frame(height: 44)
    }

    private var bottomBar: some View {
        HStack {
            Button("Back") { move { viewModel.back() } }
                .disabled(viewModel.isFirst)
                .frame(width: 110, alignment: .leading)
            Spacer()
            OnboardingPageDots(count: viewModel.pages.count, current: viewModel.currentIndex) { index in
                move { viewModel.go(to: index) }
            }
            Spacer()
            if viewModel.isLast {
                Button("Get Started") { close() }
                    .keyboardShortcut(.defaultAction)
                    .frame(width: 110, alignment: .trailing)
            } else {
                Button("Next") { move { viewModel.next() } }
                    .keyboardShortcut(.defaultAction)
                    .frame(width: 110, alignment: .trailing)
            }
        }
        .padding(20)
    }

    private func move(_ change: () -> Void) {
        let before = viewModel.currentIndex
        change()
        goingForward = viewModel.currentIndex >= before
    }

    private func close() {
        viewModel.finish()
        onClose()
    }
}

#Preview {
    OnboardingView(viewModel: OnboardingViewModel(store: .temporary()), onClose: {})
}
