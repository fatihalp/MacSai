import Foundation
import MacCleanKit

struct FileListExpansion {
    private var collapsed: Set<ScanCategory> = []

    func isExpanded(_ c: ScanCategory) -> Bool { !collapsed.contains(c) }

    var signature: String { collapsed.map(\.rawValue).sorted().joined(separator: ",") }

    mutating func toggle(_ c: ScanCategory) {
        if collapsed.contains(c) { collapsed.remove(c) } else { collapsed.insert(c) }
    }

    mutating func collapseAll(_ cats: [ScanCategory]) { collapsed.formUnion(cats) }

    mutating func expandAll() { collapsed.removeAll() }
}
