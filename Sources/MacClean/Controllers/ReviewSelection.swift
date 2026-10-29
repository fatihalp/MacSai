import Foundation
import Observation
import MacCleanKit

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
