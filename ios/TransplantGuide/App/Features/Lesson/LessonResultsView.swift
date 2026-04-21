import SwiftUI

struct LessonResultsView: View {
    let markdown: String
    let response: LessonResponse?

    var body: some View {
        if let title = response?.data?.title, !title.isEmpty {
            Text(title)
                .font(.title2.bold())
        }

        MarkdownSectionView(title: "Lesson", markdown: markdown)
        StringListSectionView(title: "Key Takeaways", items: response?.data?.keyTakeaways)
        StringListSectionView(title: "Sources", items: response?.sources)
    }
}
