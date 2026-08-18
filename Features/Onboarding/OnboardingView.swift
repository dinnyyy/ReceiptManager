import SwiftUI

/// Spec 5.2: "Explain the core promise in under one minute and create a
/// secure account." Three cards maximum, skippable straight to auth - this
/// is a vault, not an app that makes you sit through a tutorial.
struct OnboardingView: View {
    let onSignedIn: () -> Void

    @State private var page = 0
    @State private var showAuth = false

    private let cards: [OnboardingCard] = [
        OnboardingCard(
            systemImage: "camera.viewfinder",
            title: "Scan once",
            body: "Photograph a receipt or invoice and we'll read the merchant, date and total for you to confirm."
        ),
        OnboardingCard(
            systemImage: "magnifyingglass",
            title: "Find it later",
            body: "Search every purchase by merchant, amount, date or item, months or years after you bought it."
        ),
        OnboardingCard(
            systemImage: "doc.text.fill",
            title: "Proof Packs",
            body: "Generate a clean PDF and CSV for tax, warranty or insurance, ready to send whenever you need it."
        ),
    ]

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $page) {
                ForEach(cards.indices, id: \.self) { index in
                    OnboardingCardView(card: cards[index]).tag(index)
                }
            }
            .tabViewStyle(.page)
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            VStack(spacing: 12) {
                Button {
                    showAuth = true
                } label: {
                    Text(page == cards.count - 1 ? "Get started" : "Continue")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button("Skip") { showAuth = true }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .sheet(isPresented: $showAuth) {
            AuthView(onSignedIn: onSignedIn)
        }
    }
}

private struct OnboardingCard {
    let systemImage: String
    let title: String
    let body: String
}

private struct OnboardingCardView: View {
    let card: OnboardingCard

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: card.systemImage)
                .font(.system(size: 56))
                .foregroundStyle(.tint)
                .accessibilityHidden(true)
            Text(card.title)
                .font(.title.bold())
            Text(card.body)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
            Spacer()
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    OnboardingView(onSignedIn: {})
}
