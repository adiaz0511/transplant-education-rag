import SwiftUI

struct HomeInputBarView: View {
    @Binding var input: String

    let mode: AppMode
    let isLoading: Bool
    let isInputFocused: FocusState<Bool>.Binding
    let runAction: () -> Void

    var body: some View {
        GlassEffectContainer(spacing: 12) {
            HStack(spacing: 12) {
                TextField(mode.inputPlaceholder, text: $input, axis: .vertical)
                    .focused(isInputFocused)
                    .lineLimit(1...3)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .glassEffect(.regular, in: Capsule())

                Button("Run", action: runAction)
                    .buttonStyle(.glassProminent)
                    .disabled(isLoading)
            }
        }
        .frame(maxWidth: .infinity)
    }
}
