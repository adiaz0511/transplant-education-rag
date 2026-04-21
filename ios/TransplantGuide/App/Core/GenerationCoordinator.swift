import Foundation
import Observation
import SwiftData

@Observable
@MainActor
final class GenerationCoordinator {
    var activeTopicID: UUID?
    var activeQuizLessonID: UUID?
    var activeAskThreadID: UUID?
    var currentAskSessionThreadID: UUID?
    var pendingAskDraft: String?
    var activeAskError: String?
    var lastError: String?

    private var isRunningLessonQueue = false
    private let apiClient: APIClient
    private let askRecentMessageCount = 6
    private let askSummaryMessageCap = 8
    private let askSummaryCharacterCap = 1_200

    init(apiClient: APIClient? = nil) {
        self.apiClient = apiClient ?? APIClient()
    }

    func startLessonQueueIfNeeded(modelContext: ModelContext) async {
        guard !isRunningLessonQueue else { return }

        isRunningLessonQueue = true
        defer {
            isRunningLessonQueue = false
            activeTopicID = nil
        }

        while let topic = nextTopic(in: modelContext) {
            do {
                try await generateLesson(for: topic, in: modelContext)
            } catch is CancellationError {
                topic.status = .pending
                topic.errorMessage = nil
                try? modelContext.save()
                lastError = nil
                break
            } catch {
                topic.status = .failed
                topic.errorMessage = error.localizedDescription
                try? modelContext.save()
                lastError = error.localizedDescription
                logFailure(
                    operation: "lesson",
                    identifier: topic.title,
                    message: error.localizedDescription,
                    details: failureDetails(for: error)
                )
                break
            }
        }
    }

    func retryLesson(for topic: Topic, modelContext: ModelContext) async {
        guard topic.status == .failed else { return }

        topic.status = .pending
        topic.errorMessage = nil
        try? modelContext.save()
        lastError = nil

        await startLessonQueueIfNeeded(modelContext: modelContext)
    }

    func generateQuiz(for lesson: Lesson, modelContext: ModelContext) async -> Quiz? {
        if let existingQuiz = existingQuiz(for: lesson.id, in: modelContext) {
            return existingQuiz
        }

        guard activeQuizLessonID == nil else { return nil }

        activeQuizLessonID = lesson.id
        defer { activeQuizLessonID = nil }

        do {
            let responseText = try await apiClient.quiz(
                topic: lesson.title,
                instructions: GenerationInstructions.quizInstructions(for: lesson.title)
            ) { _ in }

            let response = try decodeQuizResponse(from: responseText)
            let sources = (response.sources ?? [])
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            let quiz = Quiz(
                lessonId: lesson.id,
                title: "\(lesson.title) Quiz",
                sources: sources
            )
            let questions = (response.data?.questions ?? []).enumerated().map { index, question in
                StoredQuizQuestion(
                    prompt: question.question ?? "Question \(index + 1)",
                    type: question.type ?? "multiple_choice",
                    options: question.options ?? [],
                    answer: question.answer,
                    explanation: question.explanation,
                    order: index,
                    quiz: quiz
                )
            }

            quiz.questions = questions
            modelContext.insert(quiz)
            try modelContext.save()
            lastError = nil
            logQuizSuccess(lessonTitle: lesson.title, responseText: responseText, questionCount: questions.count)
            return quiz
        } catch is CancellationError {
            lastError = nil
            return nil
        } catch {
            lastError = error.localizedDescription
            logFailure(
                operation: "quiz",
                identifier: lesson.title,
                message: error.localizedDescription,
                details: failureDetails(for: error)
            )
            return nil
        }
    }

    func createSessionChatThreadIfNeeded(modelContext: ModelContext) -> ChatThread {
        if let currentAskSessionThreadID,
           let existing = chatThread(withID: currentAskSessionThreadID, in: modelContext) {
            return existing
        }

        if let reusableEmptyThread = latestEmptyChatThread(in: modelContext) {
            currentAskSessionThreadID = reusableEmptyThread.id
            return reusableEmptyThread
        }

        let thread = ChatThread()
        modelContext.insert(thread)
        currentAskSessionThreadID = thread.id
        try? modelContext.save()
        return thread
    }

    func startNewChatSession(modelContext: ModelContext) -> ChatThread {
        let thread = ChatThread()
        modelContext.insert(thread)
        currentAskSessionThreadID = thread.id
        try? modelContext.save()
        return thread
    }

    func sendAskMessage(
        _ message: String,
        in thread: ChatThread,
        modelContext: ModelContext
    ) async -> ChatMessage? {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, activeAskThreadID == nil else { return nil }

        let userMessage = ChatMessage(
            thread: thread,
            role: .user,
            content: trimmed
        )
        modelContext.insert(userMessage)
        if thread.title == "Ask" || thread.title == "New chat" {
            thread.title = suggestedThreadTitle(from: trimmed)
        }
        thread.updatedAt = .now
        try? modelContext.save()

        let query = buildAskQuery(
            currentQuestion: trimmed,
            summary: thread.conversationSummary,
            recentMessages: recentAskMessages(for: thread, in: modelContext)
        )

        activeAskThreadID = thread.id
        activeAskError = nil
        defer { activeAskThreadID = nil }

        do {
            let responseText = try await apiClient.ask(query: query) { _ in }
            let response = try decodeAskResponse(from: responseText)
            let answer = response.data?.answer?.nilIfBlank
            let keyPoints = response.data?.keyPoints?
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty } ?? []
            let sourceIndices = response.data?.sourceIndices ?? []
            let sources = response.sources?
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty } ?? []

            guard let answer else {
                throw APIError.responseParsingFailed(
                    message: "Ask response was missing an answer.",
                    responseText: responseText
                )
            }

            let assistantMessage = ChatMessage(
                thread: thread,
                role: .assistant,
                content: answer,
                keyPoints: keyPoints,
                sourceIndices: sourceIndices,
                sources: sources
            )

            modelContext.insert(assistantMessage)
            thread.updatedAt = .now
            refreshConversationSummary(for: thread, modelContext: modelContext)
            try? modelContext.save()
            activeAskError = nil
            return assistantMessage
        } catch is CancellationError {
            activeAskError = nil
            return nil
        } catch {
            activeAskError = error.localizedDescription
            lastError = error.localizedDescription
            logFailure(
                operation: "ask",
                identifier: trimmed,
                message: error.localizedDescription,
                details: failureDetails(for: error)
            )
            return nil
        }
    }

    func submitAnswer(
        selectedAnswer: String,
        for question: StoredQuizQuestion,
        in quiz: Quiz,
        modelContext: ModelContext
    ) {
        question.selectedAnswer = selectedAnswer
        question.wasCorrect = isCorrectAnswer(selectedAnswer, expected: question.answer)
        question.submittedAt = .now

        quiz.answeredQuestionCount = answeredQuestionCount(in: quiz)
        quiz.awaitingAdvance = true

        try? modelContext.save()
    }

    func advanceQuiz(_ quiz: Quiz, modelContext: ModelContext) {
        let questions = orderedQuestions(in: quiz)
        let nextIndex = min(quiz.activeQuestionIndex + 1, questions.count)

        quiz.awaitingAdvance = false
        quiz.answeredQuestionCount = answeredQuestionCount(in: quiz)

        if nextIndex >= questions.count {
            quiz.activeQuestionIndex = questions.count
            quiz.completedAt = quiz.completedAt ?? .now
        } else {
            quiz.activeQuestionIndex = nextIndex
        }

        try? modelContext.save()
    }

    func resetQuizProgress(_ quiz: Quiz, modelContext: ModelContext) {
        quiz.activeQuestionIndex = 0
        quiz.answeredQuestionCount = 0
        quiz.awaitingAdvance = false
        quiz.completedAt = nil

        for question in quiz.questions {
            question.selectedAnswer = nil
            question.wasCorrect = nil
            question.submittedAt = nil
        }

        try? modelContext.save()
    }

    private func generateLesson(for topic: Topic, in modelContext: ModelContext) async throws {
        activeTopicID = topic.id
        topic.status = .generating
        topic.errorMessage = nil
        try modelContext.save()

        let responseText = try await apiClient.lesson(
            topic: topic.title,
            instructions: GenerationInstructions.lessonInstructions(for: topic.title)
        ) { _ in }

        let response = try decodeLessonResponse(from: responseText)
        let lessonTitle = response.data?.title?.nilIfBlank ?? topic.title
        let lessonContent = response.data?.lessonMarkdown?.nilIfBlank
        let keyTakeaways = response.data?.keyTakeaways?
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty } ?? []
        let sources = response.sources?
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty } ?? []

        guard let lessonContent else {
            throw APIError.responseParsingFailed(
                message: "Lesson response was missing lesson markdown.",
                responseText: responseText
            )
        }

        if let existingLesson = existingLesson(for: topic.id, in: modelContext) {
            existingLesson.title = lessonTitle
            existingLesson.content = lessonContent
            existingLesson.keyTakeaways = keyTakeaways
            existingLesson.sources = sources
            existingLesson.createdAt = .now
        } else {
            modelContext.insert(
                Lesson(
                    topicId: topic.id,
                    title: lessonTitle,
                    content: lessonContent,
                    keyTakeaways: keyTakeaways,
                    sources: sources
                )
            )
        }

        topic.status = .completed
        topic.errorMessage = nil
        try modelContext.save()
        lastError = nil
        logLessonSuccess(topicTitle: topic.title, lessonTitle: lessonTitle, responseText: responseText)
    }

    private func nextTopic(in modelContext: ModelContext) -> Topic? {
        let descriptor = FetchDescriptor<Topic>(
            sortBy: [SortDescriptor(\.order)]
        )

        guard let topics = try? modelContext.fetch(descriptor) else {
            return nil
        }

        return topics.first { $0.status == .generating } ?? topics.first { $0.status == .pending }
    }

    private func existingLesson(for topicID: UUID, in modelContext: ModelContext) -> Lesson? {
        let descriptor = FetchDescriptor<Lesson>(
            predicate: #Predicate<Lesson> { lesson in
                lesson.topicId == topicID
            }
        )

        return try? modelContext.fetch(descriptor).first
    }

    private func existingQuiz(for lessonID: UUID, in modelContext: ModelContext) -> Quiz? {
        let descriptor = FetchDescriptor<Quiz>(
            predicate: #Predicate<Quiz> { quiz in
                quiz.lessonId == lessonID
            },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )

        return try? modelContext.fetch(descriptor).first
    }

    private func currentChatThread(in modelContext: ModelContext) -> ChatThread? {
        let descriptor = FetchDescriptor<ChatThread>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )

        return try? modelContext.fetch(descriptor).first
    }

    private func latestEmptyChatThread(in modelContext: ModelContext) -> ChatThread? {
        let descriptor = FetchDescriptor<ChatThread>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )

        guard let threads = try? modelContext.fetch(descriptor) else {
            return nil
        }

        return threads.first { thread in
            messages(for: thread, in: modelContext).isEmpty
        }
    }

    private func chatThread(withID id: UUID, in modelContext: ModelContext) -> ChatThread? {
        let descriptor = FetchDescriptor<ChatThread>(
            predicate: #Predicate<ChatThread> { thread in
                thread.id == id
            }
        )

        return try? modelContext.fetch(descriptor).first
    }

    private func messages(for thread: ChatThread, in modelContext: ModelContext) -> [ChatMessage] {
        let threadID = thread.id
        let descriptor = FetchDescriptor<ChatMessage>(
            predicate: #Predicate<ChatMessage> { message in
                message.threadID == threadID
            },
            sortBy: [SortDescriptor(\.createdAt)]
        )

        return (try? modelContext.fetch(descriptor)) ?? []
    }

    private func recentAskMessages(for thread: ChatThread, in modelContext: ModelContext) -> [ChatMessage] {
        Array(messages(for: thread, in: modelContext).suffix(askRecentMessageCount))
    }

    private func buildAskQuery(
        currentQuestion: String,
        summary: String,
        recentMessages: [ChatMessage]
    ) -> String {
        var sections: [String] = [
            "Current question:\n\(currentQuestion)"
        ]

        let trimmedSummary = summary.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedSummary.isEmpty {
            sections.append("Conversation summary:\n\(trimmedSummary)")
        }

        if !recentMessages.isEmpty {
            let transcript = recentMessages.map { message in
                let prefix = message.role == .user ? "User" : "Assistant"
                return "\(prefix): \(sanitizedSummaryText(from: message.content, limit: 320))"
            }.joined(separator: "\n")
            sections.append("Recent conversation:\n\(transcript)")
        }

        sections.append("Answer the current question using the conversation context only when it helps clarify follow-up meaning.")
        return sections.joined(separator: "\n\n")
    }

    private func refreshConversationSummary(for thread: ChatThread, modelContext: ModelContext) {
        let allMessages = messages(for: thread, in: modelContext)
        let olderMessages = allMessages.dropLast(min(allMessages.count, askRecentMessageCount))

        guard !olderMessages.isEmpty else {
            thread.conversationSummary = ""
            return
        }

        let summaryLines = olderMessages.suffix(askSummaryMessageCap).map { message in
            let prefix = message.role == .user ? "User" : "Assistant"
            return "\(prefix): \(sanitizedSummaryText(from: message.content, limit: 140))"
        }

        let summary = summaryLines.joined(separator: "\n")
        thread.conversationSummary = String(summary.prefix(askSummaryCharacterCap))
    }

    private func sanitizedSummaryText(from content: String, limit: Int) -> String {
        let withoutCitations = content
            .replacingOccurrences(of: #"\[\d+\]"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"[#*_>`]+"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard withoutCitations.count > limit else { return withoutCitations }
        let cutoff = withoutCitations.index(withoutCitations.startIndex, offsetBy: limit)
        return String(withoutCitations[..<cutoff]).trimmingCharacters(in: .whitespacesAndNewlines) + "..."
    }

    private func suggestedThreadTitle(from firstMessage: String) -> String {
        let sanitized = sanitizedSummaryText(from: firstMessage, limit: 52)
        return sanitized.isEmpty ? "New chat" : sanitized
    }

    private func decodeLessonResponse(from responseText: String) throws -> LessonResponse {
        let parts = StreamResponseParser.split(responseText)

        do {
            guard let response = try StreamResponseParser.decode(LessonResponse.self, from: parts.jsonData) else {
                throw APIError.responseParsingFailed(
                    message: "Lesson response body was empty or invalid.",
                    responseText: responseText
                )
            }

            return response
        } catch let apiError as APIError {
            throw apiError
        } catch {
            throw APIError.responseParsingFailed(
                message: "Failed to parse lesson response: \(error.localizedDescription)",
                responseText: responseText
            )
        }
    }

    private func decodeQuizResponse(from responseText: String) throws -> QuizResponse {
        let parts = StreamResponseParser.split(responseText)

        do {
            guard let response = try StreamResponseParser.decode(QuizResponse.self, from: parts.jsonData) else {
                throw APIError.responseParsingFailed(
                    message: "Quiz response body was empty or invalid.",
                    responseText: responseText
                )
            }

            return response
        } catch let apiError as APIError {
            throw apiError
        } catch {
            throw APIError.responseParsingFailed(
                message: "Failed to parse quiz response: \(error.localizedDescription)",
                responseText: responseText
            )
        }
    }

    private func decodeAskResponse(from responseText: String) throws -> AskResponse {
        let parts = StreamResponseParser.split(responseText)

        do {
            guard let response = try StreamResponseParser.decode(AskResponse.self, from: parts.jsonData) else {
                throw APIError.responseParsingFailed(
                    message: "Ask response body was empty or invalid.",
                    responseText: responseText
                )
            }

            return response
        } catch let apiError as APIError {
            throw apiError
        } catch {
            throw APIError.responseParsingFailed(
                message: "Failed to parse ask response: \(error.localizedDescription)",
                responseText: responseText
            )
        }
    }

    private func logLessonSuccess(topicTitle: String, lessonTitle: String, responseText: String) {
        print("")
        print("===== LESSON GENERATED =====")
        print("Topic: \(topicTitle)")
        print("Lesson Title: \(lessonTitle)")
        print("Server Result:")
        print(responseText)
        print("============================")
        print("")
    }

    private func logQuizSuccess(lessonTitle: String, responseText: String, questionCount: Int) {
        print("")
        print("====== QUIZ GENERATED ======")
        print("Lesson: \(lessonTitle)")
        print("Question Count: \(questionCount)")
        print("Server Result:")
        print(responseText)
        print("============================")
        print("")
    }

    private func logFailure(operation: String, identifier: String, message: String, details: String?) {
        print("")
        print("====== GENERATION ERROR ======")
        print("Operation: \(operation)")
        print("Target: \(identifier)")
        print("Error: \(message)")
        if let details, !details.isEmpty {
            print("Details:")
            print(details)
        }
        print("==============================")
        print("")
    }

    private func failureDetails(for error: Error) -> String? {
        if let apiError = error as? APIError {
            return apiError.failureDetails
        }

        let nsError = error as NSError
        guard !nsError.userInfo.isEmpty else { return nil }

        var lines: [String] = [
            "Domain: \(nsError.domain)",
            "Code: \(nsError.code)"
        ]

        if let failingURL = nsError.userInfo[NSURLErrorFailingURLStringErrorKey] as? String {
            lines.append("Failing URL: \(failingURL)")
        }

        if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? NSError {
            lines.append("Underlying Domain: \(underlying.domain)")
            lines.append("Underlying Code: \(underlying.code)")
        }

        return lines.joined(separator: "\n")
    }

    private func orderedQuestions(in quiz: Quiz) -> [StoredQuizQuestion] {
        quiz.questions.sorted { $0.order < $1.order }
    }

    private func answeredQuestionCount(in quiz: Quiz) -> Int {
        quiz.questions.filter { $0.submittedAt != nil }.count
    }

    private func isCorrectAnswer(_ selectedAnswer: String, expected: String?) -> Bool {
        normalizeAnswer(selectedAnswer) == normalizeAnswer(expected)
    }

    private func normalizeAnswer(_ answer: String?) -> String {
        answer?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() ?? ""
    }
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
