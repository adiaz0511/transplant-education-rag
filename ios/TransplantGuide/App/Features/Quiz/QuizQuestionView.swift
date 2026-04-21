import SwiftUI

struct QuizQuestionView: View {
    let index: Int
    let question: QuizQuestion

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(questionTitle)
                .font(.headline)

            Text(questionText)
                .font(.body.weight(.semibold))

            if let options = question.options, !options.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(options.enumerated()), id: \.offset) { optionIndex, option in
                        Text(formattedOption(option, index: optionIndex))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }

            if let answer = question.answer, !answer.isEmpty {
                Text("Answer: \(answer)")
                    .font(.body.weight(.semibold))
            }

            if let explanation = question.explanation, !explanation.isEmpty {
                Text("Explanation: \(explanation)")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
    }

    private var questionTitle: String {
        "Question \(index + 1)\(formattedType.map { " - \($0)" } ?? "")"
    }

    private var questionText: String {
        question.question ?? "Untitled question"
    }

    private var formattedType: String? {
        guard let type = question.type?.trimmingCharacters(in: .whitespacesAndNewlines),
              !type.isEmpty else {
            return nil
        }

        return type
            .replacingOccurrences(of: "_", with: " ")
            .split(separator: " ")
            .map { $0.capitalized }
            .joined(separator: " ")
    }

    private func formattedOption(_ option: String, index: Int) -> String {
        let trimmedOption = option.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedOption.isEmpty else {
            return ""
        }

        if hasOptionPrefix(trimmedOption) {
            return "- \(trimmedOption)"
        }

        let label = String(UnicodeScalar(65 + index) ?? UnicodeScalar(65))
        return "- \(label)) \(trimmedOption)"
    }

    private func hasOptionPrefix(_ option: String) -> Bool {
        guard let first = option.first, first.isLetter else {
            return false
        }

        return option.dropFirst().first == ")"
    }
}
