import Foundation
import MacCleanKit

enum SmartScanCleanup {

    struct RecentlyCleanedRow: Equatable, Sendable {
        let moduleID: String
        let moduleName: String
        let itemCount: Int
        let size: UInt64
    }

    static func allResults(from modules: [ModuleScanResult]) -> [ScanResult] {
        modules.flatMap(\.categories).filter { !$0.items.isEmpty }
    }

    static func defaultSelection(from modules: [ModuleScanResult]) -> Set<URL> {
        var urls: Set<URL> = []
        for result in allResults(from: modules) where result.autoSelect {
            urls.formUnion(result.items.map(\.url))
        }
        return urls
    }

    static func recentlyCleanedBreakdown(
        from modules: [ModuleScanResult],
        selectedItems: Set<URL>
    ) -> [RecentlyCleanedRow] {
        guard !selectedItems.isEmpty else { return [] }
        return modules.compactMap { module in
            var seen = Set<URL>()
            var count = 0
            var size: UInt64 = 0
            for result in module.categories {
                for item in result.items where selectedItems.contains(item.url) {
                    guard seen.insert(item.url).inserted else { continue }
                    count += 1
                    size += item.size
                }
            }
            guard count > 0 else { return nil }
            return RecentlyCleanedRow(
                moduleID: module.moduleID,
                moduleName: module.moduleName,
                itemCount: count,
                size: size
            )
        }
    }
}
