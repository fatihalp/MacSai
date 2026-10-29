import Foundation
import Observation
import AppKit
import MacCleanKit

@MainActor @Observable
final class DiskHogsController {
    private(set) var dockerState: DiskHogsClient.DockerState = .notInstalled
    var selectedDocker: Set<DockerDiskCategory> = DockerPrune.defaultSelection
    private(set) var devices: [SimulatorDevice] = []
    private(set) var runtimes: [SimulatorRuntime] = []
    var selectedSim: Set<String> = SimulatorInventory.defaultSelection
    private(set) var isLoading = true
    private(set) var isWorking = false
    private(set) var statusLines: [String] = []
    @ObservationIgnored private var workTask: Task<Void, Never>?

    let client: DiskHogsClient

    init(client: DiskHogsClient = DiskHogsClient()) {
        self.client = client
    }

    var dockerRows: [DockerDiskRow] {
        if case .rows(let rows) = dockerState { return rows }
        return []
    }

    var selectedDevices: [SimulatorDevice] { devices.filter { selectedSim.contains($0.udid) } }
    var selectedRuntimes: [SimulatorRuntime] { runtimes.filter { selectedSim.contains($0.identifier) } }

    func startWork(_ work: @escaping @MainActor () async -> Void) {
        workTask?.cancel()
        workTask = Task { await work() }
    }

    func reload() async {
        isLoading = true
        async let docker = client.dockerState()
        async let sims = client.simulators()
        let (state, simulators) = await (docker, sims)
        if Task.isCancelled { return }
        dockerState = state
        devices = simulators.devices
        runtimes = simulators.runtimes
        selectedDocker = DockerPrune.defaultSelection
        selectedSim = SimulatorInventory.defaultSelection
        isLoading = false
    }

    func pruneDocker(_ selection: Set<DockerDiskCategory>) async {
        isWorking = true
        defer { isWorking = false }
        let results = await client.pruneDocker(selection: selection)
        statusLines = results.map { DiskHogsText.statusLine(name: $0.name, outcome: $0.outcome, success: DiskHogsText.pruned) }
        selectedDocker = []
        if Task.isCancelled { return }
        dockerState = await client.dockerState()
    }

    func deleteSims(devices: [SimulatorDevice], runtimes: [SimulatorRuntime]) async {
        isWorking = true
        defer { isWorking = false }
        let results = await client.deleteSimulators(devices: devices, runtimes: runtimes)
        statusLines = results.map { DiskHogsText.statusLine(name: $0.name, outcome: $0.outcome, success: DiskHogsText.deleted) }
        selectedSim = []
        if Task.isCancelled { return }
        let refreshed = await client.simulators()
        self.devices = refreshed.devices
        self.runtimes = refreshed.runtimes
    }
    func cancelWork() {
        workTask?.cancel()
        workTask = nil
    }
}
