import SwiftUI
import AppKit
import OSLog
import MacCleanKit

@MainActor
@Observable
final class MenuStatsModel {
    static let shared = MenuStatsModel()

    private(set) var stats: SystemStatsCollector.SystemStats?
    private(set) var networkSpeed: NetworkSpeedMonitor.NetworkSpeed?
    private(set) var devices: ConnectedDevices?
    private(set) var protection: SharedAppState.ProtectionStatus?
    private(set) var tips: [TipsEngine.Tip] = []

    private let statsCollector = SystemStatsCollector()
    private let networkMonitor = NetworkSpeedMonitor()
    private let devicesCollector = ConnectedDevicesCollector()
    private let tipsEngine = TipsEngine()
    private let healthMonitor = HealthMonitor()

    private var pollingTask: Task<Void, Never>?
    private var tickCount = 0

    private static let log = Logger(subsystem: MCConstants.menuBundleIdentifier, category: "SystemStats")

    private init() {}

    func start() {
        guard pollingTask == nil else { return }
        Self.log.info("stats polling started")
        pollingTask = Task { await self.run() }
    }

    func dismissTip(id: String) {
        SharedAppState.dismissTip(id: id)
        tips.removeAll { $0.id == id }
    }

    private func run() async {
        while !Task.isCancelled {

            if let s = await timed("stats", budget: .seconds(2), { await self.statsCollector.collect() }) {
                stats = s
                await healthMonitor.evaluate(stats: s)
            }
            if let n = await timed("network", budget: .seconds(2), { await self.networkMonitor.measure() }) {
                networkSpeed = n
            }
            protection = SharedAppState.protectionStatus
            tickCount += 1
            if tickCount % 10 == 1 {
                if let d = await timed("devices", budget: .seconds(3), { await self.devicesCollector.collect() }) {
                    devices = d
                }
                if let t = await timed("tips", budget: .seconds(3), { await self.tipsEngine.generateTips() }) {
                    tips = t
                }
            }
            try? await Task.sleep(for: .seconds(3))
        }
    }

    private func timed<T: Sendable>(
        _ label: String,
        budget: Duration,
        _ op: @escaping @Sendable () async -> T
    ) async -> T? {
        let start = ContinuousClock.now
        do {
            let value = try await withTimeout(budget) { await op() }
            let elapsed = ContinuousClock.now - start
            if elapsed > .milliseconds(500) {
                Self.log.warning("stats step '\(label, privacy: .public)' slow: \(elapsed.description, privacy: .public)")
            }
            return value
        } catch {
            Self.log.error("stats step '\(label, privacy: .public)' exceeded its budget; skipping this tick")
            return nil
        }
    }
}

@MainActor
final class MenuAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        MenuStatsModel.shared.start()
    }
}
