import Foundation
import SwiftData

@Model
final class Quiz {
    @Attribute(.unique) var id: UUID
    var lessonId: UUID
    var title: String
    var sourcesPayload: String
    var createdAt: Date
    var activeQuestionIndex: Int
    var answeredQuestionCount: Int
    var awaitingAdvance: Bool
    var completedAt: Date?
    @Relationship(deleteRule: .cascade, inverse: \StoredQuizQuestion.quiz)
    var questions: [StoredQuizQuestion]

    var sources: [String] {
        get { Self.decodeStringArray(from: sourcesPayload) }
        set { sourcesPayload = Self.encodeStringArray(newValue) }
    }

    init(
        id: UUID = UUID(),
        lessonId: UUID,
        title: String,
        sources: [String] = [],
        createdAt: Date = .now,
        activeQuestionIndex: Int = 0,
        answeredQuestionCount: Int = 0,
        awaitingAdvance: Bool = false,
        completedAt: Date? = nil,
        questions: [StoredQuizQuestion] = []
    ) {
        self.id = id
        self.lessonId = lessonId
        self.title = title
        self.sourcesPayload = Self.encodeStringArray(sources)
        self.createdAt = createdAt
        self.activeQuestionIndex = activeQuestionIndex
        self.answeredQuestionCount = answeredQuestionCount
        self.awaitingAdvance = awaitingAdvance
        self.completedAt = completedAt
        self.questions = questions
    }

    private static func encodeStringArray(_ values: [String]) -> String {
        guard let data = try? JSONEncoder().encode(values),
              let string = String(data: data, encoding: .utf8) else {
            return "[]"
        }

        return string
    }

    private static func decodeStringArray(from payload: String) -> [String] {
        guard let data = payload.data(using: .utf8),
              let values = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }

        return values
    }
}

@Model
final class StoredQuizQuestion {
    @Attribute(.unique) var id: UUID
    var prompt: String
    var type: String
    var options: [String]
    var answer: String?
    var explanation: String?
    var order: Int
    var selectedAnswer: String?
    var wasCorrect: Bool?
    var submittedAt: Date?
    var quiz: Quiz?

    init(
        id: UUID = UUID(),
        prompt: String,
        type: String,
        options: [String] = [],
        answer: String? = nil,
        explanation: String? = nil,
        order: Int,
        selectedAnswer: String? = nil,
        wasCorrect: Bool? = nil,
        submittedAt: Date? = nil,
        quiz: Quiz? = nil
    ) {
        self.id = id
        self.prompt = prompt
        self.type = type
        self.options = options
        self.answer = answer
        self.explanation = explanation
        self.order = order
        self.selectedAnswer = selectedAnswer
        self.wasCorrect = wasCorrect
        self.submittedAt = submittedAt
        self.quiz = quiz
    }
}
