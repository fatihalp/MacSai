import Foundation
import MacCleanKit

enum DuplicatesActionMode: Equatable {
    case remove
    case consolidate
}

enum DuplicatesConsolidation {
    static func groups(from displayGroups: [DuplicateDisplayGroup],
                       selection: Set<URL>) -> [GroupConsolidation] {
        displayGroups.compactMap { group in
            let copies = group.duplicates
                .map(\.url)
                .filter { selection.contains($0) }
            guard !copies.isEmpty else { return nil }
            return GroupConsolidation(master: group.original.url, copies: copies)
        }
    }

    static func estimatedReclaim(from displayGroups: [DuplicateDisplayGroup],
                                 selection: Set<URL>) -> UInt64 {
        displayGroups.reduce(0) { total, group in
            total + group.duplicates
                .filter { selection.contains($0.url) }
                .reduce(0) { $0 + $1.allocatedSize }
        }
    }
}
