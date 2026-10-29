import Foundation
import Observation
import MacCleanKit

@MainActor @Observable
public final class ScanCoordinator {
    public enum ScanState: Sendable {
        case idle
        case scanning(progress: Double, currentModule: String, filesScanned: Int, sizeFound: UInt64)
        case completed(results: [ModuleScanResult])
        case failed(Error)
    }

    public private(set) var state: ScanState = .idle
    public private(set) var filesScanned: Int = 0
    public private(set) var totalSizeFound: UInt64 = 0
    public private(set) var completedResults: [ModuleScanResult] = []

    @ObservationIgnored private var scanTask: Task<Void, Never>?
    private var modules: [ScanModule] = []

    public init() {}

    public func registerModule(_ module: ScanModule) {
        modules.append(module)
    }

    public func registerModules(_ newModules: [ScanModule]) {
        modules.append(contentsOf: newModules)
    }

    public func scanAll(onStateChange: (@MainActor (ScanState) -> Void)? = nil) {
        scanModules(modules.filter { $0.includedInSmartScan }, onStateChange: onStateChange)
    }

    public func scanAllIncludingHeavy() {
        scanModules(modules)
    }

    public func scanCategory(_ category: ModuleCategory) {
        let filtered = modules.filter { $0.category == category }
        scanModules(filtered)
    }

    public func scanSingle(_ moduleID: String) {
        let filtered = modules.filter { $0.id == moduleID }
        scanModules(filtered)
    }

    public func cancel() {
        scanTask?.cancel()
        scanTask = nil
        filesScanned = 0
        totalSizeFound = 0
        completedResults = []
        state = .idle
    }

    private func scanModules(
        _ modulesToScan: [ScanModule],
        onStateChange: (@MainActor (ScanState) -> Void)? = nil
    ) {
        scanTask?.cancel()

        filesScanned = 0
        totalSizeFound = 0
        completedResults = []

        scanTask = Task { @MainActor [weak self] in
            guard let self else { return }

            var results: [ModuleScanResult] = []
            let totalModules = modulesToScan.count

            for (index, module) in modulesToScan.enumerated() {
                if Task.isCancelled { break }

                let progress = Double(index) / Double(totalModules)
                self.state = .scanning(
                    progress: progress,
                    currentModule: module.name,
                    filesScanned: self.filesScanned,
                    sizeFound: self.totalSizeFound
                )

                onStateChange?(self.state)

                let start = Date()
                let rawResults = await module.scan()
                if Task.isCancelled { break }

                let scanResults: [ScanResult] = rawResults.map { result in
                    ScanResult(
                        category: result.category,
                        items: result.items.filter { CleanFilter.isActionable($0.url) },
                        autoSelect: result.autoSelect
                    )
                }
                let duration = Date().timeIntervalSince(start)

                let moduleResult = ModuleScanResult(
                    moduleID: module.id,
                    moduleName: module.name,
                    categories: scanResults,
                    scanDuration: duration
                )
                results.append(moduleResult)
                self.completedResults = results

                self.filesScanned += moduleResult.totalFileCount
                self.totalSizeFound += moduleResult.totalSize
            }

            if !Task.isCancelled {
                self.state = .completed(results: results)
                onStateChange?(self.state)
            }
        }
    }
}
