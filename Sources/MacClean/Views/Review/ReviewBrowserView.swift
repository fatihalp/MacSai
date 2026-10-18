import SwiftUI
import AppKit
import MacCleanKit

struct ReviewBrowserView: View {
    let data: ReviewData
    let selection: ReviewSelection
    var doneTitle: String = "Done"
    var doneDisabled: Bool = false
    let onDone: () -> Void
    var onClean: (() -> Void)? = nil

    @State private var sectionID: String
    @State private var categoryID: Int?
    @State private var drillPath: [ReviewNode] = []
    @State private var childCache: [String: [ReviewNode]] = [:]
    @State private var loadingNodeID: String?
    @State private var searchText: String = ""
    @State private var onlyLargeFiles: Bool = false

    private static let maxRows = 1_000

    init(
        data: ReviewData,
        selection: ReviewSelection,
        initialSectionID: String? = nil,
        doneTitle: String = "Done",
        doneDisabled: Bool = false,
        onDone: @escaping () -> Void,
        onClean: (() -> Void)? = nil
    ) {
        self.data = data
        self.selection = selection
        self.doneTitle = doneTitle
        self.doneDisabled = doneDisabled
        self.onDone = onDone
        self.onClean = onClean
        let section = data.sections.first { $0.id == initialSectionID } ?? data.sections.first
        _sectionID = State(initialValue: section?.id ?? "")
        let initialCat = section?.categoryIDs.first(where: { data.categories[$0].size > 0 }) ?? section?.categoryIDs.first ?? data.categories.first?.id
        _categoryID = State(initialValue: initialCat)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                categoriesMasterList
                    .frame(width: 320)
                    .background(Color(white: 0.985))

                Divider()

                detailPane
                    .frame(minWidth: 400, maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.white)
            }

            Divider()

            bottomBar
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
    }

    private var currentSection: ReviewSection? {
        data.sections.first { $0.id == sectionID }
    }

    private var currentCategory: ReviewCategory? {
        categoryID.map { data.categories[$0] }
    }

    private var categoriesMasterList: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Text("Categories")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)

                Spacer()

                HStack(spacing: 4) {
                    Button("All") {
                        selection.applyToAll(.all)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)

                    Button("Smart") {
                        selection.applyToAll(.smart)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)

                    Button("None") {
                        selection.applyToAll(.none)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider()

            ScrollView {
                if data.sections.count > 1 {
                    LazyVStack(alignment: .leading, spacing: 14) {
                        ForEach(data.sections) { section in
                            sectionGroup(section)
                        }
                    }
                    .padding(.vertical, 8)
                } else {
                    LazyVStack(spacing: 2) {
                        ForEach(data.categories) { category in
                            categoryRow(category)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 8)
                }
            }
        }
    }

    private func sectionGroup(_ section: ReviewSection) -> some View {
        let sectionSize = selection.selectedSize(ofSection: section)
        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: ReviewSectionInfo.icon(for: section.id))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color(nsColor: .systemBlue))

                Text(section.name)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                Spacer()

                if sectionSize > 0 {
                    Text(FileSizeFormatter.format(sectionSize))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color(nsColor: .systemBlue))
                }

                ReviewCheckbox(state: selection.state(ofSection: section)) {
                    selection.toggleSection(section)
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 4)
            .padding(.bottom, 2)

            VStack(spacing: 2) {
                ForEach(section.categoryIDs, id: \.self) { id in
                    categoryRow(data.categories[id])
                }
            }
            .padding(.horizontal, 8)
        }
    }

    private func categoryRow(_ category: ReviewCategory) -> some View {
        let isSelected = category.id == categoryID
        let selectedSize = selection.selectedSize(ofCategory: category.id)
        let isEmpty = category.size == 0
        return HStack(spacing: 8) {
            ReviewCheckbox(state: selection.state(ofCategory: category.id)) {
                selection.toggleCategory(category.id)
            }
            .disabled(isEmpty)
            .opacity(isEmpty ? 0.35 : 1)

            Button {
                guard category.id != categoryID else {
                    drillPath = []
                    return
                }
                categoryID = category.id
                drillPath = []
                if let section = data.sections.first(where: { $0.categoryIDs.contains(category.id) }) {
                    sectionID = section.id
                }
            } label: {
                HStack(spacing: 8) {
                    ReviewCategoryIcon(category: category.category, isEmpty: isEmpty)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(category.category.displayName)
                            .font(.system(size: 12.5, weight: isSelected ? .semibold : .regular))
                            .foregroundStyle(isEmpty ? Color.secondary : Color.primary)
                            .lineLimit(1)

                        Text(FileSizeFormatter.format(category.size))
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 4)

                    if selectedSize > 0 {
                        Text(FileSizeFormatter.format(selectedSize))
                            .font(.system(size: 10.5, weight: .semibold))
                            .foregroundStyle(Color(nsColor: .systemBlue))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(nsColor: .systemBlue).opacity(0.12), in: Capsule())
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            isSelected ? Color(nsColor: .systemBlue).opacity(0.12) : Color.clear,
            in: RoundedRectangle(cornerRadius: 6, style: .continuous)
        )
        .help(category.category.tooltip)
    }

    @ViewBuilder
    private var detailPane: some View {
        if let category = currentCategory {
            VStack(alignment: .leading, spacing: 0) {
                detailHeader(category)

                Divider()

                if !drillPath.isEmpty {
                    breadcrumb(category)
                    Divider()
                }

                nodeList(category)
            }
        } else {
            VStack {
                Spacer()
                Text("Select a category to view details")
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func detailHeader(_ category: ReviewCategory) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(category.category.displayName)
                            .font(.system(size: 18, weight: .bold))

                        Text(FileSizeFormatter.format(category.size))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }

                    Text(ReviewCategoryInfo.description(for: category.category))
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer()
            }

            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 11))

                    TextField("Search items...", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))

                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                                .font(.system(size: 11))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Color(white: 0.97), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 0.5)
                )
                .frame(maxWidth: 220)

                Spacer()

                if !category.groups.isEmpty {
                    HStack(spacing: 6) {
                        Button("Select All") {
                            selection.apply(.all, toCategory: category.id)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .keyboardShortcut("a", modifiers: .command)

                        Button("Smart") {
                            selection.apply(.smart, toCategory: category.id)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)

                        Button("Deselect") {
                            selection.apply(.none, toCategory: category.id)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)

                        Toggle(isOn: $onlyLargeFiles) {
                            Text("> 100 MB")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .toggleStyle(.button)
                        .controlSize(.small)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    private func breadcrumb(_ category: ReviewCategory) -> some View {
        HStack(spacing: 6) {
            Button {
                drillPath.removeLast()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 11, weight: .semibold))
                    Text(drillPath.count > 1 ? drillPath[drillPath.count - 2].name : category.category.displayName)
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundStyle(Color(nsColor: .systemBlue))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Text("›")
                .foregroundStyle(.tertiary)

            Text(drillPath.last?.name ?? "")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.primary)

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .background(Color(white: 0.985))
    }

    @ViewBuilder
    private func nodeList(_ category: ReviewCategory) -> some View {
        let baseNodes = drillPath.last.flatMap { childCache[$0.id] } ?? category.groups
        let filteredNodes = baseNodes.filter { node in
            let matchesSearch = searchText.isEmpty || node.name.localizedCaseInsensitiveContains(searchText)
            let matchesSize = !onlyLargeFiles || node.size >= 100 * 1024 * 1024
            return matchesSearch && matchesSize
        }

        if category.groups.isEmpty {
            VStack(spacing: 8) {
                Spacer()
                Image(systemName: "checkmark.circle")
                    .font(.system(size: 28))
                    .foregroundStyle(.secondary)
                Text("Nothing to clean in this category")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let parent = drillPath.last, childCache[parent.id] == nil || loadingNodeID == parent.id {
            VStack {
                Spacer()
                ProgressView().controlSize(.small)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if filteredNodes.isEmpty {
            VStack(spacing: 8) {
                Spacer()
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 28))
                    .foregroundStyle(.secondary)
                Text("No items match your filter")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(filteredNodes.prefix(Self.maxRows)) { node in
                        nodeRow(node, category: category)
                        Divider()
                            .padding(.leading, 44)
                    }
                    if filteredNodes.count > Self.maxRows {
                        Text("Showing the largest \(Self.maxRows) of \(filteredNodes.count) items")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 10)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 4)
            }
            .id(drillPath.last?.id ?? "category-\(category.id)")
        }
    }

    private func nodeRow(_ node: ReviewNode, category: ReviewCategory) -> some View {
        let state = selection.state(of: node.range)
        let showChevron = !node.isLeaf && category.category != .systemLogs && category.category != .userLogs || !drillPath.isEmpty && !node.isLeaf
        return HStack(spacing: 10) {
            ReviewCheckbox(state: state) {
                selection.toggle(node, category: category.id)
            }
            ReviewFileIcon(path: node.iconPath)
                .frame(width: 24, height: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(node.name)
                    .font(.system(size: 13))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                if node.appIsRunning || node.isSensitive {
                    HStack(spacing: 8) {
                        if node.appIsRunning {
                            Label(
                                "App is open",
                                systemImage: "lock.fill"
                            )
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundStyle(.orange)
                        }
                        if node.isSensitive {
                            Label(
                                "Sensitive path",
                                systemImage: "exclamationmark.shield.fill"
                            )
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundStyle(.red)
                        }
                    }
                }
            }
            Spacer(minLength: 8)
            Text(FileSizeFormatter.format(node.size))
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .frame(width: 76, alignment: .trailing)
            if showChevron {
                Button {
                    drill(into: node)
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.tertiary)
                        .frame(width: 20, height: 20)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            } else {
                Color.clear
                    .frame(width: 20)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onTapGesture {
            selection.toggle(node, category: category.id)
        }
        .help(node.basePath)
        .contextMenu {
            Button("Reveal in Finder") {
                NSWorkspace.shared.activateFileViewerSelecting([URL(filePath: node.basePath)])
            }
            if !node.isLeaf {
                Button("Show Contents") { drill(into: node) }
            }
        }
    }

    private func drill(into node: ReviewNode) {
        guard !node.isLeaf else { return }
        drillPath.append(node)
        guard childCache[node.id] == nil else { return }
        if node.range.count <= 20_000 {
            childCache[node.id] = data.children(of: node)
            return
        }
        loadingNodeID = node.id
        let data = self.data
        Task {
            let children = await Task.detached(priority: .userInitiated) {
                data.children(of: node)
            }.value
            childCache[node.id] = children
            if loadingNodeID == node.id { loadingNodeID = nil }
        }
    }

    private var bottomBar: some View {
        HStack(spacing: 12) {
            if let locked = selection.lockedSummary {
                HStack(spacing: 5) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 10.5))
                        .foregroundStyle(.orange)
                    Text("\(locked.appCount) open app\(locked.appCount == 1 ? "" : "s") skipped (\(FileSizeFormatter.format(locked.bytes)))")
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                }
                .padding(.leading, 16)
            } else {
                Spacer()
                    .frame(width: 16)
            }

            Spacer()

            HStack(spacing: 6) {
                Text("\(selection.selectedCount.formatted()) Items Selected")
                    .font(.system(size: 12.5, weight: .medium))
                Text("·")
                    .foregroundStyle(.tertiary)
                Text(FileSizeFormatter.format(selection.selectedSize))
                    .font(.system(size: 12.5, weight: .bold))
                    .foregroundStyle(Color(nsColor: .systemBlue))
                    .monospacedDigit()
            }

            HStack(spacing: 8) {
                if let onClean {
                    Button("Back", action: onDone)
                        .buttonStyle(.bordered)
                        .controlSize(.regular)

                    Button("Clean (\(FileSizeFormatter.format(selection.selectedSize)))", action: onClean)
                        .buttonStyle(.borderedProminent)
                        .tint(Color(nsColor: .systemBlue))
                        .controlSize(.regular)
                        .disabled(selection.selectedCount == 0)
                        .keyboardShortcut(.defaultAction)
                } else {
                    Button(doneTitle, action: onDone)
                        .buttonStyle(.borderedProminent)
                        .tint(Color(nsColor: .systemBlue))
                        .controlSize(.regular)
                        .disabled(doneDisabled)
                        .keyboardShortcut(.defaultAction)
                }
            }
            .padding(.trailing, 16)
        }
        .frame(height: 50)
        .background(Color.white)
    }
}

enum ReviewSectionInfo {
    static func description(for moduleID: String) -> String? {
        switch moduleID {
        case "system_junk":
            String(localized: "Redundant files that clog up device storage and impede optimal performance.")
        case "mail_attachments":
            String(localized: "Local copies of attachments saved by your mail apps.")
        case "trash_bins":
            String(localized: "Items still taking up space in your Trash bins.")
        case "malware":
            String(localized: "Suspicious files found on your disk.")
        case "privacy":
            String(localized: "Browsing and activity traces.")
        default:
            nil
        }
    }

    static func icon(for moduleID: String) -> String {
        switch moduleID {
        case "system_junk": "trash.circle.fill"
        case "mail_attachments": "paperclip.circle.fill"
        case "trash_bins": "trash.fill"
        case "malware": "shield.lefthalf.filled"
        case "privacy": "hand.raised.fill"
        default: "folder.fill"
        }
    }
}

enum ReviewCategoryInfo {
    static func description(for category: ScanCategory) -> String {
        switch category {
        case .userCaches, .packageManagerCaches, .ideCaches, .aiToolCaches:
            String(localized: "Originally intended to improve startup times, the cache files of your applications ultimately accumulate and result in improper functioning or an overall performance drop.")
        case .systemLogs:
            String(localized: "The activity of your system applications and services is being captured into numerous logs, which may be helpful for debugging purposes only and can be removed without a second thought.")
        case .userLogs:
            String(localized: "The activity of your applications is constantly being captured into numerous log files, which start using quite a lot of space after some time but are rather useless, especially if they are old.")
        default:
            category.safetyRationale
        }
    }
}

struct ReviewCheckbox: View {
    let state: ReviewCheckState
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(state == .off ? Color.white : Color(nsColor: .systemBlue))
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .strokeBorder(state == .off ? Color.secondary.opacity(0.45) : Color(nsColor: .systemBlue), lineWidth: 1)
                switch state {
                case .on:
                    Image(systemName: "checkmark")
                        .font(.system(size: 9.5, weight: .bold))
                        .foregroundStyle(.white)
                case .mixed:
                    Image(systemName: "minus")
                        .font(.system(size: 9.5, weight: .bold))
                        .foregroundStyle(.white)
                case .off:
                    EmptyView()
                }
            }
            .frame(width: 15, height: 15)
            .padding(2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Select")
        .accessibilityValue(state == .on ? "1" : state == .mixed ? "0.5" : "0")
    }
}

struct ReviewCategoryIcon: View {
    let category: ScanCategory
    var isEmpty: Bool = false

    var body: some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(isEmpty ? Color.secondary.opacity(0.1) : Color(nsColor: .systemBlue).opacity(0.12))
            .overlay(
                Image(systemName: mainSymbol)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(isEmpty ? Color.secondary : Color(nsColor: .systemBlue))
            )
            .frame(width: 26, height: 26)
    }

    private var mainSymbol: String {
        switch category {
        case .userCaches, .systemCaches: "clock.fill"
        case .xcodeJunk: "hammer.fill"
        case .universalBinaries: "circle.lefthalf.filled"
        case .userLogs, .systemLogs: "doc.text.fill"
        case .languageFiles: "bubble.left.fill"
        case .documentVersions: "checkmark.circle.fill"
        case .brokenLoginItems: "person.slash.fill"
        case .iosDeviceBackups: "arrow.clockwise.circle.fill"
        case .deletedUsers: "person.crop.rectangle.fill"
        case .brokenPreferences: "gearshape.fill"
        default: category.systemImage
        }
    }
}

struct ReviewFileIcon: View {
    let path: String

    var body: some View {
        Image(nsImage: ReviewIconCache.icon(for: path))
            .resizable()
            .interpolation(.high)
            .aspectRatio(contentMode: .fit)
    }
}

@MainActor
enum ReviewIconCache {
    private static let cache = NSCache<NSString, NSImage>()

    static func icon(for path: String) -> NSImage {
        if let cached = cache.object(forKey: path as NSString) { return cached }
        let image = NSWorkspace.shared.icon(forFile: path)
        cache.setObject(image, forKey: path as NSString)
        return image
    }
}
