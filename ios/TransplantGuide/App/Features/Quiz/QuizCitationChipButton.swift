import SwiftUI

struct QuizCitationChipButton: View {
    let citation: QuizCitationSheetItem
    let prefersPopover: Bool
    let onSelect: () -> Void

    @State private var showsPopover = false

    var body: some View {
        Button {
            if prefersPopover {
                showsPopover = true
            } else {
                onSelect()
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "books.vertical.fill")
                    .font(.caption.weight(.black))

                Text("[\(citation.displayIndex)]")
                    .font(.subheadline.weight(.black))
            }
            .foregroundStyle(Color(red: 0.16, green: 0.46, blue: 0.72))
            .frame(maxWidth: .infinity)
            .frame(minHeight: 44)
            .padding(.horizontal, 12)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.white.opacity(0.96))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(Color(red: 0.78, green: 0.87, blue: 0.98), lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .contentShape(Capsule(style: .continuous))
        .accessibilityLabel("Source \(citation.displayIndex)")
        .popover(isPresented: $showsPopover, attachmentAnchor: .rect(.bounds), arrowEdge: .bottom) {
            QuizCitationSourceSheet(citation: citation)
                .frame(minWidth: 360, idealWidth: 420, maxWidth: 460)
                .presentationCompactAdaptation(.sheet)
        }
    }
}
