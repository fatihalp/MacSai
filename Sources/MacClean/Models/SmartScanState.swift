import Foundation
import MacCleanKit

struct CompletedModule: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let fileCount: Int
    let size: UInt64
}

enum SmartScanModules {
    static var order: [(id: String, name: String, icon: String, group: String)] {
        [
            ("systemJunk", String(localized: "System Junk"), "trash.circle.fill", String(localized: "Cleanup")),
            ("mailAttachments", String(localized: "Mail Attachments"), "paperclip.circle.fill", String(localized: "Cleanup")),
            ("trashBins", String(localized: "Trash Bins"), "trash.fill", String(localized: "Cleanup")),
            ("malware", String(localized: "Malware Removal"), "shield.lefthalf.filled", String(localized: "Protection")),
            ("privacy", String(localized: "Privacy"), "hand.raised.fill", String(localized: "Protection")),
            ("optimization", String(localized: "Optimization"), "gauge.with.dots.needle.67percent", String(localized: "Speed")),
            ("maintenance", String(localized: "Maintenance"), "wrench.and.screwdriver", String(localized: "Speed")),
            ("uninstaller", String(localized: "Uninstaller"), "xmark.app.fill", String(localized: "Apps")),
            ("updater", String(localized: "Updater"), "arrow.triangle.2.circlepath", String(localized: "Apps")),
            ("largeOldFiles", String(localized: "Large & Old Files"), "doc.richtext.fill", String(localized: "Files")),
        ]
    }
}

enum SmartScanState {
    case idle
    case scanning(phase: String, progress: Double, filesFound: Int, sizeFound: UInt64)
    case results(cleanup: UInt64, protection: Int, performance: Int, totalSize: UInt64, moduleResults: [ModuleScanResult])
    case empty
    case cleaning(progress: Double)
    case done(freedSize: UInt64, breakdown: [SmartScanCleanup.RecentlyCleanedRow])
}
