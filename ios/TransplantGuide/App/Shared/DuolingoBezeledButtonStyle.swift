import SwiftUI

struct DuolingoBezeledButtonStyle: ButtonStyle {
    var fillColor: Color = Color(red: 0.12, green: 0.46, blue: 0.88)
    var shadowColor: Color = Color(red: 0.07, green: 0.31, blue: 0.63)
    var foregroundColor: Color = .white
    var cornerRadius: CGFloat = 22

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .background(
                ZStack(alignment: .top) {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(shadowColor)
                        .offset(y: 5)

                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(fillColor)
                        .overlay(
                            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                        .offset(y: configuration.isPressed ? 3 : 0)
                }
            )
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.bouncy(duration: 0.22), value: configuration.isPressed)
    }
}
