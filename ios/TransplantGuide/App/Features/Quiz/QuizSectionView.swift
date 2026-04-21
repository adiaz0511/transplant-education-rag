import SwiftUI

struct QuizSectionView: View {
    let questions: [QuizQuestion]?

    var body: some View {
        if let questions, !questions.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Quiz")
                    .font(.headline)

                ForEach(Array(questions.enumerated()), id: \.offset) { index, question in
                    QuizQuestionView(index: index, question: question)
                }
            }
        }
    }
}
