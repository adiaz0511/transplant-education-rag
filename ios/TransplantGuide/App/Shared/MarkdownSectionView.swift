import SwiftUI

struct MarkdownSectionView: View {
    let title: String
    let markdown: String?

    var body: some View {
        if let markdown, !markdown.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.headline)
                MarkdownView(text: markdown)
            }
        }
    }
}
