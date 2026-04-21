import SwiftUI

struct QuizResultsView: View {
    let markdown: String
    let response: QuizResponse?

    var body: some View {
        QuizSectionView(questions: response?.data?.questions)
        StringListSectionView(title: "Sources", items: response?.sources)
    }
}
