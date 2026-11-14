import AppKit
import Foundation
import MacCleanKit
import OSLog

public actor CleaningEngine {
    public enum CleanMode: Sendable {
        case trash
        case permanent
        case dryRun
    }

    public struct TrashedItem: Sendable, Equatable {
        public let originalURL: URL
        public let trashURL: URL
        public let bytes: UInt64

        public init(originalURL: URL, trashURL: URL, bytes: UInt64) {
            self.originalURL = originalURL
            self.trashURL = trashURL
            self.bytes = bytes
        }
    }

    public struct CleanResult: Sendable {
        public let removedCount: Int
        public let freedBytes: UInt64
        public let removedURLs: Set<URL>
        public let errors: [CleanError]
        public let skippedCount: Int

        public let trashedItems: [TrashedItem]

        public init(
            removedCount: Int,
            freedBytes: UInt64,
            removedURLs: Set<URL>,
            errors: [CleanError],
            skippedCount: Int,
            trashedItems: [TrashedItem] = []
        ) {
            self.removedCount = removedCount
            self.freedBytes = freedBytes
            self.removedURLs = removedURLs
            self.errors = errors
            self.skippedCount = skippedCount
            self.trashedItems = trashedItems
        }
    }

    public struct CleanError: Sendable {
        public let path: String
        public let error: String
    }

    public struct Progress: Sendable, Equatable {
        public let totalItems: Int
        public let processedItems: Int
        public let removedSoFar: Int
        public let freedBytesSoFar: UInt64

        public var fraction: Double {
            totalItems > 0 ? Double(processedItems) / Double(totalItems) : 0
        }
    }

    private let safetyGuard = SafetyGuard()
    private let logger = Logger(subsystem: MCConstants.bundleIdentifier, category: "CleaningEngine")

    public init() {}

    public func clean(
        items: [FileItem],
        mode: CleanMode = .trash,
        onProgress: (@Sendable (Progress) -> Void)? = nil
    ) async -> CleanResult {

        if items.count > MCConstants.maxTotalItemsPerCleanOperation {
            let msg = "Operation exceeds limit of \(MCConstants.maxTotalItemsPerCleanOperation) items (attempted: \(items.count)). This usually indicates a scanner bug."
            logger.error("\(msg, privacy: .public)")
            return CleanResult(
                removedCount: 0,
                freedBytes: 0,
                removedURLs: [],
                errors: [CleanError(path: "validation", error: msg)],
                skippedCount: items.count
            )
        }

        let runningBundleIDs = Set(await MainActor.run {
            NSWorkspace.shared.runningApplications.compactMap { $0.bundleIdentifier?.lowercased() }
        })

        var removedCount = 0
        var freedBytes: UInt64 = 0
        var removedURLs = Set<URL>()
        var errors: [CleanError] = []
        var skippedCount = 0
        var trashedItems: [TrashedItem] = []

        let chunkSize = min(50, MCConstants.cleanChunkSize)
        var startIndex = 0
        var processedSoFar = 0
        while startIndex < items.count {
            if Task.isCancelled { break }
            let endIndex = min(startIndex + chunkSize, items.count)
            let chunk = Array(items[startIndex..<endIndex])
            startIndex = endIndex

            processChunk(
                chunk, mode: mode,
                runningBundleIDs: runningBundleIDs,
                removedCount: &removedCount,
                freedBytes: &freedBytes,
                removedURLs: &removedURLs,
                errors: &errors,
                skippedCount: &skippedCount,
                trashedItems: &trashedItems
            )
            processedSoFar += chunk.count

            onProgress?(Progress(
                totalItems: items.count,
                processedItems: processedSoFar,
                removedSoFar: removedCount,
                freedBytesSoFar: freedBytes
            ))

            await Task.yield()
        }

        logger.info("Cleaning complete: \(removedCount) removed, \(freedBytes) bytes freed, \(errors.count) errors")

        return CleanResult(
            removedCount: removedCount,
            freedBytes: freedBytes,
            removedURLs: removedURLs,
            errors: errors,
            skippedCount: skippedCount,
            trashedItems: trashedItems
        )
    }

    private func processChunk(
        _ chunk: [FileItem],
        mode: CleanMode,
        runningBundleIDs: Set<String>,
        removedCount: inout Int,
        freedBytes: inout UInt64,
        removedURLs: inout Set<URL>,
        errors: inout [CleanError],
        skippedCount: inout Int,
        trashedItems: inout [TrashedItem]
    ) {
        let urls = chunk.map(\.url)
        do {
            try safetyGuard.validateDeletion(paths: urls)
        } catch SafetyGuard.SafetyError.tooManyFiles {

            logger.error("Chunk exceeds the \(MCConstants.maxFilesPerOperation)-file safety cap")
            errors.append(CleanError(
                path: "validation",
                error: SafetyGuard.SafetyError.tooManyFiles(chunk.count).localizedDescription
            ))
            skippedCount += chunk.count
            return
        } catch {

            logger.notice("Chunk has an unsafe path; validating per-item instead of skipping all")
        }

        for item in chunk {
            if Task.isCancelled { break }

            do {
                try safetyGuard.validatePath(item.url)
            } catch {
                skippedCount += 1
                errors.append(CleanError(
                    path: item.url.path(percentEncoded: false),
                    error: error.localizedDescription
                ))
                continue
            }

            if AppCacheOwnership.isOwnedByRunningApp(item.url, runningBundleIDs: runningBundleIDs) {
                skippedCount += 1
                logSkip(path: item.url, reason: "owned by a running app")
                continue
            }

            let realSize: UInt64 = item.size > 0
                ? item.size
                : (item.isDirectory ? Self.recursiveAllocatedSize(of: item.url) : item.size)

            switch mode {
            case .dryRun:
                removedCount += 1
                freedBytes += realSize
                removedURLs.insert(item.url)
                logOperation(path: item.url, size: realSize, dryRun: true)

            case .trash where Self.isInsideTrash(item.url):
                do {
                    try FileManager.default.removeItem(at: item.url)
                    removedCount += 1
                    freedBytes += realSize
                    removedURLs.insert(item.url)
                    logOperation(path: item.url, size: realSize, dryRun: false)
                } catch let nsError as NSError where Self.isBenignMissingFile(nsError) {
                    skippedCount += 1
                    logSkip(path: item.url, reason: "already gone")
                } catch {
                    let msg = error.localizedDescription
                    errors.append(CleanError(
                        path: item.url.path(percentEncoded: false), error: msg
                    ))
                    logError(path: item.url, reason: msg)
                }

            case .trash:
                do {
                    var resulting: NSURL?
                    try FileManager.default.trashItem(at: item.url, resultingItemURL: &resulting)
                    removedCount += 1
                    freedBytes += realSize
                    removedURLs.insert(item.url)
                    if let trashURL = resulting as URL? {
                        trashedItems.append(
                            TrashedItem(originalURL: item.url, trashURL: trashURL, bytes: realSize)
                        )
                    }
                    logOperation(path: item.url, size: realSize, dryRun: false)
                } catch let nsError as NSError where Self.isBenignMissingFile(nsError) {

                    skippedCount += 1
                    logSkip(path: item.url, reason: "already gone")
                } catch {
                    let msg = error.localizedDescription
                    errors.append(CleanError(
                        path: item.url.path(percentEncoded: false), error: msg
                    ))
                    logError(path: item.url, reason: msg)
                }

            case .permanent:
                do {
                    try FileManager.default.removeItem(at: item.url)
                    removedCount += 1
                    freedBytes += realSize
                    removedURLs.insert(item.url)
                    logOperation(path: item.url, size: realSize, dryRun: false)
                } catch let nsError as NSError where Self.isBenignMissingFile(nsError) {
                    skippedCount += 1
                    logSkip(path: item.url, reason: "already gone")
                } catch {
                    let msg = error.localizedDescription
                    errors.append(CleanError(
                        path: item.url.path(percentEncoded: false), error: msg
                    ))
                    logError(path: item.url, reason: msg)
                }
            }
        }
    }

    private static func recursiveAllocatedSize(of url: URL) -> UInt64 {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: url,
            includingPropertiesForKeys: [.totalFileAllocatedSizeKey, .isRegularFileKey, .linkCountKey],
            options: []
        ) else { return 0 }

        var total: UInt64 = 0
        var hardLinks = HardLinkTracker()
        for case let fileURL as URL in enumerator {
            let values = try? fileURL.resourceValues(forKeys: [
                .totalFileAllocatedSizeKey, .isRegularFileKey, .linkCountKey,
            ])
            if values?.isRegularFile == true,
               hardLinks.shouldCount(fileURL, linkCount: values?.linkCount) {
                total += UInt64(values?.totalFileAllocatedSize ?? 0)
            }
        }
        return total
    }

    private static func isInsideTrash(_ url: URL) -> Bool {
        let path = url.path(percentEncoded: false)
        return path.contains("/.Trash/") || path.contains("/.Trashes/")
    }

    private static func isBenignMissingFile(_ error: NSError) -> Bool {
        if error.domain == NSCocoaErrorDomain &&
           (error.code == NSFileNoSuchFileError ||
            error.code == NSFileReadNoSuchFileError) {
            return true
        }
        if error.domain == NSPOSIXErrorDomain && error.code == Int(ENOENT) {
            return true
        }
        return false
    }

    private nonisolated func logOperation(path: URL, size: UInt64, dryRun: Bool) {
        let sizeStr = FileSizeFormatter.format(size)
        let prefix = dryRun ? "[DRY-RUN]" : "[REMOVED]"
        appendLogLine("\(prefix) \(path.path(percentEncoded: false)) (\(sizeStr))")
    }

    private nonisolated func logError(path: URL, reason: String) {
        appendLogLine("[ERROR] \(path.path(percentEncoded: false)) — \(reason)")
    }

    private nonisolated func logSkip(path: URL, reason: String) {
        appendLogLine("[SKIP] \(path.path(percentEncoded: false)) — \(reason)")
    }

    private nonisolated func appendLogLine(_ body: String) {
        let fm = FileManager.default
        let logDir = MCConstants.operationLogDir
        let logFile = MCConstants.operationLogFile

        if !fm.fileExists(atPath: logDir.path(percentEncoded: false)) {
            try? fm.createDirectory(at: logDir, withIntermediateDirectories: true)
        }

        let timestamp = ISO8601DateFormatter().string(from: Date())
        let line = "\(timestamp) \(body)\n"

        guard let data = line.data(using: .utf8) else { return }
        if fm.fileExists(atPath: logFile.path(percentEncoded: false)) {
            if let handle = try? FileHandle(forWritingTo: logFile) {
                handle.seekToEndOfFile()
                handle.write(data)
                handle.closeFile()
            }
        } else {
            try? data.write(to: logFile)
        }
    }
}

public extension CleaningEngine.CleanResult {
    func summary(selectedCount: Int) -> CleanSummary {
        CleanSummary(
            selectedCount: selectedCount,
            removedCount: removedCount,
            freedBytes: freedBytes,
            errorMessages: errors.map(\.error)
        )
    }

    func merging(_ other: Self) -> Self {
        Self(
            removedCount: removedCount + other.removedCount,
            freedBytes: freedBytes + other.freedBytes,
            removedURLs: removedURLs.union(other.removedURLs),
            errors: errors + other.errors,
            skippedCount: skippedCount + other.skippedCount,
            trashedItems: trashedItems + other.trashedItems
        )
    }
}
