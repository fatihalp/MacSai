import Foundation
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
            [.uninstaller, .updater, .unusedApps, .extensions]
        case .files:
            [.spaceLens, .largeOldFiles, .duplicates, .shredder]
        case .settings:
            [.settings]
        }
    }
}
