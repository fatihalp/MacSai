import Foundation

public enum ScanCategory: String, CaseIterable, Identifiable, Sendable {

    case userCaches = "user_caches"
    case systemCaches = "system_caches"
    case userLogs = "user_logs"
    case systemLogs = "system_logs"
    case languageFiles = "language_files"
    case brokenPreferences = "broken_preferences"
    case brokenLoginItems = "broken_login_items"
    case documentVersions = "document_versions"
    case brokenDownloads = "broken_downloads"
    case iosDeviceBackups = "ios_device_backups"
    case oldUpdates = "old_updates"
    case universalBinaries = "universal_binaries"
    case xcodeJunk = "xcode_junk"
    case deletedUsers = "deleted_users"
    case unusedDiskImages = "unused_disk_images"
    case incompleteDownloads = "incomplete_downloads"
    case appLeftovers = "app_leftovers"
    case packageManagerCaches = "package_manager_caches"
    case ideCaches = "ide_caches"
    case aiToolCaches = "ai_tool_caches"

    case mailAttachments = "mail_attachments"

    case trashBins = "trash_bins"

    case malware = "malware"
    case browserPrivacy = "browser_privacy"
    case systemPrivacy = "system_privacy"

    case largeFiles = "large_files"
    case oldFiles = "old_files"
    case duplicates = "duplicates"

    case projectJunk = "project_junk"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .userCaches: String(localized: "User Cache Files")
        case .systemCaches: String(localized: "System Cache Files")
        case .userLogs: String(localized: "User Log Files")
        case .systemLogs: String(localized: "System Log Files")
        case .languageFiles: String(localized: "Language Files")
        case .brokenPreferences: String(localized: "Broken Preferences")
        case .brokenLoginItems: String(localized: "Broken Login Items")
        case .documentVersions: String(localized: "Document Versions")
        case .brokenDownloads: String(localized: "Broken Downloads")
        case .iosDeviceBackups: String(localized: "iOS Device Backups")
        case .oldUpdates: String(localized: "Old Updates")
        case .universalBinaries: String(localized: "Universal Binaries")
        case .xcodeJunk: String(localized: "Xcode Junk")
        case .deletedUsers: String(localized: "Deleted Users")
        case .unusedDiskImages: String(localized: "Unused Disk Images")
        case .incompleteDownloads: String(localized: "Incomplete Downloads")
        case .appLeftovers: String(localized: "Leftovers from Deleted Apps")
        case .packageManagerCaches: String(localized: "Package Manager Caches")
        case .ideCaches: String(localized: "IDE & Editor Caches")
        case .aiToolCaches: String(localized: "AI Tool Caches")
        case .mailAttachments: String(localized: "Mail Attachments")
        case .trashBins: String(localized: "Trash Bins")
        case .malware: String(localized: "Malware")
        case .browserPrivacy: String(localized: "Browser Privacy")
        case .systemPrivacy: String(localized: "System Privacy")
        case .largeFiles: String(localized: "Large Files")
        case .oldFiles: String(localized: "Old Files")
        case .duplicates: String(localized: "Duplicates")
        case .projectJunk: String(localized: "Project Junk")
        }
    }

    public var subtitle: String {
        switch self {
        case .userCaches: String(localized: "App temporary files. Regenerated next launch.")
        case .systemCaches: String(localized: "macOS-managed caches. Rebuilt automatically.")
        case .userLogs: String(localized: "Diagnostic logs written by your apps.")
        case .systemLogs: String(localized: "macOS diagnostic logs.")
        case .languageFiles: String(localized: "Unused localizations bundled with apps.")
        case .brokenPreferences: String(localized: "Corrupt or orphaned preference files.")
        case .brokenLoginItems: String(localized: "Login items pointing at apps that are gone.")
        case .documentVersions: String(localized: "Old autosaved document revisions.")
        case .brokenDownloads: String(localized: "Failed or orphaned download leftovers.")
        case .iosDeviceBackups: String(localized: "Local backups of iPhone and iPad devices.")
        case .oldUpdates: String(localized: "Installer packages left behind after updating.")
        case .universalBinaries: String(localized: "Unused CPU slices inside app binaries.")
        case .xcodeJunk: String(localized: "Derived data, archives, and simulator caches.")
        case .deletedUsers: String(localized: "Leftover data from removed user accounts.")
        case .unusedDiskImages: String(localized: "Disk images you mounted once and forgot.")
        case .incompleteDownloads: String(localized: "Partially downloaded files.")
        case .appLeftovers: String(localized: "Support files from apps you've deleted.")
        case .packageManagerCaches: String(localized: "Regenerable caches from npm, Cargo, pip, Homebrew, and Gradle.")
        case .ideCaches: String(localized: "Caches from code editors like Cursor and Antigravity.")
        case .aiToolCaches: String(localized: "Caches from AI coding tools (Claude, Codex). History and sessions excluded.")
        case .mailAttachments: String(localized: "Saved copies of Mail attachments.")
        case .trashBins: String(localized: "Items currently sitting in the Trash.")
        case .malware: String(localized: "Known malicious files found on disk.")
        case .browserPrivacy: String(localized: "Browsing history and tracking data. Cookies and sessions stay.")
        case .systemPrivacy: String(localized: "Recent-items lists and other privacy traces.")
        case .largeFiles: String(localized: "The files taking up the most space.")
        case .oldFiles: String(localized: "Files you haven't opened in a long time.")
        case .duplicates: String(localized: "Identical copies of the same file.")
        case .projectJunk: String(localized: "Dependency and build folders inside your code projects.")
        }
    }

    public var tooltip: String {
        "\(displayName)\n\(subtitle)"
    }

    public enum CleanupSafety: CaseIterable, Sendable {

        case regenerates

        case safeToRemove

        case reviewFirst

        public var label: String {
            switch self {
            case .regenerates: String(localized: "Recreated automatically")
            case .safeToRemove: String(localized: "Safe to remove")
            case .reviewFirst: String(localized: "Review before cleaning")
            }
        }

        public var systemImage: String {
            switch self {
            case .regenerates: "arrow.triangle.2.circlepath.circle"
            case .safeToRemove: "checkmark.shield"
            case .reviewFirst: "exclamationmark.shield"
            }
        }
    }

    public var cleanupSafety: CleanupSafety {
        switch self {
        case .userCaches, .systemCaches, .packageManagerCaches, .ideCaches, .aiToolCaches:
            .regenerates
        case .userLogs, .systemLogs, .brokenPreferences, .brokenLoginItems,
             .brokenDownloads, .incompleteDownloads, .oldUpdates, .appLeftovers:
            .safeToRemove
        case .languageFiles, .documentVersions, .iosDeviceBackups, .universalBinaries,
             .xcodeJunk, .deletedUsers, .unusedDiskImages, .mailAttachments, .trashBins,
             .malware, .browserPrivacy, .systemPrivacy, .largeFiles, .oldFiles, .duplicates,
             .projectJunk:
            .reviewFirst
        }
    }

    public var safetyRationale: String {
        switch self {
        case .userCaches: String(localized: "App temp files. Recreated automatically the next time each app launches.")
        case .systemCaches: String(localized: "Caches macOS manages itself. It rebuilds them automatically as needed.")
        case .packageManagerCaches: String(localized: "Download and build caches. npm, Cargo, pip, Homebrew, and Gradle re-download what they need on the next install or build.")
        case .ideCaches: String(localized: "Editor caches only. Cursor and Antigravity recreate them on next launch; your settings and extensions aren't touched.")
        case .aiToolCaches: String(localized: "Scratch and cache folders only. Claude and Codex recreate them as needed; history, memory, and sessions are never included.")
        case .userLogs: String(localized: "Diagnostic text your apps wrote for troubleshooting. Apps don't read old logs back, and they start new ones as they run.")
        case .systemLogs: String(localized: "macOS diagnostic logs. Only useful when investigating a past problem; macOS keeps writing fresh ones.")
        case .brokenPreferences: String(localized: "Settings files that can't be read, or whose app is no longer installed. Nothing on this Mac uses them.")
        case .brokenLoginItems: String(localized: "Login entries that point to apps that no longer exist, so they can't start anything.")
        case .brokenDownloads: String(localized: "Leftovers of downloads that failed or were abandoned. Download the file again if you still want it.")
        case .incompleteDownloads: String(localized: "Partial files from unfinished downloads and day-old temp files. Don't clean while a download is still running.")
        case .oldUpdates: String(localized: "Installer packages apps downloaded more than a week ago. Installers aren't needed once they've run, and can be downloaded again.")
        case .appLeftovers: String(localized: "Support folders named after an app that's no longer installed (the name on each row is that app's ID). Reinstalling the app later starts it fresh.")
        case .languageFiles: String(localized: "Translations for languages you don't use. Removing them changes the app bundle; reinstall the app to get them back.")
        case .documentVersions: String(localized: "Older autosaved revisions of your documents. The current version stays, but older ones can't be browsed after cleaning.")
        case .iosDeviceBackups: String(localized: "Local iPhone and iPad backups older than 30 days. If it's a device's only backup, keep it or back up to iCloud first.")
        case .universalBinaries: String(localized: "Removes CPU code this Mac can't run from inside apps. Changes the apps in place; only reinstalling them undoes it.")
        case .xcodeJunk: String(localized: "DerivedData and Previews are rebuilt on the next build, and Device Support is copied again when a device connects. Archives and simulator data can't be regenerated; keep them if you need old builds or crash symbols.")
        case .deletedUsers: String(localized: "Whole home folders of accounts no longer on this Mac. Check each name: a network account that's briefly offline looks the same.")
        case .unusedDiskImages: String(localized: "Disk images in Downloads older than a week, usually installers that already ran. Download them again if you need them.")
        case .mailAttachments: String(localized: "Copies of attachments Mail saved on disk. Mail can download them again from the server for IMAP and Exchange accounts, not for POP.")
        case .trashBins: String(localized: "Already in the Trash. Emptying it is permanent and can't be undone.")
        case .malware: String(localized: "Matched a known malware signature. Check the path first if it belongs to software you installed on purpose.")
        case .browserPrivacy: String(localized: "Your browsing history and tracking data. Can't be restored after cleaning; cookies and logged-in sessions stay.")
        case .systemPrivacy: String(localized: "Recent-items lists and similar traces. Apps' Open Recent menus will start empty.")
        case .largeFiles: String(localized: "Your own files, picked only by size. Nothing here is junk by definition; check each one.")
        case .oldFiles: String(localized: "Your own files you haven't opened in a long time. Old doesn't mean unneeded; check each one.")
        case .duplicates: String(localized: "Byte-for-byte identical copies. Keep at least one copy of each file you need.")
        case .projectJunk: String(localized: "Installed dependencies and build output inside your projects. Running the project's install or build command brings them back; the first build afterwards takes longer.")
        }
    }

    public var systemImage: String {
        switch self {
        case .userCaches, .systemCaches: "folder.badge.gearshape"
        case .userLogs, .systemLogs: "doc.text"
        case .languageFiles: "globe"
        case .brokenPreferences: "gearshape.triangle.fill"
        case .brokenLoginItems: "person.crop.circle.badge.exclamationmark"
        case .documentVersions: "doc.on.doc"
        case .brokenDownloads, .incompleteDownloads: "arrow.down.circle.dotted"
        case .iosDeviceBackups: "iphone"
        case .oldUpdates: "arrow.triangle.2.circlepath"
        case .universalBinaries: "cpu"
        case .xcodeJunk: "hammer"
        case .deletedUsers: "person.crop.circle.badge.minus"
        case .unusedDiskImages: "opticaldisc"
        case .appLeftovers: "shippingbox.and.arrow.backward"
        case .packageManagerCaches: "shippingbox"
        case .ideCaches: "macwindow"
        case .aiToolCaches: "sparkles"
        case .mailAttachments: "paperclip"
        case .trashBins: "trash"
        case .malware: "shield.lefthalf.filled.trianglebadge.exclamationmark"
        case .browserPrivacy: "safari"
        case .systemPrivacy: "hand.raised"
        case .largeFiles: "arrow.up.right.square"
        case .oldFiles: "clock.arrow.circlepath"
        case .duplicates: "plus.square.on.square"
        case .projectJunk: "chevron.left.forwardslash.chevron.right"
        }
    }

    public var autoSelect: Bool {
        switch self {
        case .unusedDiskImages, .largeFiles, .oldFiles, .duplicates, .projectJunk,
             .universalBinaries, .appLeftovers, .deletedUsers,
             .packageManagerCaches, .ideCaches, .aiToolCaches:

            false
        default:
            true
        }
    }
}
