import SwiftUI

struct OnboardingChooseTopicsView: View {
    @Binding var selectedTopics: [ManualTopicDefinition]

    let showsBackButton: Bool
    let isMovingForward: Bool
    let backAction: () -> Void
    let action: () -> Void

    private let columns = [
        GridItem(.adaptive(minimum: 260, maximum: 360), spacing: 28, alignment: .top)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                OnboardingSectionHeaderView(
                    title: "Choose chapters to include",
                    detail: "Select every chapter your family wants in the learning queue. You can choose as many as you want now, then rank them on the next screen."
                )

                LazyVGrid(columns: columns, spacing: 28) {
                    ForEach(Array(ManualTopicCatalog.topics.enumerated()), id: \.element.id) { index, topic in
                        TopicSelectionCard(
                            tiltIndex: index,
                            topic: topic,
                            isSelected: selectedTopics.contains(topic),
                            action: { toggle(topic) }
                        )
                        .padding(6)
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(OnboardingGradientBackground())
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            BottomPrimaryButton(
                title: buttonTitle,
                isDisabled: selectedTopics.isEmpty,
                showsBackButton: showsBackButton,
                isMovingForward: isMovingForward,
                backAction: backAction,
                action: action
            )
        }
    }

    private var buttonTitle: String {
        selectedTopics.isEmpty ? "Select Topics to Continue" : "Arrange Priority"
    }

    private func toggle(_ topic: ManualTopicDefinition) {
        if let index = selectedTopics.firstIndex(of: topic) {
            selectedTopics.remove(at: index)
        } else {
            selectedTopics.append(topic)
        }
    }
}
