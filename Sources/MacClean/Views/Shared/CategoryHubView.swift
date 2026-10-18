import SwiftUI
import AppKit
import MacCleanKit

struct CategoryHubView: View {
    @Environment(AppState.self) private var appState
    let category: SidebarCategory

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                categoryHeader

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 14) {
                    ForEach(category.subItems) { item in
                        featureItemCard(item)
                    }
                }
            }
            .padding(.horizontal, 28)
            .padding(.top, 24)
            .padding(.bottom, 32)
        }
        .background(Color.white)
    }

    private var categoryHeader: some View {
        HStack(alignment: .center, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(category.iconColor)
                    .frame(width: 40, height: 40)
                Image(systemName: category.icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(category.title)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.primary)

                Text(category.subtitle)
                    .font(.system(size: 12.5))
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }

    private func featureItemCard(_ item: SidebarItem) -> some View {
        Button {
            appState.selectItem(item)
        } label: {
            HStack(alignment: .center, spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(item.iconColor.opacity(0.12))
                        .frame(width: 36, height: 36)
                    Image(systemName: item.icon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(item.iconColor)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(item.title)
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundStyle(.primary)

                    Text(item.subtitle)
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 8)

                Button(item.actionTitle) {
                    appState.selectItem(item)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(item.iconColor)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 68, alignment: .leading)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.35))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color(nsColor: .separatorColor).opacity(0.35), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }
}
