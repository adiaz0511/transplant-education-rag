import SwiftUI
import SwiftData

struct QuizzesLibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(GenerationCoordinator.self) private var generationCoordinator

    let quizzes: [Quiz]
    let onOpenQuiz: (Quiz) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if quizzes.isEmpty {
                    placeholderCard(
                        title: "No quizzes yet",
                        detail: "Quizzes appear here after you start them from inside a lesson."
                    )
                } else {
                    LibraryGridView(
                        items: quizzes,
                        layoutStyle: .gridOnly,
                        compactGridColumns: 2,
                        regularGridColumns: 3,
                        horizontalSpacing: 16,
                        verticalSpacing: 76
                    ) { quiz in
                        QuizCardView(
                            quiz: quiz,
                            onOpenQuiz: onOpenQuiz,
                            onRetakeQuiz: retakeQuiz,
                            style: .library
                        )
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .contentMargins(.top, 20, for: .scrollContent)
        .background(backgroundGradient)
        .navigationTitle("Quizzes")
        .toolbarTitleDisplayMode(.inlineLarge)
    }

    private func retakeQuiz(_ quiz: Quiz) {
        generationCoordinator.resetQuizProgress(quiz, modelContext: modelContext)
        onOpenQuiz(quiz)
    }

    private func placeholderCard(title: String, detail: String) -> some View {
        AppCard {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.headline)

                Text(detail)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color(red: 0.99, green: 0.97, blue: 0.89),
                Color(red: 0.95, green: 0.98, blue: 1.0)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}
