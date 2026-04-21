import SwiftUI

struct AskInfoBox<Content: View>: View {
    let title: String
    let fillColor: Color
    let content: Content

    init(
        title: String,
        fillColor: Color,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.fillColor = fillColor
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline.weight(.black))

            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(fillColor)
        )
    }
}
