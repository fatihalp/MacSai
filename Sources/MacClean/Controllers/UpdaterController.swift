import Foundation
import Observation
import AppKit
import MacCleanKit

@MainActor @Observable
final class UpdaterController {
    private(set) var updates: [AppUpdateChecker.AppUpdate] = []
    private(set) var isChecking = false
    private(set) var hasChecked = false
    private(set) var updatingIDs: Set<UUID> = []

    private let discovery = AppDiscovery()
    private let checker = AppUpdateChecker()

    func checkUpdates() {
        guard !isChecking else { return }
        isChecking = true
        Task {
            let apps = await discovery.discoverApps()
            updates = await checker.checkForUpdates(apps: apps)
            isChecking = false
            hasChecked = true
        }
    }

    func startUpdate(_ update: AppUpdateChecker.AppUpdate) {
        guard !updatingIDs.contains(update.id) else { return }
        updatingIDs.insert(update.id)
        Task {
            UpdaterActions.perform(update)
            updatingIDs.remove(update.id)
        }
    }
}
