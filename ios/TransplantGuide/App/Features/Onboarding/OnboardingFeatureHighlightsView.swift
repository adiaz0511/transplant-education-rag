import SwiftUI

struct OnboardingFeatureHighlightsView: View {
    var body: some View {
        VStack(spacing: 16) {
            OnboardingFeatureCard(
                title: "Choose from the real manual",
                detail: "Topics come directly from the Heart Transplant Teaching Manual. No free text and no guessing."
            )

            OnboardingFeatureCard(
                title: "Set your own priority",
                detail: "Rank chapters in the order you want lessons to appear on the home screen."
            )

            OnboardingFeatureCard(
                title: "Learn progressively",
                detail: "Lessons arrive one at a time, and quizzes only appear when you tap to generate them."
            )
        }
    }
}
