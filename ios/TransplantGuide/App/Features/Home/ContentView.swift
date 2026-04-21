import SwiftData
import SwiftUI

struct ContentView: View {
    @Query(sort: \Topic.order) private var topics: [Topic]
    @Query(sort: \Lesson.createdAt, order: .reverse) private var lessons: [Lesson]
    @Query(sort: \Quiz.createdAt, order: .reverse) private var quizzes: [Quiz]

    var body: some View {
        if topics.isEmpty {
            OnboardingFlowView()
        } else {
            HomeShellView(
                topics: topics,
                lessons: lessons,
                quizzes: quizzes
            )
        }
    }
}
