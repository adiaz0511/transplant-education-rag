import SwiftUI

struct OnboardingSectionHeaderView: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 34, weight: .bold, design: .rounded))

            Text(detail)
                .font(.body)
                .foregroundStyle(.secondary)
        }
    }
}
