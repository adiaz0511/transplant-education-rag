import SwiftUI
import UIKit

struct AskMessageRow: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var copiedMessageID: UUID?

    let message: ChatMessage
    let onSelectSource: (AskSourceSheetItem) -> Void

    var body: some View {
        HStack {
            if message.role == .assistant {
                assistantMessage
                Spacer(minLength: 0)
            } else {
                Spacer(minLength: 0)
                userMessage
            }
        }
    }

    private var userMessage: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Question")
                    .font(.caption.weight(.black))
                    .foregroundStyle(Color.white.opacity(0.82))

                Spacer(minLength: 0)

                copyButton(text: message.content, isLight: true)
            }

            Text(message.content)
                .font(.body.weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .frame(maxWidth: horizontalSizeClass == .regular ? 420 : 320, alignment: .leading)
        .background(
            ZStack(alignment: .top) {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color(red: 0.12, green: 0.49, blue: 0.88))
                    .offset(y: 6)

                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color(red: 0.20, green: 0.58, blue: 0.83))
            }
        )
    }

    private var assistantMessage: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .center, spacing: 12) {
                    Text("Answer")
                        .font(.headline.weight(.black))

                    Spacer(minLength: 0)

                    copyButton(text: message.content, isLight: false)
                }

                MarkdownView(text: message.content)
                    .textSelection(.enabled)

                if !message.keyPoints.isEmpty {
                    AskInfoBox(
                        title: "Key points",
                        fillColor: Color(red: 0.95, green: 0.98, blue: 0.91)
                    ) {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(message.keyPoints, id: \.self) { point in
                                HStack(alignment: .top, spacing: 10) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(Color(red: 0.15, green: 0.61, blue: 0.31))
                                        .padding(.top, 2)

                                    Text(point)
                                        .font(.subheadline.weight(.semibold))
                                }
                            }
                        }
                    }
                }

                if !sourceReferences.isEmpty {
                    AskInfoBox(
                        title: "Sources",
                        fillColor: Color(red: 0.95, green: 0.97, blue: 1.0)
                    ) {
                        LazyVGrid(
                            columns: [
                                GridItem(.adaptive(minimum: horizontalSizeClass == .regular ? 130 : 110), spacing: 10)
                            ],
                            alignment: .leading,
                            spacing: 10
                        ) {
                            ForEach(sourceReferences) { reference in
                                AskSourceReferenceButton(
                                    reference: reference,
                                    prefersPopover: horizontalSizeClass == .regular,
                                    onSelectSource: onSelectSource
                                )
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: horizontalSizeClass == .regular ? 760 : .infinity, alignment: .leading)
        .padding(.trailing, horizontalSizeClass == .regular ? 120 : 36)
    }

    private var sourceReferences: [AskSourceSheetItem] {
        let citedIndices = Set(Self.citationIndices(in: message.content))

        let pairs: [(Int, String)]
        if message.sourceIndices.count == message.sources.count, !message.sourceIndices.isEmpty {
            pairs = Array(zip(message.sourceIndices, message.sources))
        } else {
            pairs = message.sources.enumerated().map { ($0.offset, $0.element) }
        }

        let filteredPairs: [(Int, String)]
        if citedIndices.isEmpty {
            filteredPairs = pairs
        } else {
            filteredPairs = pairs.filter { citedIndices.contains($0.0) }
        }

        return filteredPairs.map { index, source in
            AskSourceSheetItem(sourceIndex: index, sourceText: source)
        }
    }

    private static func citationIndices(in text: String) -> [Int] {
        guard let regex = try? NSRegularExpression(pattern: #"\[(\d+)\]"#) else {
            return []
        }

        let range = NSRange(text.startIndex..., in: text)
        return regex.matches(in: text, range: range).compactMap { match in
            guard match.numberOfRanges > 1,
                  let captureRange = Range(match.range(at: 1), in: text) else {
                return nil
            }

            return Int(text[captureRange])
        }
    }

    @ViewBuilder
    private func copyButton(text: String, isLight: Bool) -> some View {
        Button {
            UIPasteboard.general.string = text
            withAnimation(.bouncy(duration: 0.28)) {
                copiedMessageID = message.id
            }

            Task {
                try? await Task.sleep(nanoseconds: 1_200_000_000)
                guard copiedMessageID == message.id else { return }
                await MainActor.run {
                    withAnimation(.easeOut(duration: 0.22)) {
                        copiedMessageID = nil
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                    .font(.caption.weight(.black))

                Text(isCopied ? "Copied" : "Copy")
                    .font(.caption.weight(.black))
            }
            .frame(minWidth: 78, minHeight: 36)
            .padding(.horizontal, 10)
            .background(
                Capsule(style: .continuous)
                    .fill(copyButtonFillColor(isLight: isLight))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(copyButtonBorderColor(isLight: isLight), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .foregroundStyle(copyButtonForegroundColor(isLight: isLight))
        .contentShape(Capsule(style: .continuous))
        .accessibilityLabel("Copy message")
        .scaleEffect(isCopied ? 1.04 : 1)
    }

    private var isCopied: Bool {
        copiedMessageID == message.id
    }

    private func copyButtonFillColor(isLight: Bool) -> Color {
        if isCopied {
            return isLight
                ? Color.white.opacity(0.26)
                : Color(red: 0.86, green: 0.97, blue: 0.90)
        }

        return isLight
            ? Color.white.opacity(0.16)
            : Color(red: 0.95, green: 0.97, blue: 1.0)
    }

    private func copyButtonBorderColor(isLight: Bool) -> Color {
        if isCopied {
            return isLight
                ? Color.white.opacity(0.38)
                : Color(red: 0.58, green: 0.83, blue: 0.66)
        }

        return isLight
            ? Color.white.opacity(0.12)
            : Color(red: 0.84, green: 0.89, blue: 0.96)
    }

    private func copyButtonForegroundColor(isLight: Bool) -> Color {
        if isCopied {
            return isLight ? .white : Color(red: 0.16, green: 0.52, blue: 0.24)
        }

        return isLight ? .white : Color(red: 0.14, green: 0.27, blue: 0.52)
    }
}
