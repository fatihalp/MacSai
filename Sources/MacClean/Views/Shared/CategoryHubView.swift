import SwiftUI
import AppKit
import MacCleanKit

struct CategoryHubView: View {
    @Environment(AppState.self) private var appState
    let category: SidebarCategory

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                categoryHeader
                heroCard
                featuresGrid
            }
            .padding(.horizontal, 28)
            .padding(.top, 20)
            .padding(.bottom, 32)
        }
        .background(Color.white)
    }

    private var categoryHeader: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(category.iconColor)
                    .frame(width: 48, height: 48)
                Image(systemName: category.icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(category.title)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.primary)

                Text(category.subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(category.heroSubItem.actionTitle) {
                appState.selectItem(category.heroSubItem)
            }
            .buttonStyle(.borderedProminent)
            .tint(category.iconColor)
            .controlSize(.regular)
        }
        .padding(18)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.35))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color(nsColor: .separatorColor).opacity(0.4), lineWidth: 0.5)
        )
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(category.iconColor.opacity(0.12))
                        .frame(width: 44, height: 44)
                    Image(systemName: category.heroSubItem.icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(category.iconColor)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(category.heroTitle)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.primary)

                    Text(category.heroDescription)
                        .font(.system(size: 12.5))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                HStack(spacing: 8) {
                    Button("Review") {
                        appState.selectItem(category.heroSubItem)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)

                    Button(category.heroSubItem.actionTitle) {
                        appState.selectItem(category.heroSubItem)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(category.iconColor)
                    .controlSize(.regular)
                }
            }

            HStack(spacing: 8) {
                ForEach(category.subItems.prefix(4)) { subItem in
                    HStack(spacing: 6) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(subItem.iconColor.opacity(0.15))
                                .frame(width: 18, height: 18)
                            Image(systemName: subItem.icon)
                                .font(.system(size: 9.5, weight: .semibold))
                                .foregroundStyle(subItem.iconColor)
                        }
                        Text(subItem.title)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.7))
                    .clipShape(Capsule())
                }
            }
        }
        .padding(18)
        .background(category.iconColor.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(category.iconColor.opacity(0.2), lineWidth: 1)
        )
    }

    private var featuresGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Available Features")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.leading, 2)

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(category.subItems) { item in
                    featureItemCard(item)
                }
            }
        }
    }

    private func featureItemCard(_ item: SidebarItem) -> some View {
        Button {
            appState.selectItem(item)
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .center, spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(item.iconColor)
                            .frame(width: 32, height: 32)
                        Image(systemName: item.icon)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title)
                            .font(.system(size: 13.5, weight: .semibold))
                            .foregroundStyle(.primary)

                        Text(item.badgeText)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(item.iconColor)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1.5)
                            .background(item.iconColor.opacity(0.12))
                            .clipShape(Capsule())
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }

                Text(item.subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)

                HStack {
                    Spacer()
                    Text(item.actionTitle)
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(item.iconColor)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 115, alignment: .topLeading)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.35))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color(nsColor: .separatorColor).opacity(0.4), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }
}
