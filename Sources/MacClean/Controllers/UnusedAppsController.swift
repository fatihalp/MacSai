import Foundation
import Observation
import AppKit
import MacCleanKit

@MainActor @Observable
final class UnusedAppsController {
    private let engine: CleaningEngine

    init(engine: CleaningEngine = CleaningEngine()) {
        self.engine = engine
    }

    var horizon: UnusedAppHorizon = .sixMonths
    private(set) var records: [UnusedAppRecord] = []
    var selectedPaths: Set<String> = []
    private(set) var isLoading = true
    private(set) var isUninstalling = false
    @ObservationIgnored private var loadGeneration = 0

    private let discovery = AppDiscovery()
    private let pathFinder = AppPathFinder()
    let safetyGuard = SafetyGuard()

    var apps: [UnusedAppRecord] { UnusedApps.unused(from: records, horizon: horizon) }
    var selectedApps: [UnusedAppRecord] {
        apps.filter { selectedPaths.contains($0.path) }
    }

    var selectedTotalBytes: UInt64 {
        selectedApps.reduce(0) { $0 + $1.totalBytes }
    }

    func reload() async {
        loadGeneration &+= 1
        let generation = loadGeneration
        isLoading = true
        let running = Set(NSWorkspace.shared.runningApplications.compactMap {
            $0.bundleURL?.path(percentEncoded: false)
        })
        let listed = await Task.detached {
            await UnusedAppsClient().records(runningAppPaths: running)
        }.value
        guard generation == loadGeneration else { return }
        records = listed
        selectedPaths = selectedPaths.intersection(Set(listed.map(\.path)))
        isLoading = false
    }

    func uninstallSelectedApps() {
        let pathsToRemove = selectedPaths
        guard !pathsToRemove.isEmpty, !isUninstalling else { return }
        isUninstalling = true
        Task {
            let discovered = await discovery.discoverApps()
            var allItems: [FileItem] = []
            var allSelection: Set<URL> = []
            for app in discovered where pathsToRemove.contains(app.path.path(percentEncoded: false)) {
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
                _ = await CleanActions.executeUserClean(
                    items: allItems,
                    selectedItems: allSelection,
                    engine: engine
                )
            }
            selectedPaths.removeAll()
            isUninstalling = false
            await reload()
        }
    }
}
