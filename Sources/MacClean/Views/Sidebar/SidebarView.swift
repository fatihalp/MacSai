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
    public var title: String { String(localized: rawValue) }

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
        case .smartScan: "sparkle.magnifyingglass"
        case .systemJunk: "trash"
        case .mailAttachments: "paperclip"
        case .trashBins: "trash.slash"
        case .malwareRemoval: "shield"
        case .privacy: "hand.raised"
        case .wifiNetworks: "wifi"
        case .appPermissions: "lock.shield"
        case .optimization: "gauge.with.dots.needle.67percent"
        case .maintenance: "wrench.and.screwdriver"
        case .uninstaller: "Trash" == "" ? "xmark.app" : "xmark.app"
        case .extensions: "puzzlepiece.extension"
        case .updater: "arrow.triangle.2.circlepath"
        case .spaceLens: "chart.pie"
        case .largeOldFiles: "doc.richtext"
        case .duplicates: "doc.on.doc"
        case .shredder: "scissors"
        case .browserExtensions: "puzzlepiece"
        case .diskHogs: "externaldrive"
        case .projectJunk: "shippingbox"
        case .cleanHistory: "clock.arrow.circlepath"
        case .unusedApps: "app.badge"
        case .settings: "gearshape"
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

    public var section: SidebarSection {
        switch self {
        case .smartScan: .main
        case .systemJunk, .mailAttachments, .trashBins, .projectJunk, .diskHogs, .cleanHistory: .cleanup
        case .malwareRemoval, .privacy, .browserExtensions, .wifiNetworks, .appPermissions: .protection
        case .optimization, .maintenance: .performance
        case .uninstaller, .unusedApps, .extensions, .updater: .applications
        case .spaceLens, .largeOldFiles, .duplicates, .shredder: .files
        case .settings: .main
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

public enum SidebarSection: String, CaseIterable, Identifiable {
    case main = ""
    case cleanup = "Cleanup"
    case protection = "Protection"
    case performance = "Performance"
    case applications = "Applications"
    case files = "Files"

    public var id: String { rawValue }
    public var title: String { rawValue.isEmpty ? "" : String(localized: rawValue) }

    public var items: [SidebarItem] {
        SidebarItem.allCases.filter { $0.section == self && $0 != .settings }
    }
}

public struct SidebarView: View {
    @Binding var selection: SidebarItem?

    public init(selection: Binding<SidebarItem?>) {
        self._selection = selection
    }

    public var body: some View {
        List(selection: $selection) {
            ForEach(SidebarSection.allCases) { section in
                if section == .main {
                    ForEach(section.items) { item in
                        sidebarRow(item)
                    }
                } else {
                    Section(section.title) {
                        ForEach(section.items) { item in
                            sidebarRow(item)
                        }
                    }
                }
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
            minWidth: Localization.currentCode == "de" ? 240 : 200,
            idealWidth: Localization.currentCode == "de" ? 250 : 215
        )
    }

    private var settingsFooter: some View {
        Button {
            selection = .settings
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "gearshape")
                    .font(.system(size: 13))
                    .foregroundStyle(selection == .settings ? Color(nsColor: .systemBlue) : Color.secondary)
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
                .fill(selection == .settings ? Color(nsColor: .systemBlue).opacity(0.12) : Color.clear)
        )
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .accessibilityLabel("Settings")
    }

    private func sidebarRow(_ item: SidebarItem) -> some View {
        Label {
            Text(item.title)
                .font(.system(size: 13))
        } icon: {
            Image(systemName: item.icon)
                .font(.system(size: 13))
                .foregroundStyle(Color(nsColor: .systemBlue))
        }
        .tag(item)
    }
}
