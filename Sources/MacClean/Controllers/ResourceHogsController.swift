import Foundation
import Observation
import AppKit
import MacCleanKit

@MainActor @Observable
final class ResourceHogsController {
    private(set) var rows: [ResourceHogRow] = []
    var sortBy: ResourceHogsPolicy.SortKey = .cpu
    private(set) var isLoading = true
    var pendingQuit: ResourceHogRow?
    private(set) var statusMessage: String?
    var showStatus = false

    private let collector = ProcessStatsCollector()
    private let monitor = ProcessMonitor()
    private let listLimit = 40

    func refresh() async {
        let stats = await collector.getProcessStats()
        guard !Task.isCancelled else { return }
        let snapshots = stats.map {
            ResourceHogSnapshot(
                pid: $0.id,
                name: $0.name,
                cpuPercent: $0.cpuPercent,
                memoryBytes: $0.memoryBytes,
                bundleIdentifier: $0.bundleIdentifier
            )
        }
        rows = ResourceHogsPolicy.rows(from: snapshots, sortBy: sortBy, limit: listLimit)
        isLoading = false
    }

    func quitPending() {
        guard let row = pendingQuit else { return }
        pendingQuit = nil
        guard row.canQuit else {
            statusMessage = String(localized: "That process is protected and cannot be quit.")
            showStatus = true
            return
        }

        guard let live = NSRunningApplication(processIdentifier: row.snapshot.pid),
              live.bundleIdentifier == row.snapshot.bundleIdentifier,
              ResourceHogsPolicy.canQuit(bundleIdentifier: live.bundleIdentifier) else {
            statusMessage = String(localized: "That process is no longer running.")
            showStatus = true
            return
        }
        monitor.forceQuit(pid: row.snapshot.pid)
        Task { await refresh() }
    }

    func monitorProcesses() async {
        while !Task.isCancelled {
            await refresh()
            do { try await Task.sleep(for: .milliseconds(2500)) }
            catch { return }
        }
    }
}
