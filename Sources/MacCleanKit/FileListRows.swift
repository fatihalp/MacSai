import Foundation

public enum FileListRow: Equatable, Sendable {
    case header(FileListHeader)
    case item(FileItem, isSelected: Bool, appRunning: Bool)
}

public enum SelectionState: Sendable, Equatable {
    case none, mixed, all
}

public struct FileListHeader: Equatable, Sendable {
    public let category: ScanCategory
    public let totalSize: UInt64
    public let fileCount: Int
    public let selectedSize: UInt64
    public let selectedCount: Int
    public let isExpanded: Bool

    public init(
        category: ScanCategory,
        totalSize: UInt64,
        fileCount: Int,
        selectedSize: UInt64,
        selectedCount: Int,
        isExpanded: Bool
    ) {
        self.category = category
        self.totalSize = totalSize
        self.fileCount = fileCount
        self.selectedSize = selectedSize
        self.selectedCount = selectedCount
        self.isExpanded = isExpanded
    }

    public var selection: SelectionState {
        if selectedCount <= 0 { return .none }
        if selectedCount >= fileCount { return .all }
        return .mixed
    }
}

public enum FileListRows {

    public static func flatten(
        results: [ScanResult],
        isExpanded: (ScanCategory) -> Bool,
        selectedItems: Set<URL>,
        appRunningURLs: Set<URL> = []
    ) -> [FileListRow] {
        var rows: [FileListRow] = []
        rows.reserveCapacity(results.reduce(results.count) { $0 + $1.items.count })

        for result in results {
            var selectedCount = 0
            var selectedSize: UInt64 = 0
            for item in result.items where selectedItems.contains(item.url) {
                selectedCount += 1
                selectedSize += item.size
            }

            let expanded = isExpanded(result.category)
            rows.append(.header(FileListHeader(
                category: result.category,
                totalSize: result.totalSize,
                fileCount: result.fileCount,
                selectedSize: selectedSize,
                selectedCount: selectedCount,
                isExpanded: expanded
            )))

            if expanded {
                for item in result.items {
                    rows.append(.item(
                        item,
                        isSelected: selectedItems.contains(item.url),
                        appRunning: appRunningURLs.contains(item.url)
                    ))
                }
            }
        }
        return rows
    }
}
