import SwiftUI

struct QuizCardView: View {
    enum CardStyle {
        case dashboard
        case library

        var width: CGFloat {
            switch self {
            case .dashboard:
                return 250
            case .library:
                return 0
            }
        }

        var height: CGFloat {
            switch self {
            case .dashboard:
                return 215
            case .library:
                return 190
            }
        }

        var titleHeight: CGFloat {
            switch self {
            case .dashboard:
                return 42
            case .library:
                return 38
            }
        }

        var detailHeight: CGFloat {
            switch self {
            case .dashboard:
                return 56
            case .library:
                return 50
            }
        }

        var actionHeight: CGFloat {
            switch self {
            case .dashboard:
                return 58
            case .library:
                return 52
            }
        }
    }

    static let cardWidth: CGFloat = 250

    let quiz: Quiz
    let onOpenQuiz: (Quiz) -> Void
    let onRetakeQuiz: (Quiz) -> Void
    let style: CardStyle

    init(
        quiz: Quiz,
        onOpenQuiz: @escaping (Quiz) -> Void,
        onRetakeQuiz: @escaping (Quiz) -> Void,
        style: CardStyle = .dashboard
    ) {
        self.quiz = quiz
        self.onOpenQuiz = onOpenQuiz
        self.onRetakeQuiz = onRetakeQuiz
        self.style = style
    }

    var body: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 10) {
                quizBadge

                Text(quiz.title)
                    .font(.subheadline.weight(.black))
                    .lineLimit(2)
                    .frame(height: style.titleHeight, alignment: .topLeading)

                VStack(alignment: .leading, spacing: 6) {
                    Text(quizProgressLabel)
                        .font(.caption.weight(.black))
                        .foregroundStyle(Color(red: 0.12, green: 0.46, blue: 0.88))

                    Text(quizStatusSubtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                }
                .frame(height: style.detailHeight, alignment: .topLeading)

                Spacer(minLength: 0)

                Button {
                    if quiz.completedAt != nil {
                        onRetakeQuiz(quiz)
                    } else {
                        onOpenQuiz(quiz)
                    }
                } label: {
                    Text(quizActionTitle)
                        .font(.caption.weight(.bold))
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(DuolingoBezeledButtonStyle())
                .frame(height: style.actionHeight)
            }
        }
        .frame(height: style.height)
    }

    private var quizBadge: some View {
        HStack(spacing: 8) {
            Image(systemName: quizBadgeIcon)
                .font(.caption.weight(.black))

            Text(quizBadgeTitle)
                .font(.caption.weight(.black))
                .lineLimit(1)
        }
        .foregroundStyle(Color(red: 0.12, green: 0.46, blue: 0.88))
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule(style: .continuous)
                .fill(Color(red: 0.90, green: 0.95, blue: 1.0))
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(Color(red: 0.71, green: 0.83, blue: 0.98), lineWidth: 1.5)
        )
    }

    private var quizProgressLabel: String {
        if quiz.completedAt != nil {
            return "\(quiz.questions.count) questions answered"
        }

        return "\(quiz.answeredQuestionCount) of \(quiz.questions.count) questions answered"
    }

    private var quizStatusSubtitle: String {
        if quiz.completedAt != nil {
            return "Wrapped up and ready whenever you want another run."
        }

        if quiz.answeredQuestionCount > 0 {
            return "You already started this one, so you can jump right back in."
        }

        return "Ready when you are. This one has \(quiz.questions.count) questions."
    }

    private var quizBadgeTitle: String {
        if quiz.completedAt != nil {
            return "Completed quiz"
        }

        if quiz.answeredQuestionCount > 0 {
            return "In progress"
        }

        return "Ready to practice"
    }

    private var quizBadgeIcon: String {
        if quiz.completedAt != nil {
            return "checkmark.circle.fill"
        }

        if quiz.answeredQuestionCount > 0 {
            return "arrow.trianglehead.clockwise"
        }

        return "bolt.fill"
    }

    private var quizActionTitle: String {
        if quiz.completedAt != nil {
            return "Retake"
        }

        if quiz.answeredQuestionCount > 0 {
            return "Continue"
        }

        return "Start"
    }
}
