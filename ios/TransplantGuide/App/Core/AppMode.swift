import Foundation

enum AppMode: String, CaseIterable {
    case ask = "Ask"
    case lesson = "Lesson"
    case quiz = "Quiz"

    var inputPlaceholder: String {
        switch self {
        case .ask:
            return "Enter a query"
        case .lesson, .quiz:
            return "Enter a topic"
        }
    }

    var instructionsTitle: String {
        switch self {
        case .lesson:
            return "Lesson Instructions"
        case .quiz:
            return "Quiz Instructions"
        case .ask:
            return "Instructions"
        }
    }

    var instructionsPlaceholder: String {
        switch self {
        case .lesson:
            return "Optional formatting instructions for the lesson"
        case .quiz:
            return "Optional formatting instructions for the quiz"
        case .ask:
            return "Optional instructions"
        }
    }

    var supportsInstructions: Bool {
        switch self {
        case .ask:
            return false
        case .lesson, .quiz:
            return true
        }
    }
}
