import SwiftUI

struct HomeIPadNavigationView<Content: View>: View {
    @Binding var selectedTab: HomeTab
    let content: () -> Content

    init(
        selectedTab: Binding<HomeTab>,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self._selectedTab = selectedTab
        self.content = content
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
                .frame(width: 248)

            contentPane
        }
        .background(shellBackground)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 18) {
            header(
                eyebrow: "Transplant Guide",
                title: "Keep learning"
            )

            VStack(spacing: 14) {
                ForEach(HomeTab.allCases) { tab in
                    tabButton(tab, layout: .sidebar)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 22)
        .background(sidebarBackground)
    }

    private var contentPane: some View {
        content()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func header(eyebrow: String, title: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(eyebrow.uppercased())
                .font(.caption.weight(.black))
                .foregroundStyle(Color(red: 0.39, green: 0.43, blue: 0.52))
                .tracking(0.8)

            Text(title)
                .font(.title2.weight(.black))
                .foregroundStyle(Color(red: 0.17, green: 0.23, blue: 0.31))
        }
    }

    private func tabButton(_ tab: HomeTab, layout: TabButtonLayout) -> some View {
        Button {
            selectedTab = tab
        } label: {
            HStack(spacing: 14) {
                iconBadge(for: tab, isSelected: selectedTab == tab)

                Text(tab.title)
                    .font(.headline.weight(.bold))

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .buttonStyle(
            HomeSidebarTabButtonStyle(
                isSelected: selectedTab == tab,
                fillColor: tab.fillColor,
                shadowColor: tab.shadowColor,
                cornerRadius: layout.cornerRadius,
                shadowOffset: layout.shadowOffset
            )
        )
        .accessibilityLabel(tab.title)
        .accessibilityAddTraits(selectedTab == tab ? .isSelected : [])
    }

    private func iconBadge(for tab: HomeTab, isSelected: Bool) -> some View {
        ZStack {
            Circle()
                .fill(isSelected ? Color.white.opacity(0.22) : tab.fillColor.opacity(0.18))
                .frame(width: 36, height: 36)

            Image(systemName: tab.systemImage)
                .font(.subheadline.weight(.black))
                .foregroundStyle(isSelected ? .white : tab.tintColor)
        }
    }

    private func tabBackground(for tab: HomeTab, isSelected: Bool, layout: TabButtonLayout) -> some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: layout.cornerRadius, style: .continuous)
                .fill(isSelected ? tab.shadowColor : Color(red: 0.86, green: 0.90, blue: 0.95))
                .offset(y: layout.shadowOffset)

            RoundedRectangle(cornerRadius: layout.cornerRadius, style: .continuous)
                .fill(isSelected ? tab.fillColor : Color.white.opacity(0.95))
                .overlay(
                    RoundedRectangle(cornerRadius: layout.cornerRadius, style: .continuous)
                        .stroke(Color.white.opacity(isSelected ? 0.18 : 0.85), lineWidth: 1)
                )
                .offset(y: isSelected ? 3 : 0)
        }
    }

    private var sidebarBackground: some View {
        LinearGradient(
            colors: [
                Color(red: 0.98, green: 0.97, blue: 0.91),
                Color(red: 0.95, green: 0.96, blue: 0.88)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(Color.white.opacity(0.55))
                .frame(width: 1)
        }
    }

    private var shellBackground: some View {
        LinearGradient(
            colors: [
                Color(red: 0.98, green: 0.97, blue: 0.91),
                Color(red: 0.95, green: 0.98, blue: 1.0)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

}

private struct HomeSidebarTabButtonStyle: ButtonStyle {
    let isSelected: Bool
    let fillColor: Color
    let shadowColor: Color
    let cornerRadius: CGFloat
    let shadowOffset: CGFloat

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(isSelected ? .white : Color(red: 0.17, green: 0.23, blue: 0.31))
            .background(
                ZStack(alignment: .top) {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(isSelected ? shadowColor : Color(red: 0.86, green: 0.90, blue: 0.95))
                        .offset(y: shadowOffset)

                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(isSelected ? fillColor : Color.white.opacity(0.95))
                        .overlay(
                            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                .stroke(Color.white.opacity(isSelected ? 0.18 : 0.85), lineWidth: 1)
                        )
                        .offset(y: configuration.isPressed ? 3 : 0)
                }
            )
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .shadow(color: Color.black.opacity(isSelected ? 0.10 : 0.03), radius: 10, y: 8)
            .animation(.bouncy(duration: 0.22), value: configuration.isPressed)
            .animation(.bouncy(duration: 0.28), value: isSelected)
    }
}

private enum TabButtonLayout {
    case sidebar

    var cornerRadius: CGFloat {
        24
    }

    var shadowOffset: CGFloat {
        6
    }
}
