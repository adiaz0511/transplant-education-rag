import SwiftUI

struct HomeInstructionsInputView: View {
    @Binding var instructions: String

    let mode: AppMode
    let isFocused: FocusState<Bool>.Binding

    var body: some View {
        if mode.supportsInstructions {
            VStack(alignment: .leading, spacing: 8) {
                Text(mode.instructionsTitle)
                    .font(.headline)

                TextField(mode.instructionsPlaceholder, text: $instructions, axis: .vertical)
                    .focused(isFocused)
                    .lineLimit(2...5)
                    .padding(12)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }
}
