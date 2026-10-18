import Foundation
import MacCleanKit

public struct LargeOldFilesModule: ScanModule {
    public let id = "large_old_files"
    public var name: String { String(localized: "Large & Old Files") }
    public let category = ModuleCategory.files

    public let includedInSmartScan = false

    private let scanner = TargetedScanner()
    private let minSize: UInt64
    private let minAge: TimeInterval?

    public init(minSize: UInt64 = 50 * 1024 * 1024, minAge: TimeInterval? = nil) {
        self.minSize = minSize
        self.minAge = minAge
    }

    public func scan() async -> [ScanResult] {
        let targets = [
            ScanTarget(
                path: MCConstants.home,
                recursive: true,
                maxDepth: 5,
                minAge: minAge,
                minSize: minSize,
                excludePatterns: ["Library", ".Trash", ".git", "node_modules"]
            ),
            ScanTarget(
                path: MCConstants.downloads,
                recursive: true,
                minAge: minAge,
                minSize: minSize
            ),
        ]

        let items = await scanner.scan(targets: targets)
        let split = Self.splitLargeAndOld(items: items, minSize: minSize)

        return Self.makeResults(large: split.large, old: split.old).filteringUncleanable()
    }

    internal static func makeResults(large: [FileItem], old: [FileItem]) -> [ScanResult] {
        var results: [ScanResult] = []
        if !large.isEmpty {
            results.append(ScanResult(category: .largeFiles, items: large, autoSelect: false))
        }
        if !old.isEmpty {
            results.append(ScanResult(category: .oldFiles, items: old, autoSelect: false))
        }
        return results
    }

    public static func splitLargeAndOld(
        items: [FileItem],
        minSize: UInt64,
        oldThreshold: TimeInterval = 180 * 24 * 3600,
        now: Date = Date()
    ) -> (large: [FileItem], old: [FileItem]) {
        var large: [FileItem] = []
        var old: [FileItem] = []
        let cutoff = now.addingTimeInterval(-oldThreshold)

        for item in items where !item.isDirectory {
            if item.size >= minSize { large.append(item) }
            if let modDate = item.modificationDate, modDate < cutoff { old.append(item) }
        }
        large.sort { $0.size > $1.size }
        old.sort { ($0.modificationDate ?? .distantFuture) < ($1.modificationDate ?? .distantFuture) }

        return (large, old)
    }
}
