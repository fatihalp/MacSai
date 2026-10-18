import Foundation

public enum DuplicateDetection {

    private struct FileIdentity: Hashable {
        let deviceID: Int32
        let inode: UInt64
    }

    public static let maxHashableFileSize: UInt64 = 500 * 1024 * 1024

    public static func sizeGroups(_ files: [FileItem]) -> [[FileItem]] {
        let hashable = files.filter { $0.size <= maxHashableFileSize }
        let grouped = Dictionary(grouping: hashable) { $0.size }
        return grouped.values.filter { $0.count > 1 }
    }

    public static func partialGroups(
        _ pairs: [(key: String, item: FileItem)]
    ) -> [[FileItem]] {
        let grouped = Dictionary(grouping: pairs, by: \.key)
            .mapValues { $0.map(\.item) }
        return grouped.values.filter { $0.count > 1 }
    }

    public static func fullGroupsAndDedupHardLinks(
        _ pairs: [(key: String, item: FileItem)]
    ) -> [[FileItem]] {
        let grouped = Dictionary(grouping: pairs, by: \.key)
            .mapValues { $0.map(\.item) }
        return grouped.values
            .filter { $0.count > 1 }
            .map(dedupHardLinks)
            .filter { $0.count > 1 }
    }

    public static func dedupHardLinks(_ group: [FileItem]) -> [FileItem] {
        var seen: Set<FileIdentity> = []
        return group.filter { item in
            if item.inode == 0 { return true }
            return seen.insert(FileIdentity(deviceID: item.deviceID, inode: item.inode)).inserted
        }
    }

    public static func extractDeletableDuplicates(_ groups: [[FileItem]]) -> [FileItem] {
        groups.flatMap { group -> [FileItem] in
            guard group.count > 1 else { return [] }
            let original = chooseOriginal(group)
            return group.filter { $0.url != original.url }
        }
    }

    private static let backupMarkers: [String] = [
        "backup", "/.trash/", " copy", "(copy", " 2.", " (1)", " (2)", " (3)",
    ]

    public static func isLikelyBackupCopy(_ url: URL) -> Bool {
        let path = url.path(percentEncoded: false).lowercased()
        return backupMarkers.contains { path.contains($0) }
    }

    public static func chooseOriginal(_ group: [FileItem]) -> FileItem {
        group.min(by: isMoreOriginal) ?? group[0]
    }

    private static func isMoreOriginal(_ a: FileItem, _ b: FileItem) -> Bool {
        let aBackup = isLikelyBackupCopy(a.url)
        let bBackup = isLikelyBackupCopy(b.url)
        if aBackup != bBackup { return !aBackup }

        let aDepth = pathDepth(a.url)
        let bDepth = pathDepth(b.url)
        if aDepth != bDepth { return aDepth < bDepth }

        let aDate = a.creationDate ?? a.modificationDate ?? .distantFuture
        let bDate = b.creationDate ?? b.modificationDate ?? .distantFuture
        if aDate != bDate { return aDate < bDate }

        return a.url.path(percentEncoded: false) < b.url.path(percentEncoded: false)
    }

    private static func pathDepth(_ url: URL) -> Int {
        url.path(percentEncoded: false).split(separator: "/").count
    }

    public static func displayGroups(_ groups: [[FileItem]]) -> [DuplicateDisplayGroup] {
        groups.compactMap { group -> DuplicateDisplayGroup? in
            guard group.count > 1 else { return nil }
            let original = chooseOriginal(group)
            let duplicates = group.filter { $0.url != original.url }
            guard !duplicates.isEmpty else { return nil }
            return DuplicateDisplayGroup(original: original, duplicates: duplicates)
        }
        .sorted { $0.wastedSpace > $1.wastedSpace }
    }
}

public struct DuplicateDisplayGroup: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let original: FileItem
    public let duplicates: [FileItem]

    public init(id: UUID = UUID(), original: FileItem, duplicates: [FileItem]) {
        self.id = id
        self.original = original
        self.duplicates = duplicates
    }

    public var allFiles: [FileItem] { [original] + duplicates }

    public var copyCount: Int { duplicates.count + 1 }

    public var wastedSpace: UInt64 { original.size * UInt64(duplicates.count) }

    public var formattedWastedSpace: String {
        ByteCountFormatter.string(fromByteCount: Int64(wastedSpace), countStyle: .file)
    }
}
