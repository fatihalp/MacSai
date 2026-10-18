import Foundation

public enum FileListSort: String, CaseIterable, Sendable {
    case sizeDescending
    case sizeAscending
    case name

    public static let `default`: FileListSort = .sizeDescending

    public var label: String {
        switch self {
        case .sizeDescending: String(localized: "Largest first")
        case .sizeAscending: String(localized: "Smallest first")
        case .name: String(localized: "Name")
        }
    }

    public func sorted(_ items: [FileItem]) -> [FileItem] {
        switch self {
        case .sizeDescending:
            items.sorted { a, b in
                a.size != b.size ? a.size > b.size : Self.tieBreak(a, b)
            }
        case .sizeAscending:
            items.sorted { a, b in
                a.size != b.size ? a.size < b.size : Self.tieBreak(a, b)
            }
        case .name:
            items.sorted(by: Self.tieBreak)
        }
    }

    public func sorted(_ results: [ScanResult]) -> [ScanResult] {
        results.map { result in
            ScanResult(
                category: result.category,
                items: sorted(result.items),
                autoSelect: result.autoSelect
            )
        }
    }

    private static func tieBreak(_ a: FileItem, _ b: FileItem) -> Bool {
        switch a.name.localizedCaseInsensitiveCompare(b.name) {
        case .orderedAscending: true
        case .orderedDescending: false
        case .orderedSame:
            a.url.path(percentEncoded: false) < b.url.path(percentEncoded: false)
        }
    }
}
