import Foundation
import Observation
import MacCleanKit

@MainActor @Observable
final class SystemJunkController {
    enum State {
        case idle
        case scanning(progress: Double)
        case results
        case empty
        case cleaning(progress: CleaningEngine.Progress?)
        case done(summary: CleanSummary)
    }

    private(set) var state: State = .idle
    private(set) var results: [ScanResult] = []
    private(set) var review: ReviewSelection?
    private(set) var filesFound = 0
    private(set) var scanPhase = String(localized: "Scanning...")

    @ObservationIgnored private var scanTask: Task<Void, Never>?
    @ObservationIgnored private var cleanTask: Task<Void, Never>?
    @ObservationIgnored private var generation = 0
    private let module: any ScanModule

    init(module: any ScanModule = SystemJunkModule()) {
        self.module = module
    }

    var selectedCount: Int { review?.selectedCount ?? 0 }
    var currentSelectedSize: UInt64 { review?.selectedSize ?? 0 }

    func startScan() {
        if case .cleaning = state { return }
        reset()
        let generation = generation
        state = .scanning(progress: 0)
        scanTask = Task {
            let scanResults = await module.scan()
            guard !Task.isCancelled, generation == self.generation else { return }
            scanPhase = String(localized: "Analyzing results...")
            filesFound = scanResults.reduce(0) { $0 + $1.fileCount }
            let data = await ReviewService.build(
                modules: [ModuleScanResult(
                    moduleID: module.id, moduleName: module.name,
                    categories: scanResults, scanDuration: 0
                )],
                includeEmptySystemJunkCategories: true
            )
            guard !Task.isCancelled, generation == self.generation else { return }
            results = scanResults
            review = ReviewSelection(data: data)
            state = data.items.isEmpty ? .empty : .results
            scanTask = nil
        }
    }

    func startCleaning(engine: CleaningEngine) {
        guard case .results = state, let review, review.selectedCount > 0 else { return }
        let selectedCount = review.selectedCount
        let results = results
        let data = review.data
        let flags = review.snapshot()
        let generation = generation
        state = .cleaning(progress: nil)
        cleanTask = Task {
            let selection = await Task.detached(priority: .userInitiated) {
                data.selectedURLs(flags: flags)
            }.value
            guard generation == self.generation else { return }
            let result = await CleanActions.executeUserClean(
                results: results,
                selectedItems: selection,
                engine: engine,
                onProgress: { progress in
                    Task { @MainActor in
                        guard generation == self.generation, case .cleaning = self.state else { return }
                        self.state = .cleaning(progress: progress)
                    }
                }
            )
            guard generation == self.generation else { return }
            state = .done(summary: result.summary(selectedCount: selectedCount))
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
        state = .idle
        results = []
        review = nil
        filesFound = 0
        scanPhase = String(localized: "Scanning...")
    }
}
