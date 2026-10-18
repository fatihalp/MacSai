import SwiftUI
import AppKit
import MacCleanKit

enum ReviewPalette {
    static let accent = Color(nsColor: .systemBlue)
    static let selection = Color(nsColor: .systemBlue).opacity(0.12)
    static let moduleSelection = Color(nsColor: .systemBlue).opacity(0.12)
    static let panel = Color.white
    static let middlePane = Color(white: 0.985)
    static let sidebar = Color(white: 0.965)
}

struct ReviewBrowserView: View {
    let data: ReviewData
    let selection: ReviewSelection
    var doneTitle: String = String(localized: "Done")
    var doneDisabled: Bool = false
    let onDone: () -> Void
    var onClean: (() -> Void)? = nil

    @State private var sectionID: String
    @State private var categoryID: Int?
    @State private var drillPath: [ReviewNode] = []
    @State private var childCache: [String: [ReviewNode]] = [:]
    @State private var loadingNodeID: String?

    private static let maxRows = 1_000

    init(
        data: ReviewData,
        selection: ReviewSelection,
        initialSectionID: String? = nil,
        doneTitle: String = String(localized: "Done"),
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
        _categoryID = State(initialValue: section?.categoryIDs.first)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                if data.sections.count > 1 {
                    sectionList
                        .frame(width: 215)
                        .background(ReviewPalette.sidebar)
                    Divider()
                }
                categoryList
                    .frame(width: 280)
                    .background(ReviewPalette.middlePane)
                Divider()
                detailPane
                    .frame(minWidth: 300, maxWidth: .infinity, maxHeight: .infinity)
                    .background(ReviewPalette.panel)
            }
            Divider()
            bottomBar
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ReviewPalette.panel)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1)
        )
    }

    private var currentSection: ReviewSection? {
        data.sections.first { $0.id == sectionID }
    }

    private var currentCategory: ReviewCategory? {
        categoryID.map { data.categories[$0] }
    }

    private var sectionList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text("Modules")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button(String(localized: "All")) {
                        selection.applyToAll(.all)
                    }
                    .buttonStyle(.borderless)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(ReviewPalette.accent)

                    Text("·").foregroundStyle(.tertiary)

                    Button(String(localized: "None")) {
                        selection.applyToAll(.none)
                    }
                    .buttonStyle(.borderless)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(ReviewPalette.accent)
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 6)

                ForEach(data.sections) { section in
                    let isSelected = section.id == sectionID
                    let sectionSelectedSize = selection.selectedSize(ofSection: section)
                    HStack(spacing: 8) {
                        ReviewCheckbox(state: selection.state(ofSection: section)) {
                            selection.toggleSection(section)
                        }
                        Button {
                            guard section.id != sectionID else { return }
                            sectionID = section.id
                            categoryID = section.categoryIDs.first
                            drillPath = []
                        } label: {
                            HStack(spacing: 6) {
                                Text(section.name)
                                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                                    .foregroundStyle(isSelected ? ReviewPalette.accent : Color.primary)
                                    .lineLimit(1)
                                Spacer(minLength: 4)
                                if sectionSelectedSize > 0 {
                                    Text(FileSizeFormatter.format(sectionSelectedSize))
                                        .font(.system(size: 11))
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(
                        isSelected ? ReviewPalette.moduleSelection : .clear,
                        in: RoundedRectangle(cornerRadius: 6, style: .continuous)
                    )
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 14)
            .padding(.bottom, 10)
        }
    }

    private var categoryList: some View {
        ScrollView {
            if let section = currentSection {
                VStack(alignment: .leading, spacing: 0) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(section.name)
                                .font(.system(size: 16, weight: .semibold))
                            Spacer()
                            HStack(spacing: 6) {
                                Button(String(localized: "All")) {
                                    selection.apply(.all, toSection: section)
                                }
                                .buttonStyle(.borderless)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(ReviewPalette.accent)

                                Text("·").foregroundStyle(.tertiary)

                                Button(String(localized: "Smart")) {
                                    selection.apply(.smart, toSection: section)
                                }
                                .buttonStyle(.borderless)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(ReviewPalette.accent)

                                Text("·").foregroundStyle(.tertiary)

                                Button(String(localized: "None")) {
                                    selection.apply(.none, toSection: section)
                                }
                                .buttonStyle(.borderless)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(ReviewPalette.accent)
                            }
                        }
                        if let description = ReviewSectionInfo.description(for: section.id) {
                            Text(description)
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                                .lineLimit(3)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 12)

                    Divider()
                        .padding(.bottom, 6)

                    LazyVStack(spacing: 2) {
                        ForEach(section.categoryIDs, id: \.self) { id in
                            categoryRow(data.categories[id])
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.bottom, 12)
                }
            }
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
            } label: {
                HStack(spacing: 10) {
                    ReviewCategoryIcon(category: category.category, isEmpty: isEmpty)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(category.category.displayName)
                            .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
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
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2.5)
                            .background(ReviewPalette.accent, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(
            isSelected ? ReviewPalette.selection : .clear,
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
                    breadcrumb
                    Divider()
                }
                nodeList(category)
            }
        } else {
            Color.white
        }
    }

    private func detailHeader(_ category: ReviewCategory) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(category.category.displayName)
                    .font(.system(size: 16, weight: .semibold))
                Spacer()
                if !category.groups.isEmpty {
                    HStack(spacing: 6) {
                        Button(String(localized: "Select All")) {
                            selection.apply(.all, toCategory: category.id)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .keyboardShortcut("a", modifiers: .command)

                        Button(String(localized: "Smart")) {
                            selection.apply(.smart, toCategory: category.id)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)

                        Button(String(localized: "Deselect All")) {
                            selection.apply(.none, toCategory: category.id)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .keyboardShortcut("a", modifiers: [.command, .option])
                    }
                }
            }
            Text(ReviewCategoryInfo.description(for: category.category))
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .lineLimit(3)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private var breadcrumb: some View {
        HStack(spacing: 6) {
            Button {
                drillPath.removeLast()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 11, weight: .semibold))
                    Text("Back")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundStyle(ReviewPalette.accent)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Text("›")
                .foregroundStyle(.tertiary)

            Text(drillPath.map(\.name).joined(separator: "  ›  "))
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.head)
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .background(Color(white: 0.98))
    }

    @ViewBuilder
    private func nodeList(_ category: ReviewCategory) -> some View {
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
        } else {
            let nodes = drillPath.last.flatMap { childCache[$0.id] } ?? category.groups
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(nodes.prefix(Self.maxRows)) { node in
                        nodeRow(node, category: category)
                        Divider()
                            .padding(.leading, 44)
                    }
                    if nodes.count > Self.maxRows {
                        Text("Showing the largest \(Self.maxRows) of \(nodes.count) items")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 10)
                    }
                }
                .padding(.horizontal, 12)
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
                .frame(width: 26, height: 26)
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
                                String(localized: "App is open"),
                                systemImage: "lock.fill"
                            )
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundStyle(.orange)
                        }
                        if node.isSensitive {
                            Label(
                                String(localized: "Sensitive path — review before deleting"),
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
                .frame(width: 72, alignment: .trailing)
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
            Button(String(localized: "Reveal in Finder")) {
                NSWorkspace.shared.activateFileViewerSelecting([URL(filePath: node.basePath)])
            }
            if !node.isLeaf {
                Button(String(localized: "Show Contents")) { drill(into: node) }
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
                Text("\(selection.selectedCount) Items Selected")
                    .font(.system(size: 12.5, weight: .medium))
                Text("·")
                    .foregroundStyle(.tertiary)
                Text(FileSizeFormatter.format(selection.selectedSize))
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(ReviewPalette.accent)
                    .monospacedDigit()
            }

            Spacer()

            HStack(spacing: 8) {
                if let onClean {
                    Button(String(localized: "Back"), action: onDone)
                        .buttonStyle(.bordered)
                        .controlSize(.regular)

                    Button("\(String(localized: "Clean")) (\(FileSizeFormatter.format(selection.selectedSize)))", action: onClean)
                        .buttonStyle(.borderedProminent)
                        .tint(ReviewPalette.accent)
                        .controlSize(.regular)
                        .disabled(selection.selectedCount == 0)
                        .keyboardShortcut(.defaultAction)
                } else {
                    Button(doneTitle, action: onDone)
                        .buttonStyle(.borderedProminent)
                        .tint(ReviewPalette.accent)
                        .controlSize(.regular)
                        .disabled(doneDisabled)
                        .keyboardShortcut(.defaultAction)
                }
            }
            .padding(.trailing, 16)
        }
        .frame(height: 48)
        .background(Color(white: 0.975))
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
                    .fill(state == .off ? Color.white : ReviewPalette.accent)
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .strokeBorder(state == .off ? Color.secondary.opacity(0.45) : ReviewPalette.accent, lineWidth: 1)
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
        .accessibilityLabel(String(localized: "Select"))
        .accessibilityValue(state == .on ? "1" : state == .mixed ? "0.5" : "0")
    }
}

struct ReviewCategoryIcon: View {
    let category: ScanCategory
    var isEmpty: Bool = false

    var body: some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(isEmpty ? Color.secondary.opacity(0.1) : ReviewPalette.accent.opacity(0.12))
            .overlay(
                Image(systemName: mainSymbol)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(isEmpty ? Color.secondary : ReviewPalette.accent)
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

struct ReviewAccentButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(
                ReviewPalette.accent,
                in: RoundedRectangle(cornerRadius: 6, style: .continuous)
            )
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}
