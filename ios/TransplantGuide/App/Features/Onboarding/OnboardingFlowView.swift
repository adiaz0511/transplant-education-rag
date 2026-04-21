import SwiftData
import SwiftUI

struct OnboardingFlowView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var step: OnboardingStep = .intro
    @State private var selectedTopics: [ManualTopicDefinition] = []
    @State private var isMovingForward = true

    var body: some View {
        NavigationStack {
            ZStack {
                currentStepView
                    .id(step)
                    .transition(stepTransition)
            }
            .animation(.smooth(duration: 0.35), value: step)
        }
    }

    @ViewBuilder
    private var currentStepView: some View {
        switch step {
        case .intro:
            OnboardingIntroView(
                isMovingForward: isMovingForward,
                action: goToTopicSelection
            )
        case .chooseTopics:
            OnboardingChooseTopicsView(
                selectedTopics: $selectedTopics,
                showsBackButton: true,
                isMovingForward: isMovingForward,
                backAction: goBack,
                action: goToPrioritization
            )
        case .prioritizeTopics:
            OnboardingPrioritizeTopicsView(
                selectedTopics: $selectedTopics,
                showsBackButton: true,
                isMovingForward: isMovingForward,
                backAction: goBack,
                action: saveSelection
            )
        }
    }

    private func goBack() {
        guard let previousStep = OnboardingStep(rawValue: step.rawValue - 1) else { return }
        isMovingForward = false
        withAnimation(.smooth(duration: 0.35)) {
            step = previousStep
        }
    }

    private func goToTopicSelection() {
        isMovingForward = true
        withAnimation(.smooth(duration: 0.35)) {
            step = .chooseTopics
        }
    }

    private func goToPrioritization() {
        isMovingForward = true
        withAnimation(.smooth(duration: 0.35)) {
            step = .prioritizeTopics
        }
    }

    private func saveSelection() {
        let descriptor = FetchDescriptor<Topic>()
        if let existingTopics = try? modelContext.fetch(descriptor) {
            for topic in existingTopics {
                modelContext.delete(topic)
            }
        }

        for (index, topic) in selectedTopics.enumerated() {
            modelContext.insert(
                Topic(
                    slug: topic.slug,
                    title: topic.title,
                    order: index,
                    status: .pending
                )
            )
        }

        try? modelContext.save()
    }

    private var stepTransition: AnyTransition {
        let insertionEdge: Edge = isMovingForward ? .trailing : .leading
        let removalEdge: Edge = isMovingForward ? .leading : .trailing

        return .asymmetric(
            insertion: .move(edge: insertionEdge).combined(with: .opacity),
            removal: .move(edge: removalEdge).combined(with: .opacity)
        )
    }
}
