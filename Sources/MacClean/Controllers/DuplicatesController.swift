import Foundation
import Observation
import AppKit
import MacCleanKit

@MainActor @Observable
final class DuplicatesController {
    private let engine: CleaningEngine

    init(engine: CleaningEngine = CleaningEngine()) {
        self.engine = engine
    }

    private(set) var results: [ScanResult] = []
    private(set) var displayGroups: [DuplicateDisplayGroup] = []
    var selectedItems: Set<URL> = []
    private(set) var isScanning = false
    private(set) var scanPhase = ""
    private(set) var scanComplete = false
    private(set) var completion: CleanSummary?
    private(set) var cleaning: CleaningEngine.Progress?
    @ObservationIgnored private var cleanTask: Task<Void, Never>?
    @ObservationIgnored private var scanTask: Task<Void, Never>?
    @ObservationIgnored private var scanTimerTask: Task<Void, Never>?
    private(set) var elapsedSeconds: Int = 0
    @ObservationIgnored private var consolidateTask: Task<Void, Never>?
    @ObservationIgnored private var generation = 0

    func scan() {
        guard cleaning == nil else { return }
        reset()
        isScanning = true
        scanPhase = String(localized: "Hashing candidate files in parallel...")

        scanTimerTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                if Task.isCancelled { return }
                elapsedSeconds += 1
            }
        }

        scanTask = Task {
            let module = DuplicatesModule()
            let groups = await module.scanDisplayGroups()
            if Task.isCancelled { return }

            scanTimerTask?.cancel()
            displayGroups = groups

            let removable = groups.flatMap(\.duplicates)
            results = removable.isEmpty
                ? []
                : [ScanResult(category: .duplicates, items: removable, autoSelect: false)]

            selectedItems = Set(removable.map(\.url))
            isScanning = false
            scanComplete = true
            scanTask = nil
            scanTimerTask = nil
        }
    }

    func cancelScan() {
        scanTask?.cancel()
        scanTimerTask?.cancel()
        scanTask = nil
        scanTimerTask = nil
        isScanning = false
        scanComplete = false
        elapsedSeconds = 0
        scanPhase = ""
    }

    func clean() {
        guard !isScanning, cleaning == nil, !selectedItems.isEmpty else { return }
        let preCleanSelectedCount = selectedItems.count
        let results = results
        let selection = selectedItems
        let generation = generation
        cleaning = CleaningEngine.Progress(
            totalItems: preCleanSelectedCount,
            processedItems: 0, removedSoFar: 0, freedBytesSoFar: 0
        )
        cleanTask = Task {
            let result = await CleanActions.executeUserClean(
                results: results,
                selectedItems: selection,
                engine: engine,
                onProgress: { progress in
                    Task { @MainActor in
                        guard generation == self.generation, self.cleaning != nil else { return }
                        self.cleaning = progress
                    }
                }
            )
            guard generation == self.generation else { return }
            cleaning = nil
            cleanTask = nil
            completion = result.summary(selectedCount: preCleanSelectedCount)
        }
    }

    func consolidate() {
        guard !isScanning, cleaning == nil, !selectedItems.isEmpty else { return }
        let groups = DuplicatesConsolidation.groups(from: displayGroups, selection: selectedItems)
        let planned = groups.reduce(0) { $0 + $1.copies.count }
        cleaning = CleaningEngine.Progress(
            totalItems: planned,
            processedItems: 0, removedSoFar: 0, freedBytesSoFar: 0
        )
        consolidateTask?.cancel()
        let generation = generation
        consolidateTask = Task {
            let worker = Task.detached { FileConsolidator.consolidate(groups: groups) }
            let summary = await withTaskCancellationHandler {
                await worker.value
            } onCancel: {
                worker.cancel()
            }
            guard generation == self.generation else { return }
            consolidateTask = nil
            cleaning = nil
            completion = CleanSummary(
                selectedCount: summary.consolidatedCount + summary.skipped.count + summary.failed.count,
                removedCount: summary.consolidatedCount,
                freedBytes: summary.reclaimedBytes,
                errorMessages: summary.failed.map(\.message)
                    + summary.skipped.map { "\($0.url.lastPathComponent): \(skipLabel($0.reason))" }
            )
        }
    }

    func skipLabel(_ reason: SkipReason) -> String {
        switch reason {
        case .contentChanged: String(localized: "content changed")
        case .notSameVolume: String(localized: "different volume")
        case .cloningUnsupported: String(localized: "not an APFS volume")
        case .notRegularFile: String(localized: "not a regular file")
        case .notWritable: String(localized: "not writable")
        case .protectedPath: String(localized: "protected path")
        }
    }

    func cancelCleaning() {
        cleanTask?.cancel()
        consolidateTask?.cancel()
    }

    func reset() {
        generation &+= 1
        cancelCleaning()
        scanTask?.cancel()
        scanTimerTask?.cancel()
        scanTask = nil
        scanTimerTask = nil
        consolidateTask = nil
        results = []
        displayGroups = []
        selectedItems = []
        completion = nil
        cleaning = nil
        cleanTask = nil
        scanComplete = false
        elapsedSeconds = 0
        isScanning = false
        scanPhase = ""
    }
}
