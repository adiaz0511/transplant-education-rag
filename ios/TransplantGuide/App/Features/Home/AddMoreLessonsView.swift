import SwiftUI
import SwiftData

struct AddMoreLessonsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(GenerationCoordinator.self) private var generationCoordinator

    let topics: [Topic]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if unselectedTopics.isEmpty {
                    placeholderCard(
                        title: "You selected every topic",
                        detail: "All chapters from the manual are already in your learning plan."
                    )
                } else {
                    LibraryGridView(
                        items: unselectedTopics,
                        layoutStyle: .gridOnly,
                        compactGridColumns: 2,
                        regularGridColumns: 3,
                        horizontalSpacing: 16,
                        verticalSpacing: 36
                    ) { topic in
                        AddTopicCardView(topic: topic, onAdd: addTopicToQueue, style: .library)
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(backgroundGradient)
        .navigationTitle("Add More Lessons")
        .toolbarTitleDisplayMode(.inlineLarge)
    }

    private var unselectedTopics: [ManualTopicDefinition] {
        let selectedSlugs = Set(topics.map(\.slug))
        return ManualTopicCatalog.topics.filter { !selectedSlugs.contains($0.slug) }
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
