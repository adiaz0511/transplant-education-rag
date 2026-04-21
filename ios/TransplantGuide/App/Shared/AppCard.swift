import SwiftUI

struct AppCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                ZStack(alignment: .top) {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Color(red: 0.84, green: 0.89, blue: 0.94))
                        .offset(y: 7)

                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Color.white)
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color(red: 0.84, green: 0.89, blue: 0.94), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.05), radius: 10, y: 8)
    }
}
