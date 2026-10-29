import SwiftUI
import MacCleanKit

public struct SidebarView: View {
    @Binding var selection: SidebarCategory
    var onSelectCategory: ((SidebarCategory) -> Void)? = nil

    public init(
        selection: Binding<SidebarCategory>,
        onSelectCategory: ((SidebarCategory) -> Void)? = nil
    ) {
        self._selection = selection
        self.onSelectCategory = onSelectCategory
    }

    public var body: some View {
        List(selection: $selection) {
            ForEach(SidebarCategory.allCases.filter { $0 != .settings }) { category in
                sidebarCategoryRow(category)
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 0) {
                Divider()
                settingsFooter
            }
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .frame(
            minWidth: Localization.currentCode == "de" ? 220 : 180,
            idealWidth: Localization.currentCode == "de" ? 230 : 195
        )
    }

    private var settingsFooter: some View {
        Button {
            selection = .settings
            onSelectCategory?(.settings)
        } label: {
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(SidebarCategory.settings.iconColor)
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .frame(width: 20, height: 20)

                Text("Settings")
                    .font(.system(size: 13, weight: selection == .settings ? .medium : .regular))
                Spacer()
                Text("v\(MCConstants.appVersion)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(selection == .settings ? Color(nsColor: .selectedContentBackgroundColor).opacity(0.15) : Color.clear)
        )
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .accessibilityLabel("Settings")
    }

    private func sidebarCategoryRow(_ category: SidebarCategory) -> some View {
        Label {
            Text(category.title)
                .font(.system(size: 13, weight: selection == category ? .medium : .regular))
        } icon: {
            ZStack {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(category.iconColor)
                Image(systemName: category.icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 20, height: 20)
        }
        .tag(category)
        .simultaneousGesture(TapGesture().onEnded {
            selection = category
            onSelectCategory?(category)
        })
    }
}
