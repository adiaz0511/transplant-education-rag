import SwiftUI

struct OnboardingFeatureCard: View {
    let title: String
    let detail: String

    var body: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.title3.bold())

                Text(detail)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
