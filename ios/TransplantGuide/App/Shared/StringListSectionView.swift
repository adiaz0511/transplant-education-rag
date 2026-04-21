import SwiftUI

struct StringListSectionView: View {
    let title: String
    let items: [String]?

    var body: some View {
        if let items, !items.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.headline)

                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    Text("\(index + 1). \(item)")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}
