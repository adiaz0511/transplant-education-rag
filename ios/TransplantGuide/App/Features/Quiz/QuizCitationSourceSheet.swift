import SwiftUI

struct QuizCitationSourceSheet: View {
    let citation: QuizCitationSheetItem

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Source \(citation.displayIndex)")
                    .font(.title2.weight(.black))

                AppCard {
                    Text(citation.sourceText)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
            }
            .padding(24)
            .frame(maxWidth: 720, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.99, green: 0.97, blue: 0.89),
                    Color(red: 0.95, green: 0.98, blue: 1.0)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        )
    }
}
