import SwiftUI
import AppKit
import MacCleanKit

func fileListResultsSignature(sort: FileListSort, results: [ScanResult]) -> String {
    sort.rawValue + "#" + results.map {
        let generation = $0.items.first?.id.uuidString ?? "empty"
        return "\($0.category.rawValue):\($0.items.count):\(generation)"
    }
        .joined(separator: ",")
}

public struct FileListView: View {
    let results: [ScanResult]
    @Binding var selectedItems: Set<URL>
    @State private var expansion = FileListExpansion()
    @State private var sort: FileListSort = .default

    @State private var runningBundleIDs: Set<String> = []

    @State private var appRunningURLs: Set<URL> = []

    @State private var displayResults: [ScanResult]

    @State private var rows: [FileListRow] = []

    public init(results: [ScanResult], selectedItems: Binding<Set<URL>>) {
        self.results = results
        self._selectedItems = selectedItems
        self._displayResults = State(initialValue: results)
    }

    public var body: some View {
        VStack(spacing: 0) {
            sortBar

            FileTableView(
                rows: rows,
                onToggleItem: { toggle($0) },
                onToggleAll: { toggleAll($0) },
                onToggleExpand: { expansion.toggle($0) }
            )
        }
        .onAppear {
            runningBundleIDs = Set(NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier))
        }

        .onChange(of: rowsKey, initial: true) { _, _ in
            rows = FileListRows.flatten(
                results: displayResults,
                isExpanded: { expansion.isExpanded($0) },
                selectedItems: selectedItems,
                appRunningURLs: appRunningURLs
            )
        }

        .task(id: "\(sortSignature)#\(runningBundleIDs.count)") {
            let snapshot = results
            let running = runningBundleIDs
            appRunningURLs = await Task.detached(priority: .utility) {
                AppCacheOwnership.runningOwnedURLs(in: snapshot, runningBundleIDs: running)
            }.value
        }

        .task(id: sortSignature) {
            let snapshot = results
            let order = sort
            let sorted = await Task.detached(priority: .userInitiated) {
                order.sorted(snapshot)
            }.value
            displayResults = sorted
        }
    }

    private var sortSignature: String {
        fileListResultsSignature(sort: sort, results: results)
    }

    private var displayedResultsSignature: String {
        fileListResultsSignature(sort: sort, results: displayResults)
    }

    private var rowsKey: String {
        "\(displayedResultsSignature)|sel:\(selectedItems.count)|exp:\(expansion.signature)|run:\(appRunningURLs.count)"
    }

    private var sortBar: some View {
        HStack(spacing: 6) {
            Spacer()
            Image(systemName: "arrow.up.arrow.down")
                .font(.caption2)
                .foregroundStyle(.tertiary)
            Menu {
                Picker(String(localized: "Sort by"), selection: $sort) {
                    ForEach(FileListSort.allCases, id: \.self) { option in
                        Text(option.label).tag(option)
                    }
                }
                .pickerStyle(.inline)
            } label: {
                Text(sort.label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    private func toggle(_ url: URL) {
        if selectedItems.contains(url) {
            selectedItems.remove(url)
        } else {
            selectedItems.insert(url)
        }
    }

    private func toggleAll(_ category: ScanCategory) {
        guard let result = results.first(where: { $0.category == category }) else { return }
        let urls = Set(result.items.map(\.url))
        if urls.isSubset(of: selectedItems) {
            selectedItems.subtract(urls)
        } else {
            selectedItems.formUnion(urls)
        }
    }
}
