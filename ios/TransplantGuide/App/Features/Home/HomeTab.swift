import SwiftUI

enum HomeTab: String, CaseIterable, Hashable, Identifiable {
    case dashboard
    case ask
    case lessons
    case quizzes
    case addMore

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dashboard:
            return "Dashboard"
        case .ask:
            return "Ask"
        case .lessons:
            return "Lessons"
        case .quizzes:
            return "Quizzes"
        case .addMore:
            return "Add More"
        }
    }

    var shortTitle: String {
        switch self {
        case .dashboard:
            return "Home"
        case .ask:
            return "Ask"
        case .lessons:
            return "Lessons"
        case .quizzes:
            return "Quizzes"
        case .addMore:
            return "More"
        }
    }

    var systemImage: String {
        switch self {
        case .dashboard:
            return "rectangle.grid.2x2.fill"
        case .ask:
            return "bubble.left.and.bubble.right.fill"
        case .lessons:
            return "book.closed.fill"
        case .quizzes:
            return "checklist.checked"
        case .addMore:
            return "plus.circle.fill"
        }
    }

    var fillColor: Color {
        switch self {
        case .dashboard:
            return Color(red: 0.88, green: 0.42, blue: 0.23)
        case .ask:
            return Color(red: 0.17, green: 0.67, blue: 0.64)
        case .lessons:
            return Color(red: 0.14, green: 0.66, blue: 0.29)
        case .quizzes:
            return Color(red: 0.20, green: 0.58, blue: 0.83)
        case .addMore:
            return Color(red: 0.94, green: 0.53, blue: 0.18)
        }
    }

    var shadowColor: Color {
        switch self {
        case .dashboard:
            return Color(red: 0.74, green: 0.29, blue: 0.12)
        case .ask:
            return Color(red: 0.08, green: 0.47, blue: 0.46)
        case .lessons:
            return Color(red: 0.10, green: 0.48, blue: 0.20)
        case .quizzes:
            return Color(red: 0.10, green: 0.43, blue: 0.66)
        case .addMore:
            return Color(red: 0.78, green: 0.38, blue: 0.08)
        }
    }

    var tintColor: Color {
        switch self {
        case .dashboard:
            return Color(red: 0.76, green: 0.30, blue: 0.14)
        case .ask:
            return Color(red: 0.10, green: 0.53, blue: 0.52)
        case .lessons:
            return Color(red: 0.16, green: 0.55, blue: 0.24)
        case .quizzes:
            return Color(red: 0.16, green: 0.46, blue: 0.72)
        case .addMore:
            return Color(red: 0.82, green: 0.42, blue: 0.10)
        }
    }
}
