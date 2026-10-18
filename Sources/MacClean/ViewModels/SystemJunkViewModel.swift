import SwiftUI
import AppKit
import MacCleanKit

@MainActor @Observable
final class SystemJunkViewModel {
    enum State {
        case idle
        case scanning(progress: Double)
        case results
        case empty
        case cleaning(progress: CleaningEngine.Progress?)
        case done(summary: CleanSummary)
    }

    var state: State = .idle
    var results: [ScanResult] = [] {
        didSet { rebuildSizeIndex() }
    }
    var selectedItems: Set<URL> = [] {
        didSet { recomputeSelectedSize() }
    }
    var review: ReviewSelection?
    var filesFound: Int = 0
    var scanPhase: String = String(localized: "Scanning...")

    private var cleanTask: Task<Void, Never>?

    private let module = SystemJunkModule()

    private(set) var totalSelectedSize: UInt64 = 0

    private var sizeByURL: [URL: UInt64] = [:]

    private func rebuildSizeIndex() {
        var map = [URL: UInt64](minimumCapacity: results.reduce(0) { $0 + $1.items.count })
        for result in results {
            for item in result.items { map[item.url] = item.size }
        }
        sizeByURL = map
        recomputeSelectedSize()
    }

    private func recomputeSelectedSize() {
        var total: UInt64 = 0
        for url in selectedItems { total += sizeByURL[url] ?? 0 }
        totalSelectedSize = total
    }

    var selectedCount: Int {
        if let review, !review.data.items.isEmpty {
            return review.selectedCount
        }
        return selectedItems.count
    }

    var currentSelectedSize: UInt64 {
        if let review, !review.data.items.isEmpty {
            return review.selectedSize
        }
        return totalSelectedSize
    }

    var totalFileCount: Int {
        results.reduce(0) { $0 + $1.fileCount }
    }

    func exportedSelectedURLs() -> Set<URL> {
        if let review, !review.data.items.isEmpty {
            return review.data.selectedURLs(flags: review.snapshot())
        }
        return selectedItems
    }

    func startScan() {
        state = .scanning(progress: 0)
        filesFound = 0
        results = []
        selectedItems = []
        review = nil
        scanPhase = String(localized: "Scanning caches...")

        Task {
            let scanStart = Date()

            state = .scanning(progress: 0.1)
            scanPhase = String(localized: "Scanning user caches...")
            try? await Task.sleep(for: .milliseconds(300))

            scanPhase = String(localized: "Scanning system logs...")
            state = .scanning(progress: 0.25)

            async let scanTask = module.scan()

            try? await Task.sleep(for: .milliseconds(400))
            scanPhase = String(localized: "Checking language files...")
            state = .scanning(progress: 0.4)

            try? await Task.sleep(for: .milliseconds(300))
            scanPhase = String(localized: "Inspecting preferences...")
            state = .scanning(progress: 0.55)

            try? await Task.sleep(for: .milliseconds(300))
            scanPhase = String(localized: "Checking login items...")
            state = .scanning(progress: 0.7)

            let scanResults = await scanTask

            scanPhase = String(localized: "Analyzing results...")
            state = .scanning(progress: 0.9)

            results = scanResults
            filesFound = scanResults.reduce(0) { $0 + $1.fileCount }

            let running = Set(NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier))
            let moduleName = String(localized: "System Junk")
            let data = await Task.detached(priority: .userInitiated) {
                ReviewDataBuilder.build(
                    modules: [ModuleScanResult(
                        moduleID: "system_junk",
                        moduleName: moduleName,
                        categories: scanResults,
                        scanDuration: 0
                    )],
                    runningBundleIDs: running,
                    includeEmptySystemJunkCategories: true
                )
            }.value
            let newReview = ReviewSelection(data: data)
            review = newReview
            totalSelectedSize = newReview.selectedSize

            let elapsed = Date().timeIntervalSince(scanStart)
            if elapsed < 2.0 {
                try? await Task.sleep(for: .milliseconds(Int((2.0 - elapsed) * 1000)))
            }

            state = .scanning(progress: 1.0)
            try? await Task.sleep(for: .milliseconds(300))
            state = scanResults.isEmpty ? .empty : .results
        }
    }

    func startCleaning(engine: CleaningEngine) {
        state = .cleaning(progress: nil)
        let preCleanSelectedCount = selectedCount
        let currentResults = results
        let reviewData = review?.data
        let flags = review?.snapshot()
        let fallbackSelection = selectedItems

        cleanTask = Task { [weak self] in
            let selection: Set<URL>
            if let reviewData, let flags, !reviewData.items.isEmpty {
                selection = await Task.detached(priority: .userInitiated) {
                    reviewData.selectedURLs(flags: flags)
                }.value
            } else {
                selection = fallbackSelection
            }

            let result = await CleanActions.executeUserClean(
                results: currentResults,
                selectedItems: selection,
                engine: engine,
                onProgress: { [weak self] progress in
                    Task { @MainActor in
                        guard let self else { return }
                        if case .cleaning = self.state {
                            self.state = .cleaning(progress: progress)
                        }
                    }
                }
            )
            guard let self else { return }
            self.state = .done(summary: CleanSummary(
                selectedCount: preCleanSelectedCount,
                removedCount: result.removedCount,
                freedBytes: result.freedBytes,
                errorMessages: result.errors.map(\.error)
            ))
        }
    }

    func cancelCleaning() {
        cleanTask?.cancel()
    }

    func reset() {
        state = .idle
        results = []
        selectedItems = []
        review = nil
        filesFound = 0
        cleanTask = nil
    }

    func restore(results: [ScanResult], selection: Set<URL>, scanComplete: Bool) {
        self.results = results
        self.selectedItems = selection
        self.filesFound = results.reduce(0) { $0 + $1.fileCount }
        if !results.isEmpty {
            let running = Set(NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier))
            let data = ReviewDataBuilder.build(
                modules: [ModuleScanResult(
                    moduleID: "system_junk",
                    moduleName: String(localized: "System Junk"),
                    categories: results,
                    scanDuration: 0
                )],
                runningBundleIDs: running,
                includeEmptySystemJunkCategories: true
            )
            let restoredReview = ReviewSelection(data: data)
            if !data.items.isEmpty && !selection.isEmpty {
                restoredReview.applySelectedURLs(selection)
            }
            self.review = restoredReview
        } else {
            self.review = nil
        }
        state = scanComplete ? (results.isEmpty ? .empty : .results) : .idle
    }

    var isScanComplete: Bool {
        switch state {
        case .results, .empty: return true
        default: return false
        }
    }
}
