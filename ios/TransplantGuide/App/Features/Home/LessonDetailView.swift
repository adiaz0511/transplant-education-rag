import SwiftUI
import SwiftData

struct LessonDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(GenerationCoordinator.self) private var generationCoordinator
    @Query private var quizzes: [Quiz]

    let lesson: Lesson
    let onOpenQuiz: (Quiz) -> Void

    init(
        lesson: Lesson,
        onOpenQuiz: @escaping (Quiz) -> Void
    ) {
        self.lesson = lesson
        self.onOpenQuiz = onOpenQuiz

        let lessonID = lesson.id
        _quizzes = Query(
            filter: #Predicate<Quiz> { quiz in
                quiz.lessonId == lessonID
            },
            sort: \Quiz.createdAt,
            order: .reverse
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                lessonContentCard

                if !lesson.keyTakeaways.isEmpty {
                    lessonInfoCard(
                        title: "Key Takeaways",
                        systemImage: "star.bubble.fill"
                    ) {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(Array(lesson.keyTakeaways.enumerated()), id: \.offset) { index, takeaway in
                                HStack(alignment: .top, spacing: 12) {
                                    takeawayBadge(index: index + 1)

                                    Text(takeaway)
                                        .font(.body)
                                        .foregroundStyle(.primary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                        }
                    }
                }

                if !lesson.sources.isEmpty {
                    lessonInfoCard(
                        title: "Sources",
                        systemImage: "books.vertical.fill"
                    ) {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(Array(lesson.sources.enumerated()), id: \.offset) { index, source in
                                HStack(alignment: .top, spacing: 12) {
                                    sourceBadge(index: index)

                                    Text(source)
                                        .font(.body)
                                        .foregroundStyle(.primary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                        }
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: 900, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.99, green: 0.97, blue: 0.89),
                    Color(red: 0.95, green: 0.98, blue: 1.0)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        )
        .safeAreaInset(edge: .bottom) {
            bottomActionBar
        }
        .navigationTitle("Lesson")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var lessonContentCard: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 16) {
                Text(lesson.title)
                    .font(.largeTitle.bold())

                MarkdownView(text: lesson.content)
            }
        }
    }

    private func lessonInfoCard<Content: View>(
        title: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        AppCard {
            VStack(alignment: .leading, spacing: 16) {
                Label {
                    Text(title)
                        .font(.title3.weight(.black))
                } icon: {
                    Image(systemName: systemImage)
                        .foregroundStyle(Color(red: 0.20, green: 0.58, blue: 0.83))
                }

                content()
            }
        }
    }

    private func takeawayBadge(index: Int) -> some View {
        Text("\(index)")
            .font(.caption.weight(.black))
            .foregroundStyle(Color(red: 0.80, green: 0.45, blue: 0.10))
            .frame(width: 28, height: 28)
            .background(
                Circle()
                    .fill(Color(red: 1.0, green: 0.94, blue: 0.80))
            )
    }

    private func sourceBadge(index: Int) -> some View {
        Text("[\(index)]")
            .font(.caption.weight(.black))
            .foregroundStyle(Color(red: 0.16, green: 0.46, blue: 0.72))
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(Color(red: 0.88, green: 0.94, blue: 1.0))
            )
    }

    private var bottomActionBar: some View {
        VStack(spacing: 10) {
            Button {
                Task {
                    if let quiz = existingQuiz {
                        onOpenQuiz(quiz)
                    } else if let quiz = await generationCoordinator.generateQuiz(
                        for: lesson,
                        modelContext: modelContext
                    ) {
                        onOpenQuiz(quiz)
                    }
                }
            } label: {
                HStack {
                    Spacer()
                    Text(quizButtonTitle)
                        .font(.headline.weight(.black))
                    Spacer()
                }
            }
            .buttonStyle(DuolingoBezeledButtonStyle())
            .disabled(isQuizActionDisabled)

            if let quizStatusText {
                Text(quizStatusText)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 12)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.99, green: 0.97, blue: 0.89).opacity(0),
                    Color(red: 0.99, green: 0.97, blue: 0.89)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private var existingQuiz: Quiz? {
        quizzes.first
    }

    private var quizButtonTitle: String {
        if generationCoordinator.activeQuizLessonID == lesson.id {
            return "Generating quiz..."
        }

        if let existingQuiz {
            return existingQuiz.completedAt == nil ? "Continue quiz" : "Review quiz"
        }

        return "Test your knowledge"
    }

    private var isQuizActionDisabled: Bool {
        generationCoordinator.activeQuizLessonID != nil && generationCoordinator.activeQuizLessonID != lesson.id
    }

    private var quizStatusText: String? {
        guard let existingQuiz else { return nil }

        if existingQuiz.completedAt != nil {
            return "Quiz complete. You can open it again to review your answers."
        }

        let totalCount = existingQuiz.questions.count
        return "\(existingQuiz.answeredQuestionCount) of \(totalCount) questions answered. Progress is saved on this device."
    }
}
