import SwiftUI

struct AskThreadCard: View {
    let thread: ChatThread
    let isSelected: Bool
    let onRename: () -> Void
    let onDelete: () -> Void
    let action: () -> Void

    @State private var showsDeleteConfirmation = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                Text(threadTitle)
                    .font(.subheadline.weight(.black))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Text(thread.updatedAt.formatted(.dateTime.month(.abbreviated).day().hour().minute()))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(isSelected ? Color.white.opacity(0.86) : .secondary)

                Spacer(minLength: 0)
            }
            .padding(14)
            .frame(width: 220, height: 104, alignment: .topLeading)
            .background(background)
        }
        .buttonStyle(.plain)
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .contextMenu {
            Button("Rename", systemImage: "pencil") {
                onRename()
            }

            Button("Delete", systemImage: "trash", role: .destructive) {
                showsDeleteConfirmation = true
            }
        }
        .confirmationDialog(
            "Delete conversation?",
            isPresented: $showsDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                onDelete()
            }

            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This conversation and its messages will be removed from this device.")
        }
    }

    private var threadTitle: String {
        let trimmed = thread.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "New chat" : trimmed
    }

    private var background: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(isSelected ? Color(red: 0.08, green: 0.47, blue: 0.46) : Color(red: 0.85, green: 0.90, blue: 0.95))
                .offset(y: 5)

            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(isSelected ? Color(red: 0.17, green: 0.67, blue: 0.64) : Color.white.opacity(0.95))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(isSelected ? 0.22 : 0.85), lineWidth: 1)
                )
        }
        .foregroundStyle(isSelected ? .white : Color(red: 0.17, green: 0.23, blue: 0.31))
    }
}
