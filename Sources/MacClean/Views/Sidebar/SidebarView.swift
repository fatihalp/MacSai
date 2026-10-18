import SwiftUI
import AppKit
import MacCleanKit

public enum SidebarItem: String, CaseIterable, Identifiable {
    case smartScan = "Smart Scan"
    case systemJunk = "System Junk"
    case mailAttachments = "Mail Attachments"
    case trashBins = "Trash Bins"
    case malwareRemoval = "Malware Removal"
    case privacy = "Privacy"
    case wifiNetworks = "Saved Wi-Fi"
    case appPermissions = "Permissions"
    case optimization = "Optimization"
    case maintenance = "Maintenance"
    case uninstaller = "Uninstaller"
    case unusedApps = "Unused Apps"
    case extensions = "Extensions"
    case updater = "Updater"
    case spaceLens = "Space Lens"
    case largeOldFiles = "Large & Old Files"
    case duplicates = "Duplicates"
    case shredder = "Shredder"
    case browserExtensions = "Browser Extensions"
    case diskHogs = "Disk Hogs"
    case projectJunk = "Project Junk"
    case cleanHistory = "Clean History"
    case settings = "Settings"

    public var id: String { rawValue }
    public var title: String { rawValue }

    public var deepLinkID: String {
        switch self {
        case .smartScan: "smart-scan"
        case .systemJunk: "system-junk"
        case .mailAttachments: "mail-attachments"
        case .trashBins: "trash-bins"
        case .malwareRemoval: "malware"
        case .privacy: "privacy"
        case .wifiNetworks: "wifi-networks"
        case .appPermissions: "app-permissions"
        case .optimization: "optimization"
        case .maintenance: "maintenance"
        case .uninstaller: "uninstaller"
        case .extensions: "extensions"
        case .updater: "updater"
        case .spaceLens: "space-lens"
        case .largeOldFiles: "large-old-files"
        case .duplicates: "duplicates"
        case .shredder: "shredder"
        case .browserExtensions: "browser-extensions"
        case .diskHogs: "disk-hogs"
        case .projectJunk: "project-junk"
        case .cleanHistory: "clean-history"
        case .unusedApps: "unused-apps"
        case .settings: "settings"
        }
    }

    public init?(deepLinkID: String) {
        guard let match = Self.allCases.first(where: { $0.deepLinkID == deepLinkID }) else { return nil }
        self = match
    }

    public var icon: String {
        switch self {
        case .smartScan: "sparkles"
        case .systemJunk: "trash.fill"
        case .mailAttachments: "paperclip"
        case .trashBins: "trash.slash.fill"
        case .malwareRemoval: "shield.fill"
        case .privacy: "hand.raised.fill"
        case .wifiNetworks: "wifi"
        case .appPermissions: "lock.shield.fill"
        case .optimization: "gauge.with.dots.needle.67percent"
        case .maintenance: "wrench.and.screwdriver.fill"
        case .uninstaller: "xmark.app.fill"
        case .extensions: "puzzlepiece.extension.fill"
        case .updater: "arrow.triangle.2.circlepath"
        case .spaceLens: "chart.pie.fill"
        case .largeOldFiles: "doc.fill"
        case .duplicates: "doc.on.doc.fill"
        case .shredder: "scissors"
        case .browserExtensions: "puzzlepiece.fill"
        case .diskHogs: "externaldrive.fill"
        case .projectJunk: "shippingbox.fill"
        case .cleanHistory: "clock.arrow.circlepath"
        case .unusedApps: "clock.badge.xmark.fill"
        case .settings: "gearshape.fill"
        }
    }

    public var iconColor: Color {
        switch self {
        case .smartScan:
            Color(nsColor: .systemIndigo)
        case .systemJunk, .mailAttachments:
            Color(nsColor: .systemBlue)
        case .trashBins:
            Color(nsColor: .systemGray)
        case .malwareRemoval:
            Color(nsColor: .systemGreen)
        case .privacy, .wifiNetworks, .appPermissions:
            Color(nsColor: .systemBlue)
        case .optimization:
            Color(nsColor: .systemOrange)
        case .maintenance:
            Color(nsColor: .systemGray)
        case .uninstaller:
            Color(nsColor: .systemRed)
        case .unusedApps:
            Color(nsColor: .systemOrange)
        case .extensions:
            Color(nsColor: .systemPurple)
        case .updater:
            Color(nsColor: .systemBlue)
        case .spaceLens:
            Color(nsColor: .systemTeal)
        case .largeOldFiles:
            Color(nsColor: .systemOrange)
        case .duplicates:
            Color(nsColor: .systemBlue)
        case .shredder:
            Color(nsColor: .systemRed)
        case .browserExtensions:
            Color(nsColor: .systemIndigo)
        case .diskHogs:
            Color(nsColor: .systemPurple)
        case .projectJunk:
            Color(nsColor: .systemBrown)
        case .cleanHistory:
            Color(nsColor: .systemGray)
        case .settings:
            Color(nsColor: .systemGray)
        }
    }

    public var category: SidebarCategory {
        switch self {
        case .smartScan: .smartScan
        case .systemJunk, .mailAttachments, .trashBins, .diskHogs, .projectJunk, .cleanHistory: .cleanup
        case .malwareRemoval, .privacy, .wifiNetworks, .appPermissions, .browserExtensions: .protection
        case .optimization, .maintenance: .performance
        case .uninstaller, .unusedApps, .extensions, .updater: .applications
        case .spaceLens, .largeOldFiles, .duplicates, .shredder: .files
        case .settings: .settings
        }
    }

    public var theme: ModuleTheme {
        switch self {
        case .smartScan: .smartScan
        case .systemJunk, .mailAttachments, .trashBins, .projectJunk, .diskHogs, .cleanHistory: .cleanup
        case .malwareRemoval, .privacy, .browserExtensions, .wifiNetworks, .appPermissions: .protection
        case .optimization, .maintenance: .performance
        case .uninstaller, .unusedApps, .extensions, .updater: .applications
        case .spaceLens, .largeOldFiles, .duplicates, .shredder: .files
        case .settings: .settings
        }
    }

    public static var keyboardShortcutItems: [SidebarItem] {
        Array(allCases.filter { $0 != .settings }.prefix(9))
    }

    public static func item(forShortcutDigit digit: Int) -> SidebarItem? {
        let items = keyboardShortcutItems
        guard digit >= 1, digit <= items.count else { return nil }
        return items[digit - 1]
    }
}

public enum SidebarCategory: String, CaseIterable, Identifiable {
    case smartScan = "Smart Scan"
    case cleanup = "Cleanup"
    case protection = "Protection"
    case performance = "Performance"
    case applications = "Applications"
    case files = "Files"
    case settings = "Settings"

    public var id: String { rawValue }
    public var title: String { rawValue }

    public var icon: String {
        switch self {
        case .smartScan: "sparkles"
        case .cleanup: "trash.fill"
        case .protection: "shield.fill"
        case .performance: "gauge.with.dots.needle.67percent"
        case .applications: "square.stack.3d.up.fill"
        case .files: "doc.fill"
        case .settings: "gearshape.fill"
        }
    }

    public var iconColor: Color {
        switch self {
        case .smartScan:
            Color(nsColor: .systemIndigo)
        case .cleanup:
            Color(nsColor: .systemBlue)
        case .protection:
            Color(nsColor: .systemGreen)
        case .performance:
            Color(nsColor: .systemOrange)
        case .applications:
            Color(nsColor: .systemRed)
        case .files:
            Color(nsColor: .systemTeal)
        case .settings:
            Color(nsColor: .systemGray)
        }
    }

    public var subItems: [SidebarItem] {
        switch self {
        case .smartScan:
            [.smartScan]
        case .cleanup:
            [.systemJunk, .mailAttachments, .trashBins, .diskHogs, .projectJunk, .cleanHistory]
        case .protection:
            [.malwareRemoval, .privacy, .wifiNetworks, .appPermissions, .browserExtensions]
        case .performance:
            [.optimization, .maintenance]
        case .applications:
            [.uninstaller, .unusedApps, .extensions, .updater]
        case .files:
            [.spaceLens, .largeOldFiles, .duplicates, .shredder]
        case .settings:
            [.settings]
        }
    }
}

public struct SidebarView: View {
    @Binding var selection: SidebarCategory
    var onSelectSubItem: ((SidebarItem) -> Void)? = nil
    @State private var searchText: String = ""

    public init(selection: Binding<SidebarCategory>, onSelectSubItem: ((SidebarItem) -> Void)? = nil) {
        self._selection = selection
        self.onSelectSubItem = onSelectSubItem
    }

    public var body: some View {
        VStack(spacing: 0) {
            searchBar

            List(selection: $selection) {
                if searchText.isEmpty {
                    ForEach(SidebarCategory.allCases.filter { $0 != .settings }) { category in
                        sidebarCategoryRow(category)
                    }
                } else {
                    let matchingSubItems = SidebarItem.allCases.filter {
                        $0 != .settings && $0 != .smartScan && $0.title.localizedCaseInsensitiveContains(searchText)
                    }
                    let matchingCategories = SidebarCategory.allCases.filter {
                        $0 != .settings && $0.title.localizedCaseInsensitiveContains(searchText)
                    }

                    if !matchingCategories.isEmpty {
                        Section("Categories") {
                            ForEach(matchingCategories) { category in
                                sidebarCategoryRow(category)
                            }
                        }
                    }

                    if !matchingSubItems.isEmpty {
                        Section("Features") {
                            ForEach(matchingSubItems) { item in
                                Button {
                                    selection = item.category
                                    onSelectSubItem?(item)
                                } label: {
                                    Label {
                                        VStack(alignment: .leading, spacing: 1) {
                                            Text(item.title)
                                                .font(.system(size: 13))
                                            Text(item.category.title)
                                                .font(.system(size: 10.5))
                                                .foregroundStyle(.secondary)
                                        }
                                    } icon: {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                                .fill(item.iconColor)
                                            Image(systemName: item.icon)
                                                .font(.system(size: 11, weight: .semibold))
                                                .foregroundStyle(.white)
                                        }
                                        .frame(width: 20, height: 20)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .listStyle(.sidebar)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 0) {
                Divider()
                settingsFooter
            }
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .frame(
            minWidth: Localization.currentCode == "de" ? 240 : 200,
            idealWidth: Localization.currentCode == "de" ? 250 : 215
        )
    }

    private var searchBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
            TextField("Search", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .strokeBorder(Color(nsColor: .separatorColor).opacity(0.4), lineWidth: 0.5)
        )
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 6)
    }

    private var settingsFooter: some View {
        Button {
            selection = .settings
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
    }
}
