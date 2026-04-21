import SwiftUI

struct DuolingoCardPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .offset(y: configuration.isPressed ? 3 : 0)
            .animation(.bouncy(duration: 0.22), value: configuration.isPressed)
    }
}
