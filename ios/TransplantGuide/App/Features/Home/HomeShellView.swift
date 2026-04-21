import SwiftUI
import SwiftData

struct HomeShellView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var selectedTab: HomeTab = .dashboard
    @State private var dashboardPath: [HomeDestination] = []
    @State private var askPath: [HomeDestination] = []
    @State private var lessonsPath: [HomeDestination] = []
    @State private var quizzesPath: [HomeDestination] = []
    @State private var addMorePath: [HomeDestination] = []

    @Environment(\.modelContext) private var modelContext
    @Environment(GenerationCoordinator.self) private var generationCoordinator

    let topics: [Topic]
    let lessons: [Lesson]
    let quizzes: [Quiz]

    var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                HomeIPadNavigationView(selectedTab: $selectedTab) {
                    activeNavigationStack
                }
            } else {
                compactTabView
            }
        }
        .task {
            await generationCoordinator.startLessonQueueIfNeeded(modelContext: modelContext)
        }
    }

    private var compactTabView: some View {
        TabView(selection: $selectedTab) {
            Tab(HomeTab.dashboard.title, systemImage: HomeTab.dashboard.systemImage, value: .dashboard) {
                navigationStack(path: $dashboardPath) {
                    homeDashboard
                }
            }

            Tab(HomeTab.ask.title, systemImage: HomeTab.ask.systemImage, value: .ask) {
                navigationStack(path: $askPath) {
                    askChat
                }
            }

            Tab(HomeTab.lessons.title, systemImage: HomeTab.lessons.systemImage, value: .lessons) {
                navigationStack(path: $lessonsPath) {
                    lessonsLibrary
                }
            }

            Tab(HomeTab.quizzes.title, systemImage: HomeTab.quizzes.systemImage, value: .quizzes) {
                navigationStack(path: $quizzesPath) {
                    quizzesLibrary
                }
            }

            Tab(HomeTab.addMore.title, systemImage: HomeTab.addMore.systemImage, value: .addMore) {
                navigationStack(path: $addMorePath) {
                    addMoreLessons
                }
            }
        }
        .tabViewStyle(.sidebarAdaptable)
    }

    @ViewBuilder
    private var activeNavigationStack: some View {
        switch selectedTab {
        case .dashboard:
            navigationStack(path: $dashboardPath) {
                homeDashboard
            }
        case .ask:
            navigationStack(path: $askPath) {
                askChat
            }
        case .lessons:
            navigationStack(path: $lessonsPath) {
                lessonsLibrary
            }
        case .quizzes:
            navigationStack(path: $quizzesPath) {
                quizzesLibrary
            }
        case .addMore:
            navigationStack(path: $addMorePath) {
                addMoreLessons
            }
        }
    }

    private func navigationStack<Content: View>(
        path: Binding<[HomeDestination]>,
        @ViewBuilder root: () -> Content
    ) -> some View {
        NavigationStack(path: path) {
            root()
                .navigationDestination(for: HomeDestination.self) { destination in
                    destinationView(for: destination)
                }
        }
    }

    private var homeDashboard: some View {
        HomeDashboardView(
            topics: topics,
            lessons: lessons,
            quizzes: quizzes,
            onOpenLesson: openLesson,
            onOpenQuiz: openQuiz,
            onOpenAsk: { selectedTab = .ask },
            onOpenAskWithPrompt: { prompt in
                generationCoordinator.pendingAskDraft = prompt
                selectedTab = .ask
            },
            onShowAllLessons: { selectedTab = .lessons },
            onShowAllQuizzes: { selectedTab = .quizzes },
            onShowAllAddMore: { selectedTab = .addMore }
        )
        .navigationTitle("Dashboard")
        .toolbarTitleDisplayMode(.inlineLarge)
    }

    private var lessonsLibrary: some View {
        LessonsLibraryView(
            lessons: orderedLessons,
            onOpenLesson: openLesson
        )
    }

    private var askChat: some View {
        AskChatView()
    }

    private var quizzesLibrary: some View {
        QuizzesLibraryView(
            quizzes: orderedQuizzes,
            onOpenQuiz: openQuiz
        )
    }

    private var addMoreLessons: some View {
        AddMoreLessonsView(topics: topics)
    }

    @ViewBuilder
    private func destinationView(for destination: HomeDestination) -> some View {
        switch destination {
        case let .lesson(id):
            if let lesson = lessons.first(where: { $0.id == id }) {
                LessonDetailView(
                    lesson: lesson,
                    onOpenQuiz: openQuizFromLesson
                )
            } else {
                ContentUnavailableView(
                    "Lesson unavailable",
                    systemImage: "book.closed",
                    description: Text("This lesson could not be loaded.")
                )
            }
        case let .quiz(id, showsBackToLessonButton):
            if let quiz = quizzes.first(where: { $0.id == id }) {
                QuizDetailView(
                    quiz: quiz,
                    lesson: lessons.first(where: { $0.id == quiz.lessonId }),
                    showsBackToLessonButton: showsBackToLessonButton
                )
            } else {
                ContentUnavailableView(
                    "Quiz unavailable",
                    systemImage: "questionmark.circle",
                    description: Text("This quiz could not be loaded.")
                )
            }
        }
    }

    private func openLesson(_ lesson: Lesson) {
        activePath.wrappedValue.append(.lesson(id: lesson.id))
    }

    private func openQuiz(_ quiz: Quiz) {
        activePath.wrappedValue.append(.quiz(id: quiz.id, showsBackToLessonButton: false))
    }

    private func openQuizFromLesson(_ quiz: Quiz) {
        activePath.wrappedValue.append(.quiz(id: quiz.id, showsBackToLessonButton: true))
    }

    private var activePath: Binding<[HomeDestination]> {
        switch selectedTab {
        case .dashboard:
            $dashboardPath
        case .ask:
            $askPath
        case .lessons:
            $lessonsPath
        case .quizzes:
            $quizzesPath
        case .addMore:
            $addMorePath
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
}

private enum HomeDestination: Hashable {
    case lesson(id: UUID)
    case quiz(id: UUID, showsBackToLessonButton: Bool)
}
