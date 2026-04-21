import SwiftUI

struct AskResultsView: View {
    let markdown: String
    let response: AskResponse?

    var body: some View {
        MarkdownSectionView(title: "Answer", markdown: markdown)
        StringListSectionView(title: "Key Points", items: response?.data?.keyPoints)
        StringListSectionView(title: "Sources", items: response?.sources)
    }
}
