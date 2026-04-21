import SwiftUI

struct HomeSection<Content: View>: View {
    struct HeaderAction {
        let title: String
        let action: () -> Void
    }

    let title: String
    let subtitle: String?
    let headerAction: HeaderAction?
    let content: Content

    init(
        title: String,
        subtitle: String? = nil,
        headerAction: HeaderAction? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.headerAction = headerAction
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.title2.bold())

                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 0)

                if let headerAction {
                    Button(action: headerAction.action) {
                        Text(headerAction.title)
                            .font(.subheadline.weight(.bold))
                            .multilineTextAlignment(.trailing)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color(red: 0.25, green: 0.45, blue: 0.20))
                    .padding(.top, 4)
                }
            }

            VStack(spacing: 12) {
                content
            }
        }
    }
}
