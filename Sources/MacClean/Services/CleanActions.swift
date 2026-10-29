import Foundation
import MacCleanKit

public enum CleanActions {

    @discardableResult
    public static func executeUserClean(
        results: [ScanResult],
        selectedItems: Set<URL>,
        engine: CleaningEngine,
        onProgress: (@Sendable (CleaningEngine.Progress) -> Void)? = nil
    ) async -> CleaningEngine.CleanResult {
        var trashItems: [FileItem] = []
        var permanentItems: [FileItem] = []
        var thinItems: [FileItem] = []
        for result in results {
            for item in result.items where selectedItems.contains(item.url) {
                switch result.category {
                case .universalBinaries:
                    thinItems.append(item)
                case .trashBins:
                    permanentItems.append(item)
                default:
                    trashItems.append(item)
                }
            }
        }

        let dedupedTrashItems = Self.prunedToParents(trashItems)
        let dedupedPermanentItems = Self.prunedToParents(permanentItems)

        let trashResult = await engine.clean(items: dedupedTrashItems, mode: .trash,
                                             onProgress: onProgress)
        CleanHistoryRecorder.record(trashedItems: trashResult.trashedItems)
        if Task.isCancelled {
            return trashResult
        }

        let permanentResult = await engine.clean(items: dedupedPermanentItems, mode: .permanent,
                                                 onProgress: onProgress)
        let combinedResult = trashResult.merging(permanentResult)
        if Task.isCancelled { return combinedResult }

        let thinResult = await thinSelectedBinaries(thinItems)
        return combinedResult.merging(thinResult)
    }

    private static func thinSelectedBinaries(
        _ items: [FileItem]
    ) async -> CleaningEngine.CleanResult {
        guard !items.isEmpty else {
            return CleaningEngine.CleanResult(
                removedCount: 0, freedBytes: 0, removedURLs: [],
                errors: [], skippedCount: 0
            )
        }
        let op = ThinAppBundleOperation()
        let targetArch = BundleHostInfo.current.hostArch
        var bundleCount = 0
        var savedBytes: UInt64 = 0
        var removedURLs = Set<URL>()
        var errors: [CleaningEngine.CleanError] = []
        for item in items {
            if Task.isCancelled { break }

            do {
                let r = try await op.thin(bundle: item.url, to: targetArch)
                if r.binariesThinned > 0 {
                    bundleCount += 1
                }
                savedBytes += r.bytesSaved
                removedURLs.insert(item.url)
                for (path, msg) in r.perBinaryErrors {
                    errors.append(CleaningEngine.CleanError(
                        path: path, error: "binary thin failed: \(msg)"
                    ))
                }
            } catch {
                errors.append(CleaningEngine.CleanError(
                    path: item.url.path(percentEncoded: false),
                    error: "bundle thin failed: \(error.localizedDescription)"
                ))
            }
        }
        return CleaningEngine.CleanResult(
            removedCount: bundleCount,
            freedBytes: savedBytes,
            removedURLs: removedURLs,
            errors: errors,
            skippedCount: 0
        )
    }

    @discardableResult
    public static func executeUserClean(
        items: [FileItem],
        selectedItems: Set<URL>,
        engine: CleaningEngine,
        onProgress: (@Sendable (CleaningEngine.Progress) -> Void)? = nil
    ) async -> CleaningEngine.CleanResult {
        let filtered = items.filter { selectedItems.contains($0.url) }
        let deduped = Self.prunedToParents(filtered)
        let result = await engine.clean(items: deduped, mode: .trash,
                                  onProgress: onProgress)
        CleanHistoryRecorder.record(trashedItems: result.trashedItems)
        return result
    }

    static func prunedToParents(_ items: [FileItem]) -> [FileItem] {
        guard items.count > 1 else { return items }
        let sorted = items.sorted {
            $0.url.path(percentEncoded: false).count < $1.url.path(percentEncoded: false).count
        }
        var keptPaths: Set<String> = []
        keptPaths.reserveCapacity(sorted.count)
        var kept: [FileItem] = []
        kept.reserveCapacity(sorted.count)
        for item in sorted {
            let path: String = item.url.standardizedFileURL.path(percentEncoded: false)
            guard !keptPaths.contains(path) else { continue }
            var parent: URL = item.url.standardizedFileURL.deletingLastPathComponent()
            var hasAncestor: Bool = false
            while true {
                let parentPath: String = parent.path(percentEncoded: false)
                if keptPaths.contains(parentPath) {
                    hasAncestor = true
                    break
                }
                let next: URL = parent.deletingLastPathComponent()
                if next == parent { break }
                parent = next
            }
            if !hasAncestor {
                kept.append(item)
                keptPaths.insert(path)
            }
        }
        return kept
    }
}
