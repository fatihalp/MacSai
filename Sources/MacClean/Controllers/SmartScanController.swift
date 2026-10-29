import Foundation
import Observation
import MacCleanKit

@MainActor @Observable
final class SmartScanController {
    private(set) var scanState: SmartScanState = .idle
    private(set) var completedModules: [CompletedModule] = []
    private(set) var currentModuleName = ""
    private(set) var askForSupport = false
    private(set) var review: ReviewSelection?
    var showingReview = false
    var reviewSectionID: String?
    @ObservationIgnored private var cleanTask: Task<Void, Never>?
    @ObservationIgnored private var reviewTask: Task<Void, Never>?
    @ObservationIgnored private var generation = 0
    private let coordinator: ScanCoordinator
    private let engine: CleaningEngine
    private var moduleResults: [ModuleScanResult] = []

    init(coordinator: ScanCoordinator, engine: CleaningEngine) {
        self.coordinator = coordinator
        self.engine = engine
    }

    func startScan() {
        if case .cleaning = scanState { return }
        resetScan()
        scanState = .scanning(
            phase: String(localized: "Analyzing system..."), progress: 0, filesFound: 0, sizeFound: 0
        )
        coordinator.scanAll { [weak self] state in
            self?.receive(state)
        }
    }

    private func receive(_ state: ScanCoordinator.ScanState) {
        completedModules = coordinator.completedResults.map { result in
            CompletedModule(
                name: result.moduleName,
                icon: SmartScanModules.order.first { $0.name == result.moduleName }?.icon ?? "circle",
                fileCount: result.totalFileCount,
                size: result.totalSize
            )
        }
        switch state {
        case .scanning(let progress, let module, let files, let size):
            currentModuleName = module
            scanState = .scanning(phase: module, progress: progress, filesFound: files, sizeFound: size)
        case .completed(let results):
            prepareReview(results)
        case .idle, .failed:
            scanState = .idle
        }
    }

    private func prepareReview(_ results: [ModuleScanResult]) {
        let totalSize = results.reduce(UInt64(0)) { $0 + $1.totalSize }
        let fileCount = results.reduce(0) { $0 + $1.totalFileCount }
        guard fileCount > 0 else {
            scanState = .empty
            return
        }
        scanState = .scanning(
            phase: String(localized: "Preparing results..."), progress: 1,
            filesFound: fileCount, sizeFound: totalSize
        )
        let generation = generation
        reviewTask = Task {
            let data = await ReviewService.build(modules: results, includeEmptySystemJunkCategories: true)
            guard !Task.isCancelled, generation == self.generation else { return }
            moduleResults = results
            review = ReviewSelection(data: data)
            showingReview = true
            reviewSectionID = nil
            scanState = .results(
                cleanup: totalSize, protection: 0, performance: 0,
                totalSize: totalSize, moduleResults: results
            )
            reviewTask = nil
        }
    }

    func runCleanup() {
        guard case .results = scanState, let review, review.selectedCount > 0 else { return }
        let modules = moduleResults
        let results = SmartScanCleanup.allResults(from: modules)
        let data = review.data
        let flags = review.snapshot()
        let generation = generation
        scanState = .cleaning(progress: 0)
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
                        guard generation == self.generation, case .cleaning = self.scanState else { return }
                        self.scanState = .cleaning(progress: progress.fraction)
                    }
                }
            )
            guard generation == self.generation else { return }
            let breakdown = SmartScanCleanup.recentlyCleanedBreakdown(
                from: modules, selectedItems: result.removedURLs
            )
            askForSupport = SupportAskLedger.shared.shouldAsk(for: result.summary(selectedCount: selection.count))
            scanState = .done(freedSize: result.freedBytes, breakdown: breakdown)
            cleanTask = nil
        }
    }

    func cancelCleaning() {
        cleanTask?.cancel()
    }

    func cancelScan() {
        resetScan()
    }

    func resetScan() {
        generation &+= 1
        coordinator.cancel()
        reviewTask?.cancel()
        cleanTask?.cancel()
        reviewTask = nil
        cleanTask = nil
        review = nil
        showingReview = false
        reviewSectionID = nil
        askForSupport = false
        completedModules = []
        moduleResults = []
        currentModuleName = ""
        scanState = .idle
    }
}
