import SwiftUI

struct BottomPrimaryButton: View {
    let title: String
    var isDisabled: Bool = false
    var showsBackButton: Bool = false
    var isMovingForward: Bool = true
    var backAction: (() -> Void)? = nil
    let action: () -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            LinearGradient(
                colors: [
                    Color.clear,
                    Color(red: 0.97, green: 0.98, blue: 0.99).opacity(0.9),
                    Color(red: 0.97, green: 0.98, blue: 0.99)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 220)
            .offset(y: 100)

            HStack(spacing: 14) {
                if showsBackButton, let backAction {
                    Button(action: backAction) {
                        Image(systemName: "chevron.left")
                            .font(.headline.bold())
                            .frame(width: 56, height: 56)
                    }
                    .buttonStyle(
                        DuolingoBezeledButtonStyle(
                            fillColor: Color.white,
                            shadowColor: Color(red: 0.80, green: 0.84, blue: 0.89),
                            foregroundColor: Color(red: 0.18, green: 0.36, blue: 0.61),
                            cornerRadius: 18
                        )
                    )
                    .transition(backButtonTransition)
                }

                Button(action: action) {
                    Text(title)
                        .font(.title3.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(
                    DuolingoBezeledButtonStyle(
                        fillColor: isDisabled ? Color.gray.opacity(0.45) : Color(red: 0.12, green: 0.46, blue: 0.88),
                        shadowColor: isDisabled ? Color.gray.opacity(0.65) : Color(red: 0.07, green: 0.31, blue: 0.63)
                    )
                )
                .disabled(isDisabled)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 18)
        }
        .animation(.smooth(duration: 0.3), value: showsBackButton)
    }

    private var backButtonTransition: AnyTransition {
        let insertionEdge: Edge = isMovingForward ? .leading : .trailing
        let removalEdge: Edge = isMovingForward ? .trailing : .leading

        return .asymmetric(
            insertion: .move(edge: insertionEdge).combined(with: .opacity),
            removal: .move(edge: removalEdge).combined(with: .opacity)
        )
    }
}
