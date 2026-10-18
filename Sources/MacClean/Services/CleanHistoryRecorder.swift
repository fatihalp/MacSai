import Foundation
import MacCleanKit

public enum CleanHistoryRecorder {

    nonisolated(unsafe) public static var fileURL: URL = NSClassFromString("XCTestCase") != nil
        ? FileManager.default.temporaryDirectory
            .appending(path: "macsai-test-clean-history-\(ProcessInfo.processInfo.processIdentifier).json")
        : MCConstants.cleanHistoryFile

    nonisolated(unsafe) public static var trashRoot: URL = MCConstants.userTrash

    private static let lock = NSLock()

    public static func load() -> [CleanHistorySession] {
        lock.withLock { unlockedLoad() }
    }

    private static func unlockedLoad(now: Date = Date()) -> [CleanHistorySession] {
        guard let data = try? Data(contentsOf: fileURL),
              let sessions = try? CleanHistoryStore.decode(data)
        else { return [] }
        return CleanHistoryStore.pruned(sessions, now: now)
    }

    public static func record(
        trashedItems: [CleaningEngine.TrashedItem],
        now: Date = Date()
    ) {
        guard !trashedItems.isEmpty else { return }
        let kept = trashedItems.prefix(CleanHistoryStore.maxItemsPerSession)
        let omitted = trashedItems.count - kept.count
        let session = CleanHistorySession(
            id: UUID(),
            date: now,
            items: kept.map {
                let trashPath = $0.trashURL.path(percentEncoded: false)
                return CleanHistoryItem(
                    id: UUID(),
                    originalPath: $0.originalURL.path(percentEncoded: false),
                    trashPath: trashPath,
                    bytes: $0.bytes,
                    trashFileID: fileID(atPath: trashPath)
                )
            },
            omittedCount: omitted > 0 ? omitted : nil
        )
        lock.withLock {
            unlockedSave(CleanHistoryStore.adding(session, to: unlockedLoad(now: now), now: now))
        }
    }

    public static func save(_ sessions: [CleanHistorySession]) {
        lock.withLock { unlockedSave(sessions) }
    }

    public static func clear() {
        lock.withLock { try? FileManager.default.removeItem(at: fileURL) }
    }

    private static func unlockedSave(_ sessions: [CleanHistorySession]) {
        let url = fileURL
        let dir = url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        guard let data = try? CleanHistoryStore.encode(sessions) else { return }
        let tmp = dir.appending(path: ".\(url.lastPathComponent).\(UUID().uuidString).tmp")
            .path(percentEncoded: false)
        let fd = open(tmp, O_WRONLY | O_CREAT | O_EXCL, 0o600)
        guard fd >= 0 else { return }
        let written = data.withUnsafeBytes { write(fd, $0.baseAddress, $0.count) }
        close(fd)
        if written != data.count || rename(tmp, url.path(percentEncoded: false)) != 0 {
            unlink(tmp)
        }
    }

    @discardableResult
    public static func restore(_ session: CleanHistorySession) -> CleanHistoryRestoreSummary {
        let fm = FileManager.default
        let root = trashRoot.path(percentEncoded: false)
        let uid = getuid()
        var summary = CleanHistoryRestoreSummary()

        for item in session.items {
            let recordedID = item.trashFileID
            let isSafe = CleanHistoryRestore.isInsideTrash(item.trashPath, trashRoot: root, uid: uid)
                && CleanHistoryRestore.isRestorableDestination(item.originalPath, trashRoot: root, uid: uid)
                && recordedID != nil && fileID(atPath: item.trashPath) == recordedID
                && (try? SafetyGuard().validatePath(URL(filePath: item.originalPath), excludedFolders: [])) != nil
            let action = CleanHistoryRestore.plan(
                item: item,
                trashExists: fileID(atPath: item.trashPath) != nil,
                originalExists: fileID(atPath: item.originalPath) != nil,
                isSafe: isSafe
            )
            switch action {
            case .skippedEmptied:
                summary.emptied += 1
            case .skippedReappeared:
                summary.reappeared += 1
            case .skippedUnsafe:
                summary.failed += 1
            case .restore(let from, let to):
                let destination = URL(filePath: to)
                do {
                    try fm.createDirectory(
                        at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
                    try fm.moveItem(at: URL(filePath: from), to: destination)
                    summary.restored += 1
                    summary.restoredItemIDs.insert(item.id)
                } catch {
                    summary.failed += 1
                }
            }
        }

        if !summary.restoredItemIDs.isEmpty {
            lock.withLock {
                unlockedSave(CleanHistoryStore.removing(itemIDs: summary.restoredItemIDs, from: unlockedLoad()))
            }
        }
        return summary
    }

    static func fileID(atPath path: String) -> UInt64? {
        var info = stat()
        guard lstat(path, &info) == 0 else { return nil }
        return UInt64(info.st_ino)
    }
}
