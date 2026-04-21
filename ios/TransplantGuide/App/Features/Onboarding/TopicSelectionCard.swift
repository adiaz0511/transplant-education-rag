import SwiftUI

struct TopicSelectionCard: View {
    let tiltIndex: Int
    let topic: ManualTopicDefinition
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            AppCard {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .top, spacing: 12) {
                        Text(topic.title)
                            .font(.headline)
                            .multilineTextAlignment(.leading)

                        Spacer()

                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .font(.title3)
                            .foregroundStyle(
                                isSelected ? Color(red: 0.17, green: 0.58, blue: 0.31) : .secondary
                            )
                    }

                    Text(topic.detail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(
                        isSelected ? Color(red: 0.17, green: 0.58, blue: 0.31) : .clear,
                        lineWidth: 2
                    )
            )
            .rotationEffect(.degrees(rotationAngle))
        }
        .buttonStyle(DuolingoCardPressStyle())
    }

    private var rotationAngle: Double {
        let magnitudeSeed = topic.slug.unicodeScalars.map(\.value).reduce(0, +) % 3
        let magnitude = Double(magnitudeSeed) + 0.8
        let direction = tiltIndex.isMultiple(of: 2) ? -1.0 : 1.0
        return magnitude * direction
    }
}
