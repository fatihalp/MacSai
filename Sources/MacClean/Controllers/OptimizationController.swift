import Foundation
import Observation
import AppKit
import MacCleanKit

@MainActor @Observable
final class OptimizationController {
    private(set) var loginItems: [AutoStartItem] = []
    private(set) var launchAgents: [AutoStartItem] = []
    private(set) var launchDaemons: [AutoStartItem] = []
    private(set) var isLoading = true
    var showAlert = false
    private(set) var alertMessage = ""

    let manager = AutoStartManager()

    func refresh() {
        loginItems = manager.getLoginItems()
        launchAgents = manager.getLaunchAgents()
        launchDaemons = manager.getLaunchDaemons()
        isLoading = false
    }
    func toggle(_ item: AutoStartItem, enabled: Bool) {
        do {
            try manager.toggleItem(item, enabled: enabled)
            refresh()
        } catch {
            alertMessage = error.localizedDescription
            showAlert = true
        }
    }

    func openConfig(_ item: AutoStartItem) {
        manager.openConfigInFinder(item)
    }
}
