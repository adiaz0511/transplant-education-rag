import SwiftUI

struct AskSourceDetailView: View {
    let source: AskSourceSheetItem

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Source \(source.label)")
                    .font(.title2.weight(.black))

                AppCard {
                    Text(source.sourceText)
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
                    Color(red: 0.92, green: 0.98, blue: 0.96)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        )
    }
}
