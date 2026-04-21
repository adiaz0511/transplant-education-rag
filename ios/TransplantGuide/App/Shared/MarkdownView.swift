import SwiftUI
import Textual

struct MarkdownView: View {
    let text: String

    var body: some View {
        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            EmptyView()
        } else {
            StructuredText(markdown: text)
                .textual.structuredTextStyle(.gitHub)
                .frame(maxWidth: .infinity, alignment: .leading)
                .environment(\.openURL, OpenURLAction { url in
                    .systemAction(url)
                })
        }
    }
}
