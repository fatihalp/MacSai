import SwiftUI

extension SidebarItem {
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

    public var subtitle: String {
        switch self {
        case .smartScan:
            "One-click comprehensive analysis of junk, malware, and performance."
        case .systemJunk:
            "Clean caches, logs, Xcode remnants, and localization files."
        case .mailAttachments:
            "Remove local copies of email downloads and cached attachments."
        case .trashBins:
            "Safely empty startup disk Trash and external drive bins."
        case .diskHogs:
            "Discover hidden oversized folders and files taking up space."
        case .projectJunk:
            "Clean developer build artifacts from Xcode, SPM, and node_modules."
        case .cleanHistory:
            "Review audit log of past cleanup sessions and freed gigabytes."
        case .malwareRemoval:
            "Scan memory, launch agents, and applications for security threats."
        case .privacy:
            "Clean browser histories, cookies, autofill, and tracking traces."
        case .wifiNetworks:
            "Audit saved Wi-Fi networks and remove unsecured hotspots."
        case .appPermissions:
            "Review sensitive camera, microphone, and disk permissions."
        case .browserExtensions:
            "Manage extensions and helper plugins across your browsers."
        case .optimization:
            "Manage login items, background launch daemons, and RAM hogs."
        case .maintenance:
            "Flush DNS cache, reindex Spotlight, and run repair scripts."
        case .uninstaller:
            "Completely remove apps with their leftover files and caches."
        case .unusedApps:
            "Detect applications not opened in over 6 months to free space."
        case .extensions:
            "Inspect preference panes, QuickLook plugins, and system extensions."
        case .updater:
            "Check for pending updates to keep software modern and secure."
        case .spaceLens:
            "Visual storage map of files and folders by size proportion."
        case .largeOldFiles:
            "Locate massive files and archives forgotten over time."
        case .duplicates:
            "Scan folders for identical duplicate files and consolidate."
        case .shredder:
            "Permanently destroy sensitive files with secure multi-pass wiping."
        case .settings:
            "Configure automatic updates, folder exclusions, and widgets."
        }
    }

    public var actionTitle: String {
        switch self {
        case .smartScan: "Start Scan"
        case .systemJunk: "Scan Junk"
        case .mailAttachments: "Clean Mail"
        case .trashBins: "Empty Trash"
        case .diskHogs: "Find Hogs"
        case .projectJunk: "Clean Builds"
        case .cleanHistory: "View History"
        case .malwareRemoval: "Scan Malware"
        case .privacy: "Review Privacy"
        case .wifiNetworks: "Inspect Networks"
        case .appPermissions: "Review Permissions"
        case .browserExtensions: "Manage Extensions"
        case .optimization: "Optimize"
        case .maintenance: "Run Tasks"
        case .uninstaller: "Open Uninstaller"
        case .unusedApps: "Scan Unused"
        case .extensions: "Manage Extensions"
        case .updater: "Check Updates"
        case .spaceLens: "Analyze Storage"
        case .largeOldFiles: "Find Large Files"
        case .duplicates: "Find Duplicates"
        case .shredder: "Shred Files"
        case .settings: "Open Settings"
        }
    }
}

extension SidebarCategory {
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

    public var subtitle: String {
        switch self {
        case .smartScan:
            "Clean, protect, and optimize your Mac in one click."
        case .cleanup:
            "Reclaim storage by removing system junk, caches, mail attachments, and trash."
        case .protection:
            "Safeguard your Mac against malware, unauthorized permissions, and privacy risks."
        case .performance:
            "Optimize background processes, startup items, and run vital maintenance routines."
        case .applications:
            "Completely remove apps with their leftovers, check for updates, and detect unused software."
        case .files:
            "Analyze disk distribution, discover large old files, find duplicates, and shred data."
        case .settings:
            "Preferences, exclusions, and app configuration."
        }
    }
}
