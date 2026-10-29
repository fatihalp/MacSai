import Foundation
import Observation
import MacCleanKit

@MainActor @Observable
final class ScanController {
    private(set) var results: [ScanResult] = []
    var selectedItems: Set<URL> = []
    private(set) var isScanning = false
    private(set) var scanComplete = false
    private(set) var permissionDenied = false
    private(set) var completion: CleanSummary?
    private(set) var cleaning: CleaningEngine.Progress?

    @ObservationIgnored private var scanTask: Task<Void, Never>?
    @ObservationIgnored private var cleanTask: Task<Void, Never>?
    @ObservationIgnored private var generation = 0
    private let module: any ScanModule
    private let selectAll: Bool

    init(module: any ScanModule, selectAll: Bool = false) {
        self.module = module
        self.selectAll = selectAll
    }

    func scan() {
        guard !isScanning, cleaning == nil else { return }
        reset()
        isScanning = true
        let generation = generation
        scanTask = Task {
            let outcome = await module.scanOutcome()
            guard !Task.isCancelled, generation == self.generation else { return }
            results = outcome.results
            permissionDenied = outcome.permissionDenied
            selectedItems = Set(results.filter { selectAll || $0.autoSelect }.flatMap(\.items).map(\.url))
            isScanning = false
            scanComplete = true
            scanTask = nil
        }
    }

    func clean(engine: CleaningEngine) {
        guard !isScanning, cleaning == nil, !selectedItems.isEmpty else { return }
        let results = results
        let selection = selectedItems
        let generation = generation
        cleaning = CleaningEngine.Progress(
            totalItems: selection.count, processedItems: 0, removedSoFar: 0, freedBytesSoFar: 0
        )
        cleanTask = Task {
            let result = await CleanActions.executeUserClean(
                results: results,
                selectedItems: selection,
                engine: engine,
                onProgress: { progress in
                    Task { @MainActor in
                        guard self.generation == generation, self.cleaning != nil else { return }
                        self.cleaning = progress
                    }
                }
            )
            guard generation == self.generation else { return }
            cleaning = nil
            completion = result.summary(selectedCount: selection.count)
            cleanTask = nil
        }
    }

    func cancelCleaning() {
        cleanTask?.cancel()
    }

    func reset() {
        generation &+= 1
        scanTask?.cancel()
        cleanTask?.cancel()
        scanTask = nil
        cleanTask = nil
        results = []
        selectedItems = []
        isScanning = false
        scanComplete = false
        permissionDenied = false
        completion = nil
        cleaning = nil
    }
}
