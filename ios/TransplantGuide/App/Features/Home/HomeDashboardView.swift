import SwiftUI
import SwiftData

struct HomeDashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(GenerationCoordinator.self) private var generationCoordinator

    let topics: [Topic]
    let lessons: [Lesson]
    let quizzes: [Quiz]
    let onOpenLesson: (Lesson) -> Void
    let onOpenQuiz: (Quiz) -> Void
    let onOpenAsk: () -> Void
    let onOpenAskWithPrompt: (String) -> Void
    let onShowAllLessons: () -> Void
    let onShowAllQuizzes: () -> Void
    let onShowAllAddMore: () -> Void
    @State private var askSpotlightPrompts = AskStarterPrompt.defaultPrompts.shuffled()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 34) {
                lessonsSection
                askSpotlightSection

                if !orderedQuizzes.isEmpty {
                    quizzesSection
                }

                addMoreSection
                pendingSection
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(backgroundGradient)
    }

    private var askSpotlightSection: some View {
        DashboardAskCard(
            prompts: Array(askSpotlightPrompts.prefix(2)),
            onOpenAsk: onOpenAsk,
            onSelectPrompt: onOpenAskWithPrompt
        )
    }

    private var lessonsSection: some View {
        HomeSection(
            title: "Lessons",
            subtitle: lessonsSubtitle,
            headerAction: orderedLessons.count > previewLimit
                ? .init(title: "Show all", action: onShowAllLessons)
                : nil
        ) {
            if orderedLessons.isEmpty {
                placeholderCard(
                    title: "No lessons generated yet",
                    detail: "Selected topics are persisted and waiting in the lesson queue."
                )
            } else {
                LibraryGridView(
                    items: previewLessons,
                    layoutStyle: .horizontalRail,
                    cardWidth: LessonCardView.dashboardWidth
                ) { lesson in
                    Button {
                        onOpenLesson(lesson)
                    } label: {
                        LessonCardView(lesson: lesson)
                    }
                    .buttonStyle(.plain)
                    .transition(lessonInsertTransition)
                }
                .animation(.bouncy(duration: 0.45), value: previewLessonIDs)
            }
        }
    }

    private var quizzesSection: some View {
        HomeSection(
            title: "Quizzes",
            subtitle: quizzesSubtitle,
            headerAction: orderedQuizzes.count > previewLimit
                ? .init(title: "Show all", action: onShowAllQuizzes)
                : nil
        ) {
            LibraryGridView(
                items: previewQuizzes,
                layoutStyle: .horizontalCompactGridRegular,
                cardWidth: QuizCardView.cardWidth,
                regularGridColumns: 3,
                horizontalSpacing: 16,
                verticalSpacing: 72
            ) { quiz in
                QuizCardView(
                    quiz: quiz,
                    onOpenQuiz: onOpenQuiz,
                    onRetakeQuiz: retakeQuiz
                )
            }
            .padding(.top, 18)
            .padding(.bottom, 25)
        }
    }

    private var addMoreSection: some View {
        HomeSection(
            title: "Add More Lessons",
            subtitle: addMoreSubtitle,
            headerAction: unselectedTopics.count > previewLimit
                ? .init(title: "Show all", action: onShowAllAddMore)
                : nil
        ) {
            if unselectedTopics.isEmpty {
                placeholderCard(
                    title: "You selected every topic",
                    detail: "All chapters from the manual are already in your learning plan."
                )
            } else {
                LibraryGridView(
                    items: previewUnselectedTopics,
                    layoutStyle: .horizontalCompactGridRegular,
                    cardWidth: AddTopicCardView.cardWidth,
                    regularGridColumns: 3,
                    horizontalSpacing: 16,
                    verticalSpacing: 26
                ) { topic in
                    AddTopicCardView(topic: topic, onAdd: addTopicToQueue)
                        .transition(addMoreTransition)
                }
                .animation(.bouncy(duration: 0.45), value: previewUnselectedTopicIDs)
            }
        }
    }

    private var pendingSection: some View {
        HomeSection(title: "Up Next", subtitle: pendingSubtitle) {
            if pendingTopics.isEmpty {
                placeholderCard(
                    title: "Queue complete",
                    detail: "All selected topics have generated lessons."
                )
            } else {
                VStack(spacing: 12) {
                    ForEach(Array(pendingTopics.enumerated()), id: \.element.id) { index, topic in
                        AppCard {
                            VStack(alignment: .leading, spacing: 14) {
                                HStack(alignment: .top, spacing: 16) {
                                    queueStatusView(for: topic)

                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(topic.title)
                                            .font(.headline)

                                        Text(queueLabel(for: topic, at: index))
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)

                                        if let errorMessage = topic.errorMessage, topic.status == .failed {
                                            Text(errorMessage)
                                                .font(.footnote.weight(.semibold))
                                                .foregroundStyle(Color(red: 0.75, green: 0.24, blue: 0.18))
                                                .lineLimit(2)
                                        }
                                    }

                                    Spacer()
                                }

                                if topic.status == .failed {
                                    Button {
                                        Task {
                                            await generationCoordinator.retryLesson(
                                                for: topic,
                                                modelContext: modelContext
                                            )
                                        }
                                    } label: {
                                        Label("Retry lesson", systemImage: "arrow.clockwise")
                                            .font(.subheadline.weight(.bold))
                                            .frame(maxWidth: .infinity)
                                    }
                                    .buttonStyle(
                                        DuolingoBezeledButtonStyle(
                                            fillColor: Color(red: 0.95, green: 0.54, blue: 0.19),
                                            shadowColor: Color(red: 0.83, green: 0.40, blue: 0.09)
                                        )
                                    )
                                }
                            }
                        }
                        .transition(queueTransition)
                        .redacted(reason: redactionReason(for: topic, at: index))
                    }
                }
                .animation(.bouncy(duration: 0.45), value: pendingTopicIDs)
            }
        }
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

    private var orderedLessons: [Lesson] {
        let lessonsByTopic = Dictionary(grouping: lessons, by: \.topicId)

        return topics
            .sorted { $0.order < $1.order }
            .compactMap { topic in
                lessonsByTopic[topic.id]?.sorted { $0.createdAt > $1.createdAt }.first
            }
    }

    private var orderedQuizzes: [Quiz] {
        let quizzesByLessonID = Dictionary(uniqueKeysWithValues: quizzes.map { ($0.lessonId, $0) })

        return orderedLessons.compactMap { lesson in
            quizzesByLessonID[lesson.id]
        }
    }

    private var previewLessons: [Lesson] {
        Array(orderedLessons.prefix(previewLimit))
    }

    private var previewQuizzes: [Quiz] {
        Array(orderedQuizzes.prefix(previewLimit))
    }

    private var previewUnselectedTopics: [ManualTopicDefinition] {
        Array(unselectedTopics.prefix(previewLimit))
    }

    private var pendingTopics: [Topic] {
        topics
            .filter { $0.status != .completed }
            .sorted { $0.order < $1.order }
    }

    private var completedTopics: [Topic] {
        topics.filter { $0.status == .completed }
    }

    private var unselectedTopics: [ManualTopicDefinition] {
        let selectedSlugs = Set(topics.map(\.slug))
        return ManualTopicCatalog.topics.filter { !selectedSlugs.contains($0.slug) }
    }

    private var previewLessonIDs: [UUID] {
        previewLessons.map(\.id)
    }

    private var pendingTopicIDs: [UUID] {
        pendingTopics.map(\.id)
    }

    private var previewUnselectedTopicIDs: [String] {
        previewUnselectedTopics.map(\.slug)
    }

    private var lessonInsertTransition: AnyTransition {
        .move(edge: .bottom).combined(with: .opacity)
    }

    private var queueTransition: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        )
    }

    private var addMoreTransition: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .bottom).combined(with: .opacity),
            removal: .scale(scale: 0.92).combined(with: .opacity)
        )
    }

    private var lessonsSubtitle: String {
        if orderedLessons.isEmpty {
            return "Your selected topics will show up here as full lesson cards the moment each lesson is ready."
        }

        return "Your main learning queue, ordered by the priorities you picked during onboarding."
    }

    private var quizzesSubtitle: String {
        "Practice only appears after you open a lesson and generate a quiz on demand."
    }

    private var addMoreSubtitle: String {
        "Pull more topics from the manual whenever you want to keep expanding the queue."
    }

    private var pendingSubtitle: String {
        "Upcoming topics stay here while lessons are still generating one at a time."
    }

    private func queueLabel(for topic: Topic, at index: Int) -> String {
        switch topic.status {
        case .generating:
            return "Generating now"
        case .failed:
            return index == 0 ? "Generation stopped here" : "Needs retry before the queue can continue"
        case .completed:
            return "Lesson ready"
        case .pending:
            return index == 0 ? "Next lesson to generate" : "Waiting in queue"
        }
    }

    @ViewBuilder
    private func queueStatusView(for topic: Topic) -> some View {
        switch topic.status {
        case .generating:
            ProgressView()
                .controlSize(.regular)
        case .failed:
            Image(systemName: "exclamationmark.circle.fill")
                .font(.title3)
                .foregroundStyle(Color(red: 0.92, green: 0.42, blue: 0.16))
        case .pending:
            Image(systemName: "clock.fill")
                .font(.title3)
                .foregroundStyle(Color(red: 0.20, green: 0.58, blue: 0.83))
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .font(.title3)
                .foregroundStyle(Color(red: 0.18, green: 0.64, blue: 0.35))
        }
    }

    private func redactionReason(for topic: Topic, at index: Int) -> RedactionReasons {
        guard topic.status == .pending else { return [] }
        return index == 0 ? [] : .placeholder
    }

    private func addTopicToQueue(_ topic: ManualTopicDefinition) {
        guard !topics.contains(where: { $0.slug == topic.slug }) else { return }

        let nextOrder = (topics.map(\.order).max() ?? -1) + 1
        withAnimation(.bouncy(duration: 0.45)) {
            modelContext.insert(
                Topic(
                    slug: topic.slug,
                    title: topic.title,
                    order: nextOrder
                )
            )

            try? modelContext.save()
        }

        Task {
            await generationCoordinator.startLessonQueueIfNeeded(modelContext: modelContext)
        }
    }

    private func retakeQuiz(_ quiz: Quiz) {
        generationCoordinator.resetQuizProgress(quiz, modelContext: modelContext)
        onOpenQuiz(quiz)
    }

    private var previewLimit: Int { 6 }

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
