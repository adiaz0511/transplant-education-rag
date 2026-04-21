import SwiftUI

struct AskSourceReferenceButton: View {
    let reference: AskSourceSheetItem
    let prefersPopover: Bool
    let onSelectSource: (AskSourceSheetItem) -> Void

    @State private var showsPopover = false

    var body: some View {
        Button {
            if prefersPopover {
                showsPopover = true
            } else {
                onSelectSource(reference)
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "book.closed.fill")
                    .font(.caption.weight(.black))

                Text(reference.label)
                    .font(.subheadline.weight(.black))
            }
            .frame(maxWidth: .infinity, minHeight: 46)
        }
        .buttonStyle(
            DuolingoBezeledButtonStyle(
                fillColor: Color(red: 0.87, green: 0.92, blue: 1.0),
                shadowColor: Color(red: 0.73, green: 0.81, blue: 0.94),
                foregroundColor: Color(red: 0.14, green: 0.27, blue: 0.52),
                cornerRadius: 18
            )
        )
        .popover(isPresented: $showsPopover, attachmentAnchor: .rect(.bounds), arrowEdge: .bottom) {
            AskSourceDetailView(source: reference)
                .frame(minWidth: 360, idealWidth: 420, maxWidth: 460)
                .presentationCompactAdaptation(.sheet)
        }
    }
}
