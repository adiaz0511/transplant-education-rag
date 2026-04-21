import Foundation

enum OnboardingStep: Int, CaseIterable, Identifiable {
    case intro
    case chooseTopics
    case prioritizeTopics

    var id: Int { rawValue }
}
