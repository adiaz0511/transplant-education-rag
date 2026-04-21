import SwiftUI

struct ResultsView: View {
    let viewModel: AppViewModel

    var body: some View {
        switch viewModel.selectedMode {
        case .ask:
            AskResultsView(
                markdown: viewModel.outputMarkdown,
                response: viewModel.askResponse
            )
        case .lesson:
            LessonResultsView(
                markdown: viewModel.outputMarkdown,
                response: viewModel.lessonResponse
            )
        case .quiz:
            QuizResultsView(
                markdown: viewModel.outputMarkdown,
                response: viewModel.quizResponse
            )
        }
    }
}
