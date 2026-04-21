import SwiftUI

struct LessonsLibraryView: View {
    let lessons: [Lesson]
    let onOpenLesson: (Lesson) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if lessons.isEmpty {
                    placeholderCard(
                        title: "No lessons generated yet",
                        detail: "Selected topics are persisted and waiting in the lesson queue."
                    )
                } else {
                    LibraryGridView(
                        items: lessons,
                        layoutStyle: .gridOnly,
                        compactGridColumns: 2,
                        regularGridColumns: 3
                    ) { lesson in
                        Button {
                            onOpenLesson(lesson)
                        } label: {
                            LessonCardView(lesson: lesson, style: .library)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(backgroundGradient)
        .navigationTitle("Lessons")
        .toolbarTitleDisplayMode(.inlineLarge)
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
