import SwiftUI

/// The centre of the carousel: icon, title and message of one page.
struct OnboardingPageView: View {
    let page: OnboardingPage

    var body: some View {
        VStack(spacing: 14) {
            icon
                .foregroundStyle(Color.accentColor)
                .frame(height: 70)
                .accessibilityHidden(true)
            Text(page.title).font(.title2.bold())
            // LocalizedStringKey renders the Markdown (bold, `⌘R` in monospace).
            Text(LocalizedStringKey(page.message))
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
            if let footnote = page.footnote {
                Text(LocalizedStringKey(footnote))
                    .font(.callout)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 6)
            }
        }
        .padding(.horizontal, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder private var icon: some View {
        switch page.icon {
        case .symbol(let name): Image(systemName: name).font(.system(size: 56))
        case .appClock: Image("ClockMark").resizable().frame(width: 64, height: 64)
        }
    }
}

#Preview {
    OnboardingPageView(page: OnboardingPage.all[5]).frame(width: 520, height: 300)
}
