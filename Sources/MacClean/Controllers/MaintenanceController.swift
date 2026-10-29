import Foundation
import Observation
import AppKit
import MacCleanKit

@MainActor @Observable
final class MaintenanceController {
    private(set) var taskStates: [MaintenanceTask: TaskState] = [:]
    private let executor: MaintenanceExecutor

    init(executor: MaintenanceExecutor = MaintenanceExecutor()) {
        self.executor = executor
    }

    enum TaskState {
        case idle
        case running
        case completed(String)
        case failed(String)
    }

    func isRunning(_ task: MaintenanceTask) -> Bool {
        if case .running = taskStates[task] { return true }
        return false
    }

    private func executeAndStore(_ task: MaintenanceTask) async {
        guard !isRunning(task) else { return }
        taskStates[task] = .running
        let result = await executor.execute(task)
        if result.success {
            taskStates[task] = .completed(result.output)
        } else {
            taskStates[task] = .failed(result.error ?? String(localized: "Unknown error"))
        }
    }

    func runTask(_ task: MaintenanceTask) {
        Task { await executeAndStore(task) }
    }

    func runSafeTasks() {
        let safeTasks = MaintenanceTask.allCases.filter { $0.severity == .safe }
        Task {
            for task in safeTasks {
                await executeAndStore(task)
            }
        }
    }
}
