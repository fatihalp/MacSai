import SwiftUI
import MacCleanKit

@Observable
public final class AppState {
    var selectedCategory: SidebarCategory = .smartScan
    var selectedSidebarItem: SidebarItem? = .smartScan
    var scanCoordinator = ScanCoordinator()
    let cleaningEngine = CleaningEngine()
    let scanResultsStore = ScanResultsStore()

    var pendingUninstallerAppPath: String?

    private(set) var scanShortcutNonce: UInt64 = 0

    private(set) var cleanShortcutNonce: UInt64 = 0

    func requestScanShortcut() { scanShortcutNonce &+= 1 }
    func requestCleanShortcut() { cleanShortcutNonce &+= 1 }

    func selectCategory(_ category: SidebarCategory) {
        selectedCategory = category
        if category == .smartScan {
            selectedSidebarItem = .smartScan
        } else if category == .settings {
            selectedSidebarItem = .settings
        } else {
            selectedSidebarItem = nil
        }
    }

    func selectItem(_ item: SidebarItem) {
        selectedCategory = item.category
        selectedSidebarItem = item
    }

    func openUninstaller(forAppPath path: String) {
        pendingUninstallerAppPath = path
        selectItem(.uninstaller)
    }

    init() {
        registerModules()

        Task.detached(priority: .background) {
            CleanLogManager.pruneOldEntries()
        }

        Task.detached(priority: .background) {
            let found = LanguageScanner().discoverLproj(in: LanguageScanner.defaultRoots)
            await MainActor.run { LanguagePreferences.discoveredLproj = found }
        }
    }

    private func registerModules() {
        scanCoordinator.registerModules([
            SystemJunkModule(),
            MailAttachmentsModule(),
            TrashBinsModule(),
            MalwareModule(),
            PrivacyModule(),
            OptimizationModule(),
            MaintenanceModule(),
            UninstallerModule(),
            UpdaterModule(),
            SpaceLensModule(),
            LargeOldFilesModule(),
            DuplicatesModule(),
            ShredderModule(),
        ])
    }

}
