import Foundation
import Observation
import AppKit
import MacCleanKit

@MainActor @Observable
final class UninstallerController {
    private let engine: CleaningEngine

    init(engine: CleaningEngine = CleaningEngine()) {
        self.engine = engine
    }

    private(set) var apps: [AppInfo] = []
    var selectedApp: AppInfo?
    var checkedAppIDs: Set<UUID> = []
    private(set) var associatedFiles: [FileItem] = []
    var selectedFiles: Set<URL> = []
    private(set) var isLoading = true
    private(set) var isLoadingFiles = false
    private(set) var isUninstalling = false
    private(set) var isResetting = false
    var uninstallError: String?
    var resetError: String?
    var filter: AppFilter = .all
    var searchText = ""

    enum AppFilter: String, CaseIterable {
        case all = "All"
        case unused = "Unused"
        case thirdParty = "Third-party"

        var label: String { String(localized: rawValue) }
    }

    @ObservationIgnored private var associatedFilesTask: Task<Void, Never>?
    private let discovery = AppDiscovery()
    private let pathFinder = AppPathFinder()
    let safetyGuard = SafetyGuard()

    var checkedApps: [AppInfo] {
        apps.filter { checkedAppIDs.contains($0.id) && !safetyGuard.isProtectedApp($0.bundleIdentifier) }
    }

    var checkedTotalSize: UInt64 {
        checkedApps.reduce(0) { $0 + $1.size }
    }

    var filteredApps: [AppInfo] {
        var filtered = apps
        switch filter {
        case .all: break
        case .unused: filtered = filtered.filter(\.isUnused)
        case .thirdParty: filtered = filtered.filter { !$0.isAppleApp }
        }
        if !searchText.isEmpty {
            filtered = filtered.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.bundleIdentifier.localizedCaseInsensitiveContains(searchText)
            }
        }
        return filtered
    }

    func resetToDefaults(_ app: AppInfo) {
        guard !isResetting, !isUninstalling, !isLoadingFiles else { return }
        guard let plan = AppReset.plan(
            app: app,
            associatedFiles: associatedFiles,
            selectedFiles: selectedFiles
        ) else { return }

        isResetting = true
        Task {
            let result = await CleanActions.executeUserClean(
                items: plan.items,
                selectedItems: plan.selection,
                engine: engine
            )
            if !result.errors.isEmpty {
                resetError = "Some items couldn't be reset for \(app.name) (\(result.errors.count)). Quit the app if it is running and try again."
            }
            loadAssociatedFiles(for: app)
            isResetting = false
        }
    }

    func loadApps() async {
        apps = await discovery.discoverApps()
        checkedAppIDs = checkedAppIDs.intersection(Set(apps.map(\.id)))
        isLoading = false
    }

    func selectPendingApp(path: String) {
        guard let match = apps.first(where: {
            $0.path.path(percentEncoded: false) == path
        }) else { return }
        selectedApp = match
        loadAssociatedFiles(for: match)
        filter = .all
    }

    func loadAssociatedFiles(for app: AppInfo) {
        associatedFilesTask?.cancel()
        isLoadingFiles = true
        associatedFiles = []
        selectedFiles = []
        let pathFinder = pathFinder
        associatedFilesTask = Task {
            let files = await Task.detached(priority: .userInitiated) {
                pathFinder.findAssociatedFiles(for: app)
            }.value
            guard !Task.isCancelled, selectedApp?.id == app.id else { return }
            associatedFiles = files
            selectedFiles = Set(files.map(\.url))
            isLoadingFiles = false
            associatedFilesTask = nil
        }
    }

    func uninstall(_ app: AppInfo) {
        guard !isUninstalling, !isResetting, !isLoadingFiles else { return }
        guard let plan = AppUninstaller.plan(
            app: app,
            associatedFiles: associatedFiles,
            selectedFiles: selectedFiles,
            safetyGuard: safetyGuard
        ) else {
            uninstallError = "\(app.name) is a protected system app and can't be removed."
            return
        }

        isUninstalling = true
        Task {
            let result = await CleanActions.executeUserClean(
                items: plan.items,
                selectedItems: plan.selection,
                engine: engine
            )
            if !result.errors.isEmpty {
                uninstallError = "Some items couldn't be removed while uninstalling \(app.name) (\(result.errors.count)). Check whether the app is still there and try again."
            }
            checkedAppIDs.remove(app.id)
            await loadApps()
            isUninstalling = false
            selectedApp = nil
            associatedFiles = []
        }
    }

    func uninstallBatch(_ targets: [AppInfo]) {
        guard !isUninstalling, !isResetting, !targets.isEmpty else { return }
        isUninstalling = true
        Task {
            var allItems: [FileItem] = []
            var allSelection: Set<URL> = []
            for app in targets {
                let files = pathFinder.findAssociatedFiles(for: app)
                let fileURLs = Set(files.map(\.url))
                if let plan = AppUninstaller.plan(
                    app: app,
                    associatedFiles: files,
                    selectedFiles: fileURLs,
                    safetyGuard: safetyGuard
                ) {
                    allItems.append(contentsOf: plan.items)
                    allSelection.formUnion(plan.selection)
                }
            }
            if !allItems.isEmpty {
                let result = await CleanActions.executeUserClean(
                    items: allItems,
                    selectedItems: allSelection,
                    engine: engine
                )
                if !result.errors.isEmpty {
                    uninstallError = "Some items couldn't be removed (\(result.errors.count))."
                }
            }
            checkedAppIDs.removeAll()
            await loadApps()
            isUninstalling = false
            selectedApp = nil
            associatedFiles = []
        }
    }
}
