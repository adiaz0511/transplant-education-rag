import SwiftUI

struct OnboardingIntroView: View {
    let isMovingForward: Bool
    let action: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(spacing: 12) {
                        IntroSymbolBubble(systemName: "book.closed.fill")
                        IntroSymbolBubble(systemName: "heart.text.square.fill")
                        IntroSymbolBubble(systemName: "checklist.checked")
                    }

                    Text("Learn heart transplant care one chapter at a time")
                        .font(.system(size: 42, weight: .heavy, design: .rounded))

                    Text("Transplant Guide turns the hospital teaching manual into focused lessons and optional quizzes, so families can learn what matters most in the order they choose.")
                        .font(.title3)
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 14) {
                        IntroLine(
                            systemName: "square.stack.3d.up.fill",
                            text: "Choose chapters directly from the manual"
                        )
                        IntroLine(
                            systemName: "arrow.up.arrow.down.circle.fill",
                            text: "Arrange them in the order your family needs"
                        )
                        IntroLine(
                            systemName: "sparkles.rectangle.stack.fill",
                            text: "Get lessons one at a time, with quizzes only when requested"
                        )
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: 760, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .background(OnboardingGradientBackground())
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            BottomPrimaryButton(
                title: "Choose Topics",
                isMovingForward: isMovingForward,
                action: action
            )
        }
    }
}

private struct IntroSymbolBubble: View {
    let systemName: String

    var body: some View {
        Image(systemName: systemName)
            .font(.title2.weight(.bold))
            .foregroundStyle(Color(red: 0.15, green: 0.45, blue: 0.84))
            .frame(width: 52, height: 52)
            .background(Color.white.opacity(0.82), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct IntroLine: View {
    let systemName: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemName)
                .font(.headline)
                .foregroundStyle(Color(red: 0.17, green: 0.58, blue: 0.31))
                .frame(width: 20)

            Text(text)
                .font(.body)
                .foregroundStyle(.secondary)
        }
    }
}
