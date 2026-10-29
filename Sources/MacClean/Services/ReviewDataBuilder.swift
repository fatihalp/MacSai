import Foundation
import AppKit
import MacCleanKit

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
