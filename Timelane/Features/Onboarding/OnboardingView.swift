import SwiftUI

/// The skippable welcome carousel, shown as a sheet on the main window.
struct OnboardingView: View {
    @State var viewModel: OnboardingViewModel
    let onClose: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let width: CGFloat = 520

    var body: some View {
        VStack(spacing: 0) {
            topBar
            pages
            bottomBar
        }
        .frame(width: width, height: 400)
        .focusable()
        .focusEffectDisabled()
        .onKeyPress(.leftArrow) { viewModel.back(); return .handled }
        .onKeyPress(.rightArrow) { viewModel.next(); return .handled }
    }

    /// All pages side by side, shifted by the current index: the slide direction always follows the index.
    /// (A per-page `.transition` slid the wrong way after changing direction, because the leaving page
    /// keeps the transition of its previous render.)
    private var pages: some View {
        HStack(spacing: 0) {
            ForEach(Array(viewModel.pages.enumerated()), id: \.element.id) { index, page in
                OnboardingPageView(page: page)
                    .frame(width: width)
                    .accessibilityHidden(index != viewModel.currentIndex)
            }
        }
        .offset(x: -CGFloat(viewModel.currentIndex) * width)
        .frame(width: width, alignment: .leading)
        .clipped()
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: viewModel.currentIndex)
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
            Button("Back") { viewModel.back() }
                .disabled(viewModel.isFirst)
                .frame(width: 110, alignment: .leading)
            Spacer()
            OnboardingPageDots(count: viewModel.pages.count, current: viewModel.currentIndex) { index in
                viewModel.go(to: index)
            }
            Spacer()
            if viewModel.isLast {
                Button("Get Started") { close() }
                    .keyboardShortcut(.defaultAction)
                    .frame(width: 110, alignment: .trailing)
            } else {
                Button("Next") { viewModel.next() }
                    .keyboardShortcut(.defaultAction)
                    .frame(width: 110, alignment: .trailing)
            }
        }
        .padding(20)
    }

    private func close() {
        viewModel.finish()
        onClose()
    }
}

#Preview {
    OnboardingView(viewModel: OnboardingViewModel(store: .temporary()), onClose: {})
}
