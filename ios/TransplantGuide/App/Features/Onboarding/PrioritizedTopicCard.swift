import SwiftUI

struct PrioritizedTopicCard: View {
    let index: Int
    let tiltIndex: Int
    let topic: ManualTopicDefinition
    let isFirst: Bool
    let isLast: Bool
    let moveUpAction: () -> Void
    let moveDownAction: () -> Void

    var body: some View {
        AppCard {
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .center, spacing: 4) {
                    Text("\(index + 1)")
                        .font(.title2.bold().monospacedDigit())

                    Text(index == 0 ? "First" : "Queue")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .frame(width: 56)

                VStack(alignment: .leading, spacing: 6) {
                    Text(topic.title)
                        .font(.headline)

                    Text(topic.detail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                VStack(spacing: 10) {
                    Button(action: moveUpAction) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title3.bold())
                            .frame(width: 48, height: 48)
                    }
                    .buttonStyle(
                        DuolingoBezeledButtonStyle(
                            fillColor: Color(red: 0.41, green: 0.66, blue: 0.96),
                            shadowColor: Color(red: 0.20, green: 0.46, blue: 0.78),
                            cornerRadius: 16
                        )
                    )
                    .disabled(isFirst)

                    Button(action: moveDownAction) {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.title3.bold())
                            .frame(width: 48, height: 48)
                    }
                    .buttonStyle(
                        DuolingoBezeledButtonStyle(
                            fillColor: Color(red: 0.41, green: 0.66, blue: 0.96),
                            shadowColor: Color(red: 0.20, green: 0.46, blue: 0.78),
                            cornerRadius: 16
                        )
                    )
                    .disabled(isLast)
                }
            }
        }
        .rotationEffect(.degrees(rotationAngle))
        .padding(.vertical, 4)
        .contentTransition(.numericText())
    }

    private var rotationAngle: Double {
        let magnitudeSeed = topic.slug.unicodeScalars.map(\.value).reduce(0, +) % 3
        let magnitude = Double(magnitudeSeed) + 0.8
        let direction = tiltIndex.isMultiple(of: 2) ? -1.0 : 1.0
        return magnitude * direction
    }
}
