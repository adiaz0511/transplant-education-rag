import SwiftUI
import SwiftData

struct QuizDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.modelContext) private var modelContext
    @Environment(GenerationCoordinator.self) private var generationCoordinator

    let quiz: Quiz
    let lesson: Lesson?
    let showsBackToLessonButton: Bool

    @State private var selectedAnswer: String?
    @State private var selectedCitation: QuizCitationSheetItem?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                headerCard

                if isCompleted {
                    resultsCard
                } else if let currentQuestion {
                    questionCard(currentQuestion)
                }
            }
            .padding(24)
            .frame(maxWidth: 900, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.99, green: 0.97, blue: 0.89),
                    Color(red: 0.95, green: 0.98, blue: 1.0)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        )
        .safeAreaInset(edge: .bottom) {
            if isCompleted {
                completedBottomActionBar
            } else if let currentQuestion {
                bottomActionBar(for: currentQuestion)
            }
        }
        .navigationTitle(quiz.title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: syncSelectionFromStoredState)
        .onChange(of: quiz.activeQuestionIndex) { _, _ in
            syncSelectionFromStoredState()
        }
        .onChange(of: quiz.awaitingAdvance) { _, _ in
            syncSelectionFromStoredState()
        }
        .sheet(item: compactSelectedCitationBinding) { citation in
            QuizCitationSourceSheet(citation: citation)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    private var headerCard: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 14) {
                Text(quiz.title)
                    .font(.largeTitle.bold())

                if let lesson {
                    Text(lesson.title)
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }

                ProgressView(value: progressValue)
                    .tint(Color(red: 0.18, green: 0.70, blue: 0.28))

                Text(progressLabel)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var resultsCard: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 18) {
                Text(resultsTitle)
                    .font(.title.bold())

                Text("You answered \(correctAnswerCount) out of \(orderedQuestions.count) questions correctly.")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                if !orderedQuestions.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(orderedQuestions, id: \.id) { question in
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: question.wasCorrect == true ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundStyle(question.wasCorrect == true ? Color(red: 0.18, green: 0.64, blue: 0.35) : Color(red: 0.92, green: 0.42, blue: 0.16))

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(question.prompt)
                                        .font(.subheadline.weight(.semibold))
                                        .lineLimit(2)

                                    if let selectedAnswer = question.selectedAnswer {
                                        Text("Your answer: \(selectedAnswer)")
                                            .font(.footnote)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func questionCard(_ question: StoredQuizQuestion) -> some View {
        AppCard {
            VStack(alignment: .leading, spacing: 18) {
                Text("Question \(quiz.activeQuestionIndex + 1)")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                Text(question.prompt)
                    .font(.title3.bold())

                VStack(spacing: 12) {
                    ForEach(options(for: question), id: \.self) { option in
                        optionButton(for: option, question: question)
                    }
                }
            }
        }
    }

    private func optionButton(for option: String, question: StoredQuizQuestion) -> some View {
        Button {
            guard !quiz.awaitingAdvance else { return }
            selectedAnswer = option
        } label: {
            HStack(spacing: 12) {
                Image(systemName: iconName(for: option, question: question))
                    .font(.headline)

                Text(option)
                    .font(.body.weight(.semibold))
                    .multilineTextAlignment(.leading)

                Spacer()
            }
            .foregroundStyle(optionTextColor(for: option, question: question))
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(optionFillColor(for: option, question: question))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(optionBorderColor(for: option, question: question), lineWidth: 2)
            )
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(quiz.awaitingAdvance)
        .scaleEffect(selectedAnswer == option && !quiz.awaitingAdvance ? 1.01 : 1.0)
        .animation(.bouncy(duration: 0.28), value: selectedAnswer)
    }

    private func bottomActionBar(for question: StoredQuizQuestion) -> some View {
        VStack(spacing: 14) {
            if quiz.awaitingAdvance {
                feedbackCard(for: question)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            Button {
                if quiz.awaitingAdvance {
                    withAnimation(.bouncy(duration: 0.35)) {
                        generationCoordinator.advanceQuiz(quiz, modelContext: modelContext)
                    }
                } else if let selectedAnswer {
                    withAnimation(.bouncy(duration: 0.35)) {
                        generationCoordinator.submitAnswer(
                            selectedAnswer: selectedAnswer,
                            for: question,
                            in: quiz,
                            modelContext: modelContext
                        )
                    }
                }
            } label: {
                HStack {
                    Spacer()
                    Text(primaryButtonTitle)
                        .font(.headline.weight(.black))
                    Spacer()
                }
            }
            .buttonStyle(DuolingoBezeledButtonStyle())
            .disabled(!quiz.awaitingAdvance && selectedAnswer == nil)
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 12)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.99, green: 0.97, blue: 0.89).opacity(0),
                    Color(red: 0.99, green: 0.97, blue: 0.89)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .animation(.bouncy(duration: 0.35), value: quiz.awaitingAdvance)
    }

    private var completedBottomActionBar: some View {
        HStack(alignment: .center, spacing: 16) {
            Button {
                dismiss()
            } label: {
                HStack {
                    Spacer()
                    Image(systemName: "xmark")
                        .font(.headline.weight(.black))
                    Spacer()
                }
            }
            .buttonStyle(
                DuolingoBezeledButtonStyle(
                    fillColor: Color(red: 0.98, green: 0.95, blue: 0.85),
                    shadowColor: Color(red: 0.88, green: 0.82, blue: 0.64),
                    foregroundColor: Color(red: 0.36, green: 0.27, blue: 0.14),
                    cornerRadius: 18
                )
            )
            .frame(width: 96)
            .accessibilityLabel("Close quiz")

            Button {
                withAnimation(.bouncy(duration: 0.35)) {
                    generationCoordinator.resetQuizProgress(quiz, modelContext: modelContext)
                }
            } label: {
                HStack {
                    Spacer()
                    Text("Retake quiz")
                        .font(.headline.weight(.black))
                    Spacer()
                }
            }
            .buttonStyle(DuolingoBezeledButtonStyle())
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 12)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.99, green: 0.97, blue: 0.89).opacity(0),
                    Color(red: 0.99, green: 0.97, blue: 0.89)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private func feedbackCard(for question: StoredQuizQuestion) -> some View {
        let isCorrect = question.wasCorrect == true

        return AppCard {
            VStack(alignment: .leading, spacing: 10) {
                Text(isCorrect ? "Correct" : "Not quite")
                    .font(.title3.bold())
                    .foregroundStyle(isCorrect ? Color(red: 0.12, green: 0.48, blue: 0.22) : Color(red: 0.73, green: 0.22, blue: 0.12))

                if !isCorrect, let answer = question.answer {
                    Text("Correct answer: \(answer)")
                        .font(.headline)
                }

                if let explanation = question.explanation, !explanation.isEmpty {
                    let citationContent = citationContent(for: explanation)

                    Text(citationContent.text)
                        .foregroundStyle(.secondary)

                    if !citationContent.citations.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Sources")
                                .font(.caption.weight(.black))
                                .foregroundStyle(Color(red: 0.39, green: 0.43, blue: 0.52))
                                .textCase(.uppercase)
                                .tracking(0.6)
                                .padding(.top, 6)

                            citationChips(citationContent.citations)
                        }
                    }
                }
            }
        }
    }

    private func citationChips(_ citations: [QuizCitationSheetItem]) -> some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 72), spacing: 12, alignment: .leading)],
            alignment: .leading,
            spacing: 12
        ) {
            ForEach(citations) { citation in
                QuizCitationChipButton(
                    citation: citation,
                    prefersPopover: horizontalSizeClass == .regular
                ) {
                    selectedCitation = citation
                }
            }
        }
    }

    private func citationContent(for explanation: String) -> QuizCitationContent {
        let nsExplanation = explanation as NSString
        let pattern = #"\[(\d+)\]"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return QuizCitationContent(text: explanation, citations: [])
        }

        let matches = regex.matches(
            in: explanation,
            range: NSRange(location: 0, length: nsExplanation.length)
        )

        guard !matches.isEmpty else {
            return QuizCitationContent(text: explanation, citations: [])
        }

        var cleaned = explanation
        for match in matches.reversed() {
            cleaned = (cleaned as NSString).replacingCharacters(in: match.range, with: "")
        }

        cleaned = cleaned
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let citations = matches.compactMap { match -> QuizCitationSheetItem? in
            guard match.numberOfRanges > 1 else { return nil }
            let indexString = nsExplanation.substring(with: match.range(at: 1))
            guard let index = Int(indexString),
                  quiz.sources.indices.contains(index) else { return nil }

            return QuizCitationSheetItem(
                sourceIndex: index,
                sourceText: quiz.sources[index]
            )
        }

        let uniqueCitations = Dictionary(
            uniqueKeysWithValues: citations.map { ($0.id, $0) }
        ).values.sorted { $0.sourceIndex < $1.sourceIndex }

        return QuizCitationContent(text: cleaned, citations: uniqueCitations)
    }

    private var orderedQuestions: [StoredQuizQuestion] {
        quiz.questions.sorted { $0.order < $1.order }
    }

    private var currentQuestion: StoredQuizQuestion? {
        guard quiz.activeQuestionIndex < orderedQuestions.count else { return nil }
        return orderedQuestions[quiz.activeQuestionIndex]
    }

    private var isCompleted: Bool {
        quiz.completedAt != nil || quiz.activeQuestionIndex >= orderedQuestions.count
    }

    private var correctAnswerCount: Int {
        orderedQuestions.filter { $0.wasCorrect == true }.count
    }

    private var resultsTitle: String {
        guard !orderedQuestions.isEmpty else { return "Quiz complete" }

        let scoreRatio = Double(correctAnswerCount) / Double(orderedQuestions.count)

        switch scoreRatio {
        case 1.0:
            return "Perfect score"
        case 0.8...:
            return "Nice work"
        case 0.4...:
            return "Good effort"
        default:
            return "Keep practicing"
        }
    }

    private var progressValue: Double {
        guard !orderedQuestions.isEmpty else { return 0 }
        return Double(quiz.answeredQuestionCount) / Double(orderedQuestions.count)
    }

    private var progressLabel: String {
        if isCompleted {
            return "All \(orderedQuestions.count) questions answered"
        }

        return "\(quiz.answeredQuestionCount) of \(orderedQuestions.count) questions answered"
    }

    private var primaryButtonTitle: String {
        if quiz.awaitingAdvance {
            return quiz.activeQuestionIndex == orderedQuestions.count - 1 ? "See results" : "Continue"
        }

        return "Check"
    }

    private var compactSelectedCitationBinding: Binding<QuizCitationSheetItem?> {
        Binding(
            get: {
                horizontalSizeClass == .regular ? nil : selectedCitation
            },
            set: { newValue in
                selectedCitation = newValue
            }
        )
    }

    private func syncSelectionFromStoredState() {
        guard let currentQuestion else {
            selectedAnswer = nil
            return
        }

        selectedAnswer = currentQuestion.selectedAnswer
    }

    private func options(for question: StoredQuizQuestion) -> [String] {
        let trimmedOptions = question.options
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if !trimmedOptions.isEmpty {
            return trimmedOptions
        }

        if question.type == "true_false" {
            return ["True", "False"]
        }

        return []
    }

    private func optionFillColor(for option: String, question: StoredQuizQuestion) -> Color {
        if quiz.awaitingAdvance {
            if option == question.answer {
                return Color(red: 0.86, green: 0.97, blue: 0.88)
            }

            if option == question.selectedAnswer, question.wasCorrect == false {
                return Color(red: 1.0, green: 0.91, blue: 0.89)
            }

            return Color.white
        }

        return selectedAnswer == option ? Color(red: 0.90, green: 0.95, blue: 1.0) : Color.white
    }

    private func optionBorderColor(for option: String, question: StoredQuizQuestion) -> Color {
        if quiz.awaitingAdvance {
            if option == question.answer {
                return Color(red: 0.18, green: 0.64, blue: 0.35)
            }

            if option == question.selectedAnswer, question.wasCorrect == false {
                return Color(red: 0.92, green: 0.42, blue: 0.16)
            }

            return Color.black.opacity(0.08)
        }

        return selectedAnswer == option ? Color(red: 0.20, green: 0.58, blue: 0.83) : Color.black.opacity(0.08)
    }

    private func optionTextColor(for option: String, question: StoredQuizQuestion) -> Color {
        if quiz.awaitingAdvance {
            if option == question.answer {
                return Color(red: 0.12, green: 0.48, blue: 0.22)
            }

            if option == question.selectedAnswer, question.wasCorrect == false {
                return Color(red: 0.73, green: 0.22, blue: 0.12)
            }
        }

        return .primary
    }

    private func iconName(for option: String, question: StoredQuizQuestion) -> String {
        if quiz.awaitingAdvance {
            if option == question.answer {
                return "checkmark.circle.fill"
            }

            if option == question.selectedAnswer, question.wasCorrect == false {
                return "xmark.circle.fill"
            }
        }

        return selectedAnswer == option ? "largecircle.fill.circle" : "circle"
    }
}
