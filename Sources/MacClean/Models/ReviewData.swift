import Foundation
import AppKit
import MacCleanKit

enum ReviewPath {

    static func precedes(_ a: String, _ b: String) -> Bool {
        var ai = a.utf8.makeIterator()
        var bi = b.utf8.makeIterator()
        while true {
            let x = ai.next()
            let y = bi.next()
            guard let x else { return y != nil }
            guard let y else { return false }
            if x != y {
                return (x == 0x2F ? 0 : x) < (y == 0x2F ? 0 : y)
            }
        }
    }

    static func isDescendant(_ path: String, of base: String) -> Bool {
        let p = path.utf8
        let b = base.utf8
        guard p.count > b.count, p.starts(with: b) else { return false }
        if base == "/" { return true }
        return p[p.index(p.startIndex, offsetBy: b.count)] == 0x2F
    }

    static func isSameOrDescendant(_ path: String, of base: String) -> Bool {
        path == base || isDescendant(path, of: base)
    }

    static func normalized(_ url: URL) -> String {
        var p = url.path(percentEncoded: false)
        while p.count > 1 && p.hasSuffix("/") { p.removeLast() }
        return p
    }

    static func firstComponent(of path: String, below base: String) -> Substring {
        let offset = base == "/" ? 1 : base.utf8.count + 1
        let start = path.utf8.index(path.utf8.startIndex, offsetBy: offset)
        let rest = path[start...]
        if let slash = rest.firstIndex(of: "/") { return rest[..<slash] }
        return rest
    }

    static func join(_ base: String, _ component: some StringProtocol) -> String {
        base == "/" ? "/" + component : base + "/" + component
    }

    static func lastComponent(_ path: String) -> String {
        guard let slash = path.lastIndex(of: "/") else { return path }
        let name = path[path.index(after: slash)...]
        return name.isEmpty ? path : String(name)
    }

    static func commonDirectory(_ paths: [String]) -> String {
        guard var common = paths.first?.split(separator: "/", omittingEmptySubsequences: true) else { return "/" }
        for path in paths.dropFirst() {
            let parts = path.split(separator: "/", omittingEmptySubsequences: true)
            var n = 0
            while n < common.count, n < parts.count, common[n] == parts[n] { n += 1 }
            common = Array(common.prefix(n))
        }
        return "/" + common.joined(separator: "/")
    }
}

struct ReviewItem: Sendable {
    let url: URL
    let path: String
    let size: UInt64
    let isDirectory: Bool

    init(_ item: FileItem) {
        url = item.url
        path = ReviewPath.normalized(item.url)
        size = item.size
        isDirectory = item.isDirectory
    }
}

struct ReviewNode: Identifiable, Hashable, Sendable {
    let id: String
    let name: String

    let basePath: String
    let range: Range<Int>
    let size: UInt64

    let isLeaf: Bool

    let iconPath: String

    let appIsRunning: Bool

    let autoSelect: Bool

    let isSensitive: Bool

    init(
        id: String,
        name: String,
        basePath: String,
        range: Range<Int>,
        size: UInt64,
        isLeaf: Bool,
        iconPath: String,
        appIsRunning: Bool,
        autoSelect: Bool = true,
        isSensitive: Bool? = nil
    ) {
        self.id = id
        self.name = name
        self.basePath = basePath
        self.range = range
        self.size = size
        self.isLeaf = isLeaf
        self.iconPath = iconPath
        self.appIsRunning = appIsRunning
        self.autoSelect = autoSelect
        self.isSensitive = isSensitive ?? SensitiveRemnantMatcher.isSensitive(path: basePath)
    }
}

struct ReviewCategory: Identifiable, Sendable {
    let id: Int
    let category: ScanCategory
    let autoSelect: Bool
    let range: Range<Int>
    let size: UInt64
    let groups: [ReviewNode]
}

struct ReviewSection: Identifiable, Sendable {
    let id: String
    let name: String
    let categoryIDs: [Int]
    let size: UInt64
    let itemCount: Int
}

final class ReviewData: Sendable {
    let items: [ReviewItem]
    let categories: [ReviewCategory]
    let sections: [ReviewSection]
    let totalSize: UInt64

    init(items: [ReviewItem], categories: [ReviewCategory], sections: [ReviewSection]) {
        self.items = items
        self.categories = categories
        self.sections = sections
        self.totalSize = sections.reduce(0) { $0 + $1.size }
    }

    func children(of node: ReviewNode) -> [ReviewNode] {
        let base = node.basePath
        var out: [ReviewNode] = []
        var i = node.range.lowerBound
        let end = node.range.upperBound
        while i < end {
            let item = items[i]
            if item.path == base { i += 1; continue }
            guard ReviewPath.isDescendant(item.path, of: base) else {
                out.append(ReviewNode(
                    id: item.path + "#\(i)", name: ReviewPath.lastComponent(item.path),
                    basePath: item.path, range: i..<(i + 1), size: item.size,
                    isLeaf: true, iconPath: item.path, appIsRunning: node.appIsRunning,
                    autoSelect: node.autoSelect
                ))
                i += 1
                continue
            }
            let component = ReviewPath.firstComponent(of: item.path, below: base)
            let childPath = ReviewPath.join(base, component)
            var j = i + 1
            var size = item.size
            while j < end, ReviewPath.isSameOrDescendant(items[j].path, of: childPath) {
                size += items[j].size
                j += 1
            }
            out.append(ReviewNode(
                id: childPath + "#\(i)", name: String(component), basePath: childPath,
                range: i..<j, size: size, isLeaf: j == i + 1 && item.path == childPath,
                iconPath: childPath, appIsRunning: node.appIsRunning,
                autoSelect: node.autoSelect
            ))
            i = j
        }
        out.sort { $0.size > $1.size }
        return out
    }

    func selectedURLs(flags: [Bool]) -> Set<URL> {
        var unselected: [String] = []
        var selectedCount = 0
        for i in items.indices {
            if flags[i] { selectedCount += 1 } else { unselected.append(items[i].path) }
        }
        unselected.sort(by: ReviewPath.precedes)

        func hasUnselectedDescendant(_ dir: String) -> Bool {
            guard !unselected.isEmpty else { return false }
            let key = dir + "/"
            var lo = 0
            var hi = unselected.count
            while lo < hi {
                let mid = (lo + hi) / 2
                if ReviewPath.precedes(unselected[mid], key) { lo = mid + 1 } else { hi = mid }
            }
            return lo < unselected.count && ReviewPath.isDescendant(unselected[lo], of: dir)
        }

        var urls = Set<URL>(minimumCapacity: selectedCount)
        for i in items.indices where flags[i] {
            let item = items[i]
            if item.isDirectory && hasUnselectedDescendant(item.path) { continue }
            urls.insert(item.url)
        }
        return urls
    }
}

enum ReviewCheckState {
    case off, mixed, on
}

enum ReviewSelectMode {
    case smart, all, none, custom

    var label: String {
        switch self {
        case .smart: String(localized: "Smartly")
        case .all: String(localized: "All")
        case .none: String(localized: "None")
        case .custom: String(localized: "Custom")
        }
    }
}
