import SwiftUI

struct OnboardingGradientBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 1.0, green: 0.97, blue: 0.90),
                Color(red: 0.95, green: 0.98, blue: 1.0),
                Color(red: 0.95, green: 1.0, blue: 0.95)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}
