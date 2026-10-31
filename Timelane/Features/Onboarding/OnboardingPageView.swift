import SwiftUI

/// The centre of the carousel: icon, title and message of one page.
struct OnboardingPageView: View {
    let page: OnboardingPage

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: page.systemImage)
                .font(.system(size: 56))
                .foregroundStyle(Color.accentColor)
                .frame(height: 70)
                .accessibilityHidden(true)
            Text(page.title).font(.title2.bold())
            Text(page.message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    OnboardingPageView(page: OnboardingPage.all[3]).frame(width: 520, height: 300)
}
