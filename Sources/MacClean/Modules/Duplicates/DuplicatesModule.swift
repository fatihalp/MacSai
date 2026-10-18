import Foundation
import CryptoKit
import MacCleanKit

public struct DuplicatesModule: ScanModule {
    public let id = "duplicates"
    public var name: String { String(localized: "Duplicates") }
    public let category = ModuleCategory.files
    public let includedInSmartScan = false

    private let scanner = TargetedScanner()

    public init() {}

    private var scanTargets: [ScanTarget] {
        [
            ScanTarget(
                path: MCConstants.home,
                recursive: true,
                maxDepth: 5,
                minSize: 1024,
                excludePatterns: ["Library", "node_modules"],
                skipHiddenDirectories: true
            ),
        ]
    }

    public func scan() async -> [ScanResult] {
        let items = await scanner.scan(targets: scanTargets)
        let files = items.filter { !$0.isDirectory }
        let duplicateGroups = await findDuplicates(files)
        let duplicates = DuplicateDetection.extractDeletableDuplicates(duplicateGroups)

        guard !duplicates.isEmpty else { return [] }
        return [ScanResult(category: .duplicates, items: duplicates, autoSelect: false)]
            .filteringUncleanable()
    }

    public func scanDisplayGroups() async -> [DuplicateDisplayGroup] {
        let items = await scanner.scan(targets: scanTargets)
        let files = items.filter { !$0.isDirectory }
        let duplicateGroups = await findDuplicates(files)
        let cleanableGroups = duplicateGroups.map { group in
            group.filter { CleanFilter.isActionable($0.url) }
        }
        return DuplicateDetection.displayGroups(cleanableGroups)
    }

    public func findDuplicates(_ files: [FileItem]) async -> [[FileItem]] {

        let candidates = DuplicateDetection.sizeGroups(files)

        let partialResults = await withTaskGroup(of: (key: String, item: FileItem)?.self) {
            group -> [(key: String, item: FileItem)] in
            for sizeGroup in candidates {
                for item in sizeGroup {
                    group.addTask {
                        guard let hash = Self.partialHash(item.url) else { return nil }
                        return (key: "\(item.size)-\(hash)", item: item)
                    }
                }
            }
            var out: [(key: String, item: FileItem)] = []
            for await r in group { if let r { out.append(r) } }
            return out
        }
        let partialCandidates = DuplicateDetection.partialGroups(partialResults)

        let fullResults = await withTaskGroup(of: (key: String, item: FileItem)?.self) {
            group -> [(key: String, item: FileItem)] in
            for partialGroup in partialCandidates {
                for item in partialGroup {
                    group.addTask {
                        guard let hash = Self.fullHash(item.url) else { return nil }
                        return (key: hash, item: item)
                    }
                }
            }
            var out: [(key: String, item: FileItem)] = []
            for await r in group { if let r { out.append(r) } }
            return out
        }

        return DuplicateDetection.fullGroupsAndDedupHardLinks(fullResults)
    }

    static func partialHash(_ url: URL, bytes: Int = 4096) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        let data = handle.readData(ofLength: bytes)
        guard !data.isEmpty else { return nil }
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    static func fullHash(_ url: URL) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        var hasher = SHA256()
        while true {
            let chunk = handle.readData(ofLength: 65536)
            if chunk.isEmpty { break }
            hasher.update(data: chunk)
        }
        let digest = hasher.finalize()
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
