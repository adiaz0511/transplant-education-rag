import SwiftUI

struct DashboardAskCard: View {
    let prompts: [AskStarterPrompt]
    let onOpenAsk: () -> Void
    let onSelectPrompt: (String) -> Void

    var body: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 18) {
                header
                promptChips
            }
        }
        .overlay(cardOverlay)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 20) {
            VStack(alignment: .leading, spacing: 10) {
                Label {
                    Text("Question Corner")
                        .font(.title3.weight(.black))
                } icon: {
                    Image(systemName: "sparkle.magnifyingglass")
                        .font(.title3.weight(.black))
                        .foregroundStyle(Color(red: 0.16, green: 0.64, blue: 0.62))
                }

                Text("Quick, source-backed answers from the manual.")
                    .font(.subheadline)
                    .foregroundStyle(Color(red: 0.22, green: 0.30, blue: 0.39))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            Button(action: onOpenAsk) {
                HStack(spacing: 8) {
                    Image(systemName: "message.fill")
                        .font(.subheadline.weight(.black))

                    Text("Open Ask")
                        .font(.subheadline.weight(.black))
                }
            }
            .buttonStyle(
                DuolingoBezeledButtonStyle(
                    fillColor: Color(red: 0.17, green: 0.67, blue: 0.64),
                    shadowColor: Color(red: 0.08, green: 0.47, blue: 0.46),
                    cornerRadius: 18
                )
            )
        }
    }

    private var promptChips: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Try one of these")
                .font(.footnote.weight(.black))
                .foregroundStyle(Color(red: 0.12, green: 0.48, blue: 0.47))

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) {
                    ForEach(prompts) { prompt in
                        promptButton(for: prompt)
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    ForEach(prompts) { prompt in
                        promptButton(for: prompt)
                    }
                }
            }
        }
    }

    private func promptButton(for prompt: AskStarterPrompt) -> some View {
        Button {
            onSelectPrompt(prompt.title)
        } label: {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "quote.bubble.fill")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color(red: 0.16, green: 0.64, blue: 0.62))

                Text(prompt.title)
                    .font(.subheadline.weight(.semibold))
                    .multilineTextAlignment(.leading)
                    .foregroundStyle(Color(red: 0.24, green: 0.29, blue: 0.35))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(0.92))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color(red: 0.74, green: 0.89, blue: 0.88), lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var cardOverlay: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .stroke(
                LinearGradient(
                    colors: [
                        Color(red: 0.54, green: 0.86, blue: 0.84),
                        Color(red: 0.80, green: 0.95, blue: 0.93)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1.5
            )
    }
}
