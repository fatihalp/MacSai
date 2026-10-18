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

enum ReviewDataBuilder {

    static let standardSystemJunkCategories: [ScanCategory] = [
        .userCaches,
        .xcodeJunk,
        .universalBinaries,
        .userLogs,
        .systemLogs,
        .languageFiles,
        .documentVersions,
        .brokenLoginItems,
        .systemCaches,
        .iosDeviceBackups,
        .deletedUsers,
        .brokenPreferences,
    ]

    private static let mergedUserCacheCategories: Set<ScanCategory> = [
        .packageManagerCaches,
        .ideCaches,
        .aiToolCaches,
    ]

    private static let coreCleanupModuleIDs: Set<String> = [
        "system_junk",
        "mail_attachments",
        "trash_bins",
    ]

    static func build(
        modules: [ModuleScanResult],
        runningBundleIDs: Set<String>,
        includeEmptySystemJunkCategories: Bool = false
    ) -> ReviewData {
        var items: [ReviewItem] = []
        items.reserveCapacity(modules.reduce(0) { $0 + $1.totalFileCount })
        var categories: [ReviewCategory] = []
        var sections: [ReviewSection] = []
        var appLookup: [String: URL?] = [:]
        let isMultiModule = modules.count > 1

        for module in modules {
            var categoryIDs: [Int] = []
            var sectionSize: UInt64 = 0
            var sectionCount = 0

            let nonEmptyResults = module.categories.filter { !$0.items.isEmpty }
            let hasUserCaches = nonEmptyResults.contains { $0.category == .userCaches }

            struct PreparedCategory {
                let category: ScanCategory
                let autoSelect: Bool
                let bucketInputs: [(bucket: ReviewGrouping.Bucket, autoSelect: Bool)]
                let totalSize: UInt64
            }

            var prepared: [PreparedCategory] = []
            if module.moduleID == "system_junk" && hasUserCaches {
                var userCacheBuckets: [(bucket: ReviewGrouping.Bucket, autoSelect: Bool)] = []
                for result in nonEmptyResults where result.category == .userCaches || mergedUserCacheCategories.contains(result.category) {
                    let buckets = ReviewGrouping.buckets(
                        for: result.category,
                        items: result.items.map(ReviewItem.init)
                    )
                    for b in buckets {
                        userCacheBuckets.append((b, result.autoSelect))
                    }
                }
                userCacheBuckets.sort { $0.bucket.size > $1.bucket.size }
                let userCacheSize = userCacheBuckets.reduce(0 as UInt64) { $0 + $1.bucket.size }
                prepared.append(PreparedCategory(
                    category: .userCaches,
                    autoSelect: true,
                    bucketInputs: userCacheBuckets,
                    totalSize: userCacheSize
                ))

                for result in nonEmptyResults where result.category != .userCaches && !mergedUserCacheCategories.contains(result.category) {
                    let buckets = ReviewGrouping.buckets(
                        for: result.category,
                        items: result.items.map(ReviewItem.init)
                    ).sorted { $0.size > $1.size }
                    let size = buckets.reduce(0 as UInt64) { $0 + $1.size }
                    prepared.append(PreparedCategory(
                        category: result.category,
                        autoSelect: result.autoSelect,
                        bucketInputs: buckets.map { ($0, result.autoSelect) },
                        totalSize: size
                    ))
                }
            } else {
                for result in nonEmptyResults {
                    let buckets = ReviewGrouping.buckets(
                        for: result.category,
                        items: result.items.map(ReviewItem.init)
                    ).sorted { $0.size > $1.size }
                    let size = buckets.reduce(0 as UInt64) { $0 + $1.size }
                    prepared.append(PreparedCategory(
                        category: result.category,
                        autoSelect: result.autoSelect,
                        bucketInputs: buckets.map { ($0, result.autoSelect) },
                        totalSize: size
                    ))
                }
            }

            prepared.sort { $0.totalSize > $1.totalSize }

            var seenCategories = Set<ScanCategory>()
            for entry in prepared {
                seenCategories.insert(entry.category)
                let categoryStart = items.count
                var groups: [ReviewNode] = []
                groups.reserveCapacity(entry.bucketInputs.count)
                for (bucket, bucketAutoSelect) in entry.bucketInputs {
                    let sorted = bucket.items.sorted { ReviewPath.precedes($0.path, $1.path) }
                    let start = items.count
                    items.append(contentsOf: sorted)
                    let range = start..<items.count
                    groups.append(makeGroup(
                        bucket, sortedItems: sorted, range: range,
                        autoSelect: bucketAutoSelect,
                        runningBundleIDs: runningBundleIDs, appLookup: &appLookup
                    ))
                }
                let range = categoryStart..<items.count
                let size = groups.reduce(0) { $0 + $1.size }
                let id = categories.count
                categories.append(ReviewCategory(
                    id: id, category: entry.category, autoSelect: entry.autoSelect,
                    range: range, size: size, groups: groups
                ))
                categoryIDs.append(id)
                sectionSize += size
                sectionCount += range.count
            }

            if module.moduleID == "system_junk" && (includeEmptySystemJunkCategories || isMultiModule) && !categoryIDs.isEmpty {
                for stdCategory in standardSystemJunkCategories where !seenCategories.contains(stdCategory) {
                    let id = categories.count
                    let emptyRange = items.count..<items.count
                    categories.append(ReviewCategory(
                        id: id, category: stdCategory, autoSelect: stdCategory.autoSelect,
                        range: emptyRange, size: 0, groups: []
                    ))
                    categoryIDs.append(id)
                }
            }

            if categoryIDs.isEmpty && isMultiModule && coreCleanupModuleIDs.contains(module.moduleID) {
                let fallbackCategory: ScanCategory = switch module.moduleID {
                case "mail_attachments": .mailAttachments
                case "trash_bins": .trashBins
                default: .userCaches
                }
                let id = categories.count
                let emptyRange = items.count..<items.count
                categories.append(ReviewCategory(
                    id: id, category: fallbackCategory, autoSelect: fallbackCategory.autoSelect,
                    range: emptyRange, size: 0, groups: []
                ))
                categoryIDs.append(id)
            }

            guard !categoryIDs.isEmpty else { continue }
            sections.append(ReviewSection(
                id: module.moduleID, name: module.moduleName,
                categoryIDs: categoryIDs, size: sectionSize, itemCount: sectionCount
            ))
        }

        return ReviewData(items: items, categories: categories, sections: sections)
    }

    private static func makeGroup(
        _ bucket: ReviewGrouping.Bucket,
        sortedItems: [ReviewItem],
        range: Range<Int>,
        autoSelect: Bool,
        runningBundleIDs: Set<String>,
        appLookup: inout [String: URL?]
    ) -> ReviewNode {
        var name = bucket.name
        var iconPath = bucket.base
        var owner = AppCacheOwnership.owningBundleID(for: URL(filePath: bucket.base))

        if ReviewGrouping.looksLikeBundleID(bucket.name) {
            let appURL: URL?
            if let cached = appLookup[bucket.name] {
                appURL = cached
            } else {
                appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bucket.name)
                appLookup[bucket.name] = appURL
            }
            if let appURL {
                name = appURL.lastPathComponent
                iconPath = appURL.path(percentEncoded: false)
                owner = bucket.name
            }
        } else if let ownerID = owner {
            let appURL: URL?
            if let cached = appLookup[ownerID] {
                appURL = cached
            } else {
                appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: ownerID)
                appLookup[ownerID] = appURL
            }
            if let appURL, bucket.name.lowercased().contains("brave") {
                name = appURL.lastPathComponent
                iconPath = appURL.path(percentEncoded: false)
            }
        }

        let isLeaf = sortedItems.count == 1 && sortedItems[0].path == bucket.base && !sortedItems[0].isDirectory
        return ReviewNode(
            id: bucket.base + "#\(range.lowerBound)",
            name: name,
            basePath: bucket.base,
            range: range,
            size: bucket.size,
            isLeaf: isLeaf,
            iconPath: iconPath,
            appIsRunning: owner.map { runningBundleIDs.contains($0) } ?? false,
            autoSelect: autoSelect
        )
    }
}

enum ReviewGrouping {
    struct Bucket {
        var name: String
        var base: String
        var items: [ReviewItem] = []
        var size: UInt64 = 0
        var roots: Set<String> = []
    }

    enum Mode {

        case byChild

        case byLogEntry

        case byTool
    }

    static func mode(for category: ScanCategory) -> Mode {
        switch category {
        case .packageManagerCaches, .ideCaches, .aiToolCaches: .byTool
        case .systemLogs, .userLogs: .byLogEntry
        default: .byChild
        }
    }

    static let rootsByCategory: [ScanCategory: [String]] = {
        var map: [ScanCategory: [String]] = [:]
        for junk in SystemJunkModule.allCategories {
            map[junk.scanCategory, default: []] += junk.targets.map { ReviewPath.normalized($0.path) }
        }
        map[.mailAttachments] = [
            MCConstants.mailDownloads,
            MCConstants.mailContainerDownloads,
            MCConstants.mailData,
            MCConstants.userContainers.appending(path: "com.microsoft.Outlook/Data/Library/Caches"),
            MCConstants.userContainers.appending(path: "com.readdle.smartemail/Data/Library/Caches"),
        ].map(ReviewPath.normalized)
        map[.trashBins] = [ReviewPath.normalized(MCConstants.userTrash)]
        return map.mapValues { roots in
            Array(Set(roots)).sorted { $0.utf8.count > $1.utf8.count }
        }
    }()

    static func buckets(for category: ScanCategory, items: [ReviewItem]) -> [Bucket] {
        let roots = rootsByCategory[category] ?? []
        let mode = mode(for: category)
        var byKey: [String: Bucket] = [:]
        var unmatched: [ReviewItem] = []

        for item in items {
            guard let root = roots.first(where: { ReviewPath.isDescendant(item.path, of: $0) }) else {
                unmatched.append(item)
                continue
            }
            switch mode {
            case .byChild:
                let component = ReviewPath.firstComponent(of: item.path, below: root)
                let base = ReviewPath.join(root, component)
                byKey[base, default: Bucket(name: String(component), base: base)].append(item)
            case .byLogEntry:
                let component = String(ReviewPath.firstComponent(of: item.path, below: root))
                let childPath = ReviewPath.join(root, component)

                if item.path == childPath && !item.isDirectory {
                    let stem = logStem(for: component)
                    let key = ReviewPath.join(root, stem)
                    byKey[key, default: Bucket(name: stem, base: item.path)].append(item)
                } else {
                    byKey[childPath, default: Bucket(name: component, base: childPath)].append(item)
                }
            case .byTool:
                let name = toolName(for: root)
                byKey["tool:" + name, default: Bucket(name: name, base: root)].append(item, root: root)
            }
        }

        var result = Array(byKey.values)
        if mode == .byTool {
            for i in result.indices where result[i].roots.count > 1 {
                result[i].base = ReviewPath.commonDirectory(Array(result[i].roots))
            }
        }

        unmatched.sort { ReviewPath.precedes($0.path, $1.path) }
        var current: Bucket?
        for item in unmatched {
            if current != nil, ReviewPath.isDescendant(item.path, of: current!.base) {
                current!.append(item)
            } else {
                if let done = current { result.append(done) }
                var fresh = Bucket(name: ReviewPath.lastComponent(item.path), base: item.path)
                fresh.append(item)
                current = fresh
            }
        }
        if let done = current { result.append(done) }
        return result
    }

    static func logStem(for filename: String) -> String {
        var s = filename
        if let range = s.range(of: ".log", options: .caseInsensitive) {
            s = String(s[..<range.lowerBound])
        } else {
            for ext in [".gz", ".txt", ".crash", ".diag", ".ips", ".out"] where s.lowercased().hasSuffix(ext) {
                s = String(s.dropLast(ext.count))
                break
            }
        }
        return s.isEmpty ? filename : s
    }

    static func toolName(for root: String) -> String {
        let home = ReviewPath.normalized(MCConstants.home)
        let relative = ReviewPath.isDescendant(root, of: home)
            ? String(root.dropFirst(home.count + 1))
            : root
        let generic: Set<String> = ["Library", "Caches", "Application Support", "Containers", "Data"]
        let component = relative.split(separator: "/").first { !generic.contains(String($0)) }
            .map(String.init) ?? ReviewPath.lastComponent(root)
        var name = component.hasPrefix(".") ? String(component.dropFirst()) : component
        if name == name.lowercased(), !["npm", "pip"].contains(name) {
            name = name.prefix(1).uppercased() + name.dropFirst()
        }
        return name
    }

    static func looksLikeBundleID(_ string: String) -> Bool {
        guard string.split(separator: ".").count >= 3 else { return false }
        return string.allSatisfy { $0.isLetter || $0.isNumber || $0 == "." || $0 == "-" || $0 == "_" }
    }
}

private extension ReviewGrouping.Bucket {
    mutating func append(_ item: ReviewItem, root: String? = nil) {
        items.append(item)
        size += item.size
        if let root { roots.insert(root) }
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

@MainActor @Observable
final class ReviewSelection {
    let data: ReviewData
    @ObservationIgnored private var flags: [Bool]
    @ObservationIgnored private var categorySize: [UInt64]
    @ObservationIgnored private var categoryCount: [Int]
    private(set) var revision = 0
    private(set) var selectedCount = 0
    private(set) var selectedSize: UInt64 = 0

    let lockedSummary: (appCount: Int, bytes: UInt64)?

    init(data: ReviewData) {
        self.data = data
        flags = Array(repeating: false, count: data.items.count)
        categorySize = Array(repeating: 0, count: data.categories.count)
        categoryCount = Array(repeating: 0, count: data.categories.count)

        var runningAppNames: Set<String> = []
        var runningBytes: UInt64 = 0
        for category in data.categories {
            for group in category.groups where group.appIsRunning && group.size > 0 {
                runningAppNames.insert(group.name)
                runningBytes += group.size
            }
        }
        if !runningAppNames.isEmpty && runningBytes > 0 {
            self.lockedSummary = (appCount: runningAppNames.count, bytes: runningBytes)
        } else {
            self.lockedSummary = nil
        }

        for category in data.categories {
            for group in category.groups where Self.isSmartPick(group, in: category) {
                write(group.range, to: true, category: category.id)
            }
        }
    }

    static func isSmartPick(_ node: ReviewNode, in category: ReviewCategory) -> Bool {
        category.autoSelect && node.autoSelect && !node.appIsRunning && !node.isSensitive
    }

    func state(of range: Range<Int>) -> ReviewCheckState {
        _ = revision
        var anyOn = false
        var anyOff = false
        for i in range {
            if flags[i] { anyOn = true } else { anyOff = true }
            if anyOn && anyOff { return .mixed }
        }
        return anyOn ? .on : .off
    }

    func selectedSize(ofCategory id: Int) -> UInt64 {
        _ = revision
        return categorySize[id]
    }

    func selectedSize(ofSection section: ReviewSection) -> UInt64 {
        _ = revision
        return section.categoryIDs.reduce(0) { $0 + categorySize[$1] }
    }

    func mode(ofCategory id: Int) -> ReviewSelectMode {
        _ = revision
        let category = data.categories[id]
        guard !category.range.isEmpty else { return .none }
        let isSmart = category.groups.allSatisfy { group in
            state(of: group.range) == (Self.isSmartPick(group, in: category) ? .on : .off)
        }
        let hasExcludedSmartGroup = category.groups.contains { !Self.isSmartPick($0, in: category) }

        if isSmart && hasExcludedSmartGroup { return .smart }
        if categoryCount[id] == category.range.count { return .all }
        if categoryCount[id] == 0 { return .none }
        if isSmart { return .smart }
        return .custom
    }

    func toggle(_ node: ReviewNode, category id: Int) {
        set(node.range, to: state(of: node.range) != .on, category: id)
    }

    func state(ofCategory id: Int) -> ReviewCheckState {
        _ = revision
        let category = data.categories[id]
        guard !category.range.isEmpty else { return .off }
        if categoryCount[id] == 0 { return .off }
        if categoryCount[id] == category.range.count { return .on }
        return .mixed
    }

    func toggleCategory(_ id: Int) {
        let current = state(ofCategory: id)
        apply(current == .on ? .none : .all, toCategory: id)
    }

    func state(ofSection section: ReviewSection) -> ReviewCheckState {
        _ = revision
        let total = section.categoryIDs.reduce(0) { $0 + data.categories[$1].range.count }
        guard total > 0 else { return .off }
        let selected = section.categoryIDs.reduce(0) { $0 + categoryCount[$1] }
        if selected == 0 { return .off }
        if selected == total { return .on }
        return .mixed
    }

    func toggleSection(_ section: ReviewSection) {
        let current = state(ofSection: section)
        apply(current == .on ? .none : .all, toSection: section)
    }

    func set(_ range: Range<Int>, to value: Bool, category id: Int) {
        write(range, to: value, category: id)
        revision &+= 1
    }

    func apply(_ mode: ReviewSelectMode, toCategory id: Int) {
        let category = data.categories[id]
        switch mode {
        case .all: write(category.range, to: true, category: id)
        case .none: write(category.range, to: false, category: id)
        case .smart:
            for group in category.groups {
                write(group.range, to: Self.isSmartPick(group, in: category), category: id)
            }
        case .custom: return
        }
        revision &+= 1
    }

    func apply(_ mode: ReviewSelectMode, toSection section: ReviewSection) {
        for id in section.categoryIDs {
            apply(mode, toCategory: id)
        }
    }

    func applyToAll(_ mode: ReviewSelectMode) {
        for category in data.categories {
            apply(mode, toCategory: category.id)
        }
    }

    func applySelectedURLs(_ urls: Set<URL>) {
        guard !data.items.isEmpty else { return }
        for category in data.categories {
            write(category.range, to: false, category: category.id)
            for i in category.range where urls.contains(data.items[i].url) {
                write(i..<(i + 1), to: true, category: category.id)
            }
        }
        revision &+= 1
    }

    func snapshot() -> [Bool] { flags }

    private func write(_ range: Range<Int>, to value: Bool, category id: Int) {
        let items = data.items
        var added: UInt64 = 0
        var removed: UInt64 = 0
        var addedCount = 0
        var removedCount = 0
        flags.withUnsafeMutableBufferPointer { buffer in
            for i in range where buffer[i] != value {
                buffer[i] = value
                if value {
                    added += items[i].size
                    addedCount += 1
                } else {
                    removed += items[i].size
                    removedCount += 1
                }
            }
        }
        guard addedCount + removedCount > 0 else { return }
        categorySize[id] = categorySize[id] + added - removed
        categoryCount[id] += addedCount - removedCount
        selectedSize = selectedSize + added - removed
        selectedCount += addedCount - removedCount
    }
}
