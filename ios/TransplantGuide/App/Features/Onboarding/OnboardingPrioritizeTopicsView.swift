import SwiftUI

struct OnboardingPrioritizeTopicsView: View {
    @Binding var selectedTopics: [ManualTopicDefinition]

    let showsBackButton: Bool
    let isMovingForward: Bool
    let backAction: () -> Void
    let action: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                OnboardingSectionHeaderView(
                    title: "Set the learning order",
                    detail: "The first topic will generate first, followed by the rest of the queue. Use the arrows to rearrange the order."
                )

                VStack(spacing: 38) {
                    ForEach(Array(selectedTopics.enumerated()), id: \.element.id) { index, topic in
                        PrioritizedTopicCard(
                            index: index,
                            tiltIndex: index,
                            topic: topic,
                            isFirst: index == 0,
                            isLast: index == selectedTopics.count - 1,
                            moveUpAction: { move(topic, by: -1) },
                            moveDownAction: { move(topic, by: 1) }
                        )
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                    }
                }
            }
            .padding(24)
            .padding(.bottom, 20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(OnboardingGradientBackground())
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            BottomPrimaryButton(
                title: "Start Learning",
                showsBackButton: showsBackButton,
                isMovingForward: isMovingForward,
                backAction: backAction,
                action: action
            )
        }
    }

    private func move(_ topic: ManualTopicDefinition, by delta: Int) {
        guard let index = selectedTopics.firstIndex(of: topic) else { return }
        let targetIndex = index + delta
        guard selectedTopics.indices.contains(targetIndex) else { return }

        withAnimation(.bouncy(duration: 0.45)) {
            selectedTopics.swapAt(index, targetIndex)
        }
    }
}
