import SwiftUI

struct LibraryGridView<Item: Identifiable, Content: View>: View {
    enum LayoutStyle {
        case horizontalRail
        case adaptiveGrid
        case horizontalCompactGridRegular
        case gridOnly
    }

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let items: [Item]
    let layoutStyle: LayoutStyle
    let cardWidth: CGFloat
    let compactGridColumns: Int
    let regularGridColumns: Int
    let horizontalSpacing: CGFloat
    let verticalSpacing: CGFloat
    let content: (Item) -> Content

    init(
        items: [Item],
        layoutStyle: LayoutStyle = .adaptiveGrid,
        cardWidth: CGFloat = 320,
        compactGridColumns: Int = 1,
        regularGridColumns: Int = 3,
        @ViewBuilder content: @escaping (Item) -> Content
    ) {
        self.init(
            items: items,
            layoutStyle: layoutStyle,
            cardWidth: cardWidth,
            compactGridColumns: compactGridColumns,
            regularGridColumns: regularGridColumns,
            horizontalSpacing: 16,
            verticalSpacing: 16,
            content: content
        )
    }

    init(
        items: [Item],
        layoutStyle: LayoutStyle = .adaptiveGrid,
        cardWidth: CGFloat = 320,
        compactGridColumns: Int = 1,
        regularGridColumns: Int = 3,
        horizontalSpacing: CGFloat = 16,
        verticalSpacing: CGFloat = 16,
        @ViewBuilder content: @escaping (Item) -> Content
    ) {
        self.items = items
        self.layoutStyle = layoutStyle
        self.cardWidth = cardWidth
        self.compactGridColumns = compactGridColumns
        self.regularGridColumns = regularGridColumns
        self.horizontalSpacing = horizontalSpacing
        self.verticalSpacing = verticalSpacing
        self.content = content
    }

    var body: some View {
        if usesHorizontalRail {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: horizontalSpacing) {
                    ForEach(items) { item in
                        content(item)
                            .frame(width: cardWidth, alignment: .top)
                    }
                }
                .padding(.vertical, 6)
            }
            .scrollClipDisabled()
        } else {
            LazyVGrid(
                columns: gridColumns,
                alignment: .leading,
                spacing: verticalSpacing
            ) {
                ForEach(items) { item in
                    content(item)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private var usesHorizontalRail: Bool {
        switch layoutStyle {
        case .horizontalRail:
            return true
        case .horizontalCompactGridRegular:
            return horizontalSizeClass == .compact
        case .gridOnly:
            return false
        case .adaptiveGrid:
            return horizontalSizeClass == .compact
        }
    }

    private var gridColumns: [GridItem] {
        let count = horizontalSizeClass == .compact ? compactGridColumns : regularGridColumns
        return Array(repeating: GridItem(.flexible(), spacing: horizontalSpacing, alignment: .top), count: count)
    }
}
