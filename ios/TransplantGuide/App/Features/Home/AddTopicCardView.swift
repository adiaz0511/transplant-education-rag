import SwiftUI

struct AddTopicCardView: View {
    enum CardStyle: Equatable {
        case dashboard
        case library

        var width: CGFloat {
            switch self {
            case .dashboard:
                return 250
            case .library:
                return 0
            }
        }

        var height: CGFloat {
            switch self {
            case .dashboard:
                return 215
            case .library:
                return 190
            }
        }

        var titleHeight: CGFloat {
            switch self {
            case .dashboard:
                return 58
            case .library:
                return 54
            }
        }

        var detailHeight: CGFloat {
            switch self {
            case .dashboard:
                return 36
            case .library:
                return 32
            }
        }

        var actionHeight: CGFloat {
            switch self {
            case .dashboard:
                return 46
            case .library:
                return 42
            }
        }
    }

    static let cardWidth: CGFloat = 250

    let topic: ManualTopicDefinition
    let onAdd: (ManualTopicDefinition) -> Void
    let style: CardStyle

    init(
        topic: ManualTopicDefinition,
        onAdd: @escaping (ManualTopicDefinition) -> Void,
        style: CardStyle = .dashboard
    ) {
        self.topic = topic
        self.onAdd = onAdd
        self.style = style
    }

    var body: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 12) {
                    topicIcon

                    VStack(alignment: .leading, spacing: 0) {
                        Text(topic.title)
                            .font(.subheadline.weight(.black))
                            .lineLimit(3)
                            .frame(height: style.titleHeight, alignment: .center)
                    }
                }

                Text(topic.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .frame(height: style.detailHeight, alignment: .topLeading)

                Spacer(minLength: style == .dashboard ? 6 : 4)

                Button {
                    onAdd(topic)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                            .font(.caption.weight(.bold))

                        Text("Add topic")
                            .font(.caption.weight(.black))

                        Spacer(minLength: 0)

                        Image(systemName: "arrow.right")
                            .font(.caption.weight(.bold))
                    }
                    .foregroundStyle(Color(red: 0.89, green: 0.50, blue: 0.10))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color(red: 1.0, green: 0.95, blue: 0.88))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color(red: 0.98, green: 0.78, blue: 0.53), lineWidth: 1.5)
                    )
                }
                .buttonStyle(.plain)
                .frame(height: style.actionHeight)
            }
        }
        .frame(height: style.height)
    }

    private var topicIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(red: 1.0, green: 0.95, blue: 0.88))

            Image(systemName: "books.vertical.fill")
                .font(.headline.weight(.black))
                .foregroundStyle(Color(red: 0.89, green: 0.50, blue: 0.10))
        }
        .frame(width: 42, height: 42)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(red: 0.98, green: 0.78, blue: 0.53).opacity(0.16))
        )
    }
}
