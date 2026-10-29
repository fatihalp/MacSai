import Foundation
import Observation
import MacCleanKit

@MainActor @Observable
final class CleanHistoryController {
    private(set) var sessions: [CleanHistorySession] = []
    private(set) var isRestoring = false
    var lastSummary: CleanHistoryRestoreSummary?

    func reload() async {
        let sessions = await Task.detached { CleanHistoryRecorder.load() }.value
        guard !Task.isCancelled else { return }
        self.sessions = sessions
    }

    func restore(_ session: CleanHistorySession) async {
        guard !isRestoring else { return }
        isRestoring = true
        defer { isRestoring = false }
        lastSummary = await Task.detached { CleanHistoryRecorder.restore(session) }.value
        await reload()
    }

    func clear() {
        guard !isRestoring else { return }
        CleanHistoryRecorder.clear()
        sessions = []
    }
}
