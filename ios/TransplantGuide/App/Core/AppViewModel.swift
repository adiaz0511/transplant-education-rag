import Foundation
import Observation

@Observable
@MainActor
final class AppViewModel {
    var input: String = ""
    var instructions: String = ""
    var selectedMode: AppMode = .ask

    var outputMarkdown: String = ""
    var fullResponse: String = ""
    var parsedJSON: Data?

    var askResponse: AskResponse?
    var lessonResponse: LessonResponse?
    var quizResponse: QuizResponse?

    var isLoading = false
    var error: String?

    private let apiClient: APIClient

    init(apiClient: APIClient? = nil) {
        self.apiClient = apiClient ?? APIClient()
    }

    func run() async {
        let trimmedInput = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedInstructions = instructions.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedInput.isEmpty else {
            error = selectedMode == .ask ? "Enter a query." : "Enter a topic."
            clearResults()
            return
        }

        clearResults()
        isLoading = true
        defer { isLoading = false }

        do {
            switch selectedMode {
            case .ask:
                fullResponse = try await apiClient.ask(query: trimmedInput) { [weak self] chunk in
                    await self?.appendStreamChunk(chunk)
                }
                logCompletedResponse(input: trimmedInput, instructions: trimmedInstructions)
                try decodeAskResponse()
            case .lesson:
                let effectiveInstructions = trimmedInstructions.isEmpty
                    ? GenerationInstructions.lessonInstructions(for: trimmedInput)
                    : trimmedInstructions
                fullResponse = try await apiClient.lesson(
                    topic: trimmedInput,
                    instructions: effectiveInstructions
                ) { [weak self] chunk in
                    await self?.appendStreamChunk(chunk)
                }
                logCompletedResponse(input: trimmedInput, instructions: effectiveInstructions)
                try decodeLessonResponse()
            case .quiz:
                let effectiveInstructions = trimmedInstructions.isEmpty
                    ? GenerationInstructions.quizInstructions(for: trimmedInput)
                    : trimmedInstructions
                fullResponse = try await apiClient.quiz(
                    topic: trimmedInput,
                    instructions: effectiveInstructions
                ) { [weak self] chunk in
                    await self?.appendStreamChunk(chunk)
                }
                logCompletedResponse(input: trimmedInput, instructions: effectiveInstructions)
                try decodeQuizResponse()
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func appendStreamChunk(_ chunk: String) {
        fullResponse.append(chunk)
    }

    private func logCompletedResponse(input: String, instructions: String) {
        let parts = StreamResponseParser.split(fullResponse)
        let jsonText = parts.jsonData.flatMap { String(data: $0, encoding: .utf8) } ?? "<none>"
        let instructionsText = instructions.isEmpty ? "<none>" : instructions

        print("")
        print("========== \(selectedMode.rawValue.uppercased()) RESPONSE ==========")
        print("Input:")
        print(input)
        print("")
        print("Instructions:")
        print(instructionsText)
        print("")
        print("Full Response:")
        print(fullResponse)
        print("")
        print("JSON:")
        print(jsonText)
        print("================================================")
        print("")
    }

    private func decodeAskResponse() throws {
        let parts = StreamResponseParser.split(fullResponse)
        parsedJSON = parts.jsonData
        askResponse = try StreamResponseParser.decode(AskResponse.self, from: parts.jsonData)
        outputMarkdown = askResponse?.data?.answer ?? ""
    }

    private func decodeLessonResponse() throws {
        let parts = StreamResponseParser.split(fullResponse)
        parsedJSON = parts.jsonData
        lessonResponse = try StreamResponseParser.decode(LessonResponse.self, from: parts.jsonData)
        outputMarkdown = lessonResponse?.data?.lessonMarkdown ?? ""
    }

    private func decodeQuizResponse() throws {
        let parts = StreamResponseParser.split(fullResponse)
        parsedJSON = parts.jsonData
        quizResponse = try StreamResponseParser.decode(QuizResponse.self, from: parts.jsonData)
        outputMarkdown = ""
    }

    private func clearResults() {
        outputMarkdown = ""
        fullResponse = ""
        parsedJSON = nil
        askResponse = nil
        lessonResponse = nil
        quizResponse = nil
        error = nil
    }
}
