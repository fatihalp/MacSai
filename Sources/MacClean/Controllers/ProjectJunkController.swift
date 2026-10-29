import Foundation
import Observation
import MacCleanKit

@MainActor @Observable
final class ProjectJunkController {
    private(set) var rootURL: URL?
    private(set) var scannedRootsCount: Int = 0
    private(set) var rootRefused = false
    private(set) var results: [ScanResult] = []
    private(set) var items: [ProjectJunkItem] = []
    private(set) var gitStatuses: [String: GitRepoStatus] = [:]
    var selectedItems: Set<URL> = []
    private(set) var isScanning = false
    private(set) var scanProgress: Double = 0
    private(set) var scanPhase = ""
    private(set) var scanComplete = false
    private(set) var completion: CleanSummary?
    private(set) var cleaning: CleaningEngine.Progress?
    @ObservationIgnored private var isAccessingRoot = false
    @ObservationIgnored private var cleanTask: Task<Void, Never>?
    @ObservationIgnored private var scanTask: Task<Void, Never>?
    @ObservationIgnored private var scanGeneration = 0
    @ObservationIgnored private var cleanGeneration = 0
    private let scanner = ProjectJunkScanner()

    static var findingPhase: String {
        String(localized: "Finding projects…")
    }

    static var measuringPhase: String {
        String(localized: "Measuring folders…")
    }

    static var checkingGitPhase: String {
        String(localized: "Checking Git status…")
    }

    var availableDefaultRoots: [URL] {
        ProjectJunkScanner.defaultProjectRoots()
    }

    func scanDefaultRoots() {
        let roots = availableDefaultRoots
        guard !roots.isEmpty else { return }
        cancelScan()
        releaseRoot()
        rootURL = roots.count == 1 ? roots.first : nil
        scannedRootsCount = roots.count
        rootRefused = false
        results = []
        items = []
        gitStatuses = [:]
        selectedItems = []
        completion = nil
        scanComplete = false
        startScanTask(roots: roots)
    }

    func runScan(root: URL) {
        cancelScan()
        releaseRoot()
        rootURL = root
        scannedRootsCount = 1
        isAccessingRoot = root.startAccessingSecurityScopedResource()
        rootRefused = !ProjectJunkScanner.isAllowedRoot(root)
        results = []
        items = []
        gitStatuses = [:]
        selectedItems = []
        completion = nil
        scanComplete = false
        if rootRefused {
            scanComplete = true
            return
        }
        startScanTask(roots: [root])
    }

    private func startScanTask(roots: [URL]) {
        scanGeneration += 1
        let generation = scanGeneration
        isScanning = true
        scanProgress = 0.05
        scanPhase = Self.findingPhase
        let scanner = scanner
        scanTask = Task {
            let worker = Task.detached(priority: .userInitiated) {
                scanner.scan(roots: roots) { fraction in
                    Task { @MainActor in
                        guard generation == self.scanGeneration else { return }
                        self.scanProgress = max(self.scanProgress, fraction * 0.9)
                        self.scanPhase = Self.measuringPhase
                    }
                }
            }
            let foundItems = await withTaskCancellationHandler {
                await worker.value
            } onCancel: {
                worker.cancel()
            }
            guard !Task.isCancelled, generation == scanGeneration else { return }
            scanPhase = Self.checkingGitPhase
            scanProgress = 0.95
            let statuses = await scanner.gitStatuses(for: foundItems)
            guard !Task.isCancelled, generation == scanGeneration else { return }
            items = foundItems
            gitStatuses = statuses
            results = scanner.asScanResults(foundItems)
            selectedItems = []
            scanProgress = 1
            isScanning = false
            scanComplete = true
        }
    }

    func cancelScan() {
        scanGeneration += 1
        scanTask?.cancel()
        scanTask = nil
        isScanning = false
    }

    func cancelClean() {
        cleanTask?.cancel()
    }

    func clean(engine: CleaningEngine) {
        guard !isScanning, cleaning == nil, !selectedItems.isEmpty else { return }
        let preCleanSelectedCount = selectedItems.count
        let results = results
        let selectedItems = selectedItems
        let generation = cleanGeneration
        cleaning = CleaningEngine.Progress(
            totalItems: preCleanSelectedCount,
            processedItems: 0, removedSoFar: 0, freedBytesSoFar: 0
        )
        cleanTask = Task {
            let result = await CleanActions.executeUserClean(
                results: results,
                selectedItems: selectedItems,
                engine: engine,
                onProgress: { progress in
                    Task { @MainActor in
                        guard generation == self.cleanGeneration, self.cleaning != nil else { return }
                        self.cleaning = progress
                    }
                }
            )
            guard generation == cleanGeneration else { return }
            cleaning = nil
            cleanTask = nil
            completion = result.summary(selectedCount: preCleanSelectedCount)
        }
    }

    func reset() {
        cleanGeneration &+= 1
        cleanTask?.cancel()
        cancelScan()
        releaseRoot()
        rootURL = nil
        scannedRootsCount = 0
        rootRefused = false
        results = []
        items = []
        gitStatuses = [:]
        selectedItems = []
        completion = nil
        cleaning = nil
        cleanTask = nil
        scanProgress = 0
        scanComplete = false
    }

    private func releaseRoot() {
        if isAccessingRoot, let rootURL {
            rootURL.stopAccessingSecurityScopedResource()
        }
        isAccessingRoot = false
    }
}
