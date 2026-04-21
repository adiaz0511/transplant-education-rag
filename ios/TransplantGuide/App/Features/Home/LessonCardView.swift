import SwiftUI
import Textual

struct LessonCardView: View {
    enum CardStyle {
        case dashboard
        case library

        var height: CGFloat {
            switch self {
            case .dashboard:
                return 324
            case .library:
                return 286
            }
        }

        var titleHeight: CGFloat {
            switch self {
            case .dashboard:
                return 86
            case .library:
                return 66
            }
        }

        var previewHeight: CGFloat {
            switch self {
            case .dashboard:
                return 110
            case .library:
                return 84
            }
        }
    }

    static let dashboardWidth: CGFloat = 236

    let lesson: Lesson
    let style: CardStyle

    init(lesson: Lesson, style: CardStyle = .dashboard) {
        self.lesson = lesson
        self.style = style
    }

    var body: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 12) {
                    Text(lesson.title)
                        .font(.title3.weight(.black))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(3)
                        .frame(height: style.titleHeight, alignment: .topLeading)

                    StructuredText(markdown: previewMarkdown)
                        .id(previewMarkdown)
                        .textSelection(.disabled)
                        .textual.structuredTextStyle(.gitHub)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(5)
                        .truncationMode(.tail)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .frame(height: style.previewHeight, alignment: .topLeading)
                        .clipped()
                        .allowsHitTesting(false)
                }

                Spacer(minLength: 0)

                HStack {
                    Spacer()
                    readButton
                }
            }
        }
        .frame(height: style.height)
    }

    private var readButton: some View {
        HStack(spacing: 8) {
            Text("READ")
                .font(.subheadline.weight(.black))

            Image(systemName: "arrow.right")
                .font(.subheadline.weight(.black))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            ZStack(alignment: .top) {
                Capsule()
                    .fill(Color(red: 0.12, green: 0.56, blue: 0.22))
                    .offset(y: 4)

                Capsule()
                    .fill(Color(red: 0.18, green: 0.70, blue: 0.28))
            }
        )
    }

    private var previewMarkdown: String {
        let collapsed = lesson.content
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: #"[#*_>`\-\[\]\(\)]+"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !collapsed.isEmpty else { return "" }

        if collapsed.count <= 140 {
            return collapsed
        }

        let limitIndex = collapsed.index(collapsed.startIndex, offsetBy: 140)
        return String(collapsed[..<limitIndex]).trimmingCharacters(in: .whitespacesAndNewlines) + "..."
    }
}
