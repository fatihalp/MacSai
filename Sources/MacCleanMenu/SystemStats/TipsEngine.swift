import Foundation
import AppKit
import MacCleanKit

public actor TipsEngine {
    public struct Tip: Sendable, Identifiable, Equatable {
        public let id: String
        public let title: String
        public let body: String

        public let estimatedSavings: UInt64
        public let symbol: String

        public init(id: String, title: String, body: String, estimatedSavings: UInt64, symbol: String) {
            self.id = id
            self.title = title
            self.body = body
            self.estimatedSavings = estimatedSavings
            self.symbol = symbol
        }
    }

    public init() {}

    public func generateTips() async -> [Tip] {
        async let trash = trashTip()
        async let caches = cachesTip()

        var tips: [Tip] = []
        if let t = await trash { tips.append(t) }
        if let c = await caches { tips.append(c) }

        return tips
            .filter { !SharedAppState.isTipDismissed(id: $0.id) }
            .sorted { $0.estimatedSavings > $1.estimatedSavings }
    }

    private static let trashSizeMinimum: UInt64 = 1 * 1024 * 1024 * 1024
    private static let cachesSizeMinimum: UInt64 = 2 * 1024 * 1024 * 1024

    private func trashTip() async -> Tip? {
        let size = await directorySize(MCConstants.userTrash)
        guard size >= Self.trashSizeMinimum else { return nil }
        return Tip(
            id: "trash_large",
            title: "Trash is taking \(FileSizeFormatter.format(size))",
            body: "Empty the Trash from \(MCConstants.appName) to reclaim space.",
            estimatedSavings: size,
            symbol: "trash"
        )
    }

    private func cachesTip() async -> Tip? {
        let size = await directorySize(MCConstants.userCaches)
        guard size >= Self.cachesSizeMinimum else { return nil }
        return Tip(
            id: "caches_large",
            title: "User caches grew to \(FileSizeFormatter.format(size))",
            body: "Run System Junk in \(MCConstants.appName) to clear regenerable cache files.",
            estimatedSavings: size,
            symbol: "internaldrive"
        )
    }

    private func directorySize(_ url: URL) async -> UInt64 {
        let path = url.path(percentEncoded: false)
        guard FileManager.default.fileExists(atPath: path) else { return 0 }
        let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [.totalFileAllocatedSizeKey, .isDirectoryKey],
            options: [.skipsHiddenFiles],
            errorHandler: nil
        )
        var total: UInt64 = 0
        var sampled = 0
        let cap = 50_000
        while let next = enumerator?.nextObject() as? URL {
            sampled += 1
            if sampled > cap { break }
            if let values = try? next.resourceValues(forKeys: [.totalFileAllocatedSizeKey, .isDirectoryKey]),
               values.isDirectory == false,
               let size = values.totalFileAllocatedSize {
                total += UInt64(size)
            }

            if sampled % 5_000 == 0 { await Task.yield() }
        }
        return total
    }
}

public enum TipAction {
    @MainActor
    public static func open() {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: MCConstants.bundleIdentifier) {
            NSWorkspace.shared.openApplication(at: url, configuration: .init())
        }
    }
}

public extension TipAction {

    @MainActor
    static func open(moduleID: String?) {
        guard let moduleID, let url = URL(string: "macclean://module/\(moduleID)") else {
            open()
            return
        }
        NSWorkspace.shared.open(url)
    }
}
