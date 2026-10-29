import Foundation
import Observation
import MacCleanKit

@MainActor @Observable
public final class AppState {
    var selectedCategory: SidebarCategory = .smartScan
    var selectedSidebarItem: SidebarItem? = .smartScan
    let scanCoordinator = ScanCoordinator()
    let cleaningEngine = CleaningEngine()
    @ObservationIgnored lazy var smartScanController = SmartScanController(coordinator: scanCoordinator, engine: cleaningEngine)
    let systemJunkController = SystemJunkController()
    @ObservationIgnored lazy var uninstallerController = UninstallerController(engine: cleaningEngine)
    @ObservationIgnored lazy var unusedAppsController = UnusedAppsController(engine: cleaningEngine)
    @ObservationIgnored lazy var extensionsController = ExtensionsController(engine: cleaningEngine)
    @ObservationIgnored lazy var duplicatesController = DuplicatesController(engine: cleaningEngine)
    @ObservationIgnored private var scanControllers: [ScanFeature: ScanController] = [:]

    func scanController(for feature: ScanFeature) -> ScanController {
        if let controller = scanControllers[feature] { return controller }
        let controller = ScanController(module: feature.module, selectAll: feature.selectAll)
        scanControllers[feature] = controller
        return controller
    }

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
