import SwiftUI
import AppKit
import MacCleanKit

struct FileTableView: NSViewRepresentable {
    let rows: [FileListRow]
    let onToggleItem: (URL) -> Void
    let onToggleAll: (ScanCategory) -> Void
    let onToggleExpand: (ScanCategory) -> Void

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSScrollView {
        let table = NSTableView()
        let column = NSTableColumn(identifier: .init("main"))
        column.resizingMask = .autoresizingMask
        table.addTableColumn(column)
        table.headerView = nil
        table.usesAutomaticRowHeights = false
        table.selectionHighlightStyle = .none
        table.backgroundColor = .clear
        table.intercellSpacing = NSSize(width: 0, height: 2)
        table.style = .plain
        table.columnAutoresizingStyle = .firstColumnOnlyAutoresizingStyle

        let coordinator = context.coordinator
        table.dataSource = coordinator
        table.delegate = coordinator
        table.target = coordinator
        table.action = #selector(Coordinator.tableClicked(_:))

        let menu = NSMenu()
        let reveal = NSMenuItem(
            title: String(localized: "Reveal in Finder"),
            action: #selector(Coordinator.revealInFinder(_:)),
            keyEquivalent: ""
        )
        reveal.target = coordinator
        menu.addItem(reveal)
        menu.delegate = coordinator
        table.menu = menu

        coordinator.tableView = table

        let scroll = NSScrollView()
        scroll.documentView = table
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.drawsBackground = false

        scroll.automaticallyAdjustsContentInsets = false
        scroll.contentInsets = NSEdgeInsets(top: 8, left: 0, bottom: 8, right: 0)
        return scroll
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        let coordinator = context.coordinator
        coordinator.onToggleItem = onToggleItem
        coordinator.onToggleAll = onToggleAll
        coordinator.onToggleExpand = onToggleExpand
        if coordinator.rows != rows {
            coordinator.rows = rows
            coordinator.tableView?.reloadData()
        }
    }

    @MainActor
    final class Coordinator: NSObject, NSTableViewDataSource,
                             NSTableViewDelegate, NSMenuDelegate {
        var rows: [FileListRow] = []
        weak var tableView: NSTableView?
        var onToggleItem: (URL) -> Void = { _ in }
        var onToggleAll: (ScanCategory) -> Void = { _ in }
        var onToggleExpand: (ScanCategory) -> Void = { _ in }

        func numberOfRows(in tableView: NSTableView) -> Int { rows.count }

        func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
            switch rows[row] {
            case .header: 50
            case .item: 42
            }
        }

        func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
            switch rows[row] {
            case .header(let header):
                let cell = dequeue(tableView, id: "header") { HeaderCellView() }
                cell.configure(header: header) { [weak self] in
                    self?.onToggleExpand(header.category)
                } onToggleAll: { [weak self] in
                    self?.onToggleAll(header.category)
                }
                return cell
            case .item(let item, let isSelected, let appRunning):
                let cell = dequeue(tableView, id: "item") { ItemCellView() }
                cell.configure(
                    item: item,
                    isSelected: isSelected,
                    appRunning: appRunning,
                    onToggle: { [weak self] in self?.onToggleItem(item.url) },
                    onReveal: { NSWorkspace.shared.activateFileViewerSelecting([item.url]) },
                    onInfo: {
                        let pasteboard = NSPasteboard.general
                        pasteboard.clearContents()
                        pasteboard.setString(item.url.path(percentEncoded: false), forType: .string)
                    }
                )
                return cell
            }
        }

        func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
            let id = NSUserInterfaceItemIdentifier("grouprow")
            let rowView = (tableView.makeView(withIdentifier: id, owner: nil) as? GroupRowView)
                ?? { let view = GroupRowView(); view.identifier = id; return view }()
            rowView.groupPosition = groupPosition(for: row)
            return rowView
        }

        private func groupPosition(for row: Int) -> GroupRowView.GroupPosition {
            let isFirst: Bool = { if case .header = rows[row] { return true } else { return false } }()
            let isLast: Bool = row == rows.count - 1
                || { if case .header = rows[row + 1] { return true } else { return false } }()
            switch (isFirst, isLast) {
            case (true, true): return .single
            case (true, false): return .top
            case (false, true): return .bottom
            case (false, false): return .middle
            }
        }

        private func dequeue<T: NSTableCellView>(
            _ tableView: NSTableView, id: String, make: () -> T
        ) -> T {
            let identifier = NSUserInterfaceItemIdentifier(id)
            if let cell = tableView.makeView(withIdentifier: identifier, owner: nil) as? T {
                return cell
            }
            let cell = make()
            cell.identifier = identifier
            return cell
        }

        @objc func tableClicked(_ sender: NSTableView) {
            let row = sender.clickedRow
            guard row >= 0, row < rows.count else { return }
            switch rows[row] {
            case .header(let header): onToggleExpand(header.category)
            case .item(let item, _, _): onToggleItem(item.url)
            }
        }

        @objc func revealInFinder(_ sender: NSMenuItem) {
            guard let row = tableView?.clickedRow, row >= 0, row < rows.count,
                  case .item(let item, _, _) = rows[row] else { return }
            NSWorkspace.shared.activateFileViewerSelecting([item.url])
        }

        func menuNeedsUpdate(_ menu: NSMenu) {
            let row = tableView?.clickedRow ?? -1
            let isItem = row >= 0 && row < rows.count
                && { if case .item = rows[row] { return true } else { return false } }()
            menu.items.forEach { $0.isHidden = !isItem }
        }
    }
}

private final class HeaderCellView: NSTableCellView {
    private let chevron = NSButton()
    private let checkbox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let icon = NSImageView()
    private let title = NSTextField(labelWithString: "")
    private let safetyButton = NSButton()
    private let subtitle = NSTextField(labelWithString: "")
    private let count = NSTextField(labelWithString: "")
    private let size = NSTextField(labelWithString: "")
    private var category: ScanCategory?
    private var onToggleExpand: () -> Void = {}
    private var onToggleAll: () -> Void = {}

    init() {
        super.init(frame: .zero)

        chevron.isBordered = false
        chevron.bezelStyle = .regularSquare
        chevron.imagePosition = .imageOnly
        chevron.target = self
        chevron.action = #selector(chevronClicked)

        checkbox.allowsMixedState = true
        checkbox.target = self
        checkbox.action = #selector(checkboxClicked)

        icon.contentTintColor = .secondaryLabelColor

        title.font = .boldSystemFont(ofSize: 13)
        title.lineBreakMode = .byTruncatingTail
        title.maximumNumberOfLines = 1

        safetyButton.isBordered = false
        safetyButton.bezelStyle = .regularSquare
        safetyButton.imagePosition = .imageOnly
        safetyButton.target = self
        safetyButton.action = #selector(safetyClicked)
        safetyButton.setContentCompressionResistancePriority(.required, for: .horizontal)

        subtitle.font = .systemFont(ofSize: 10)
        subtitle.textColor = .tertiaryLabelColor
        subtitle.lineBreakMode = .byTruncatingTail
        subtitle.maximumNumberOfLines = 1

        for label in [title, subtitle] {
            label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            label.setContentHuggingPriority(.defaultLow, for: .horizontal)
        }

        count.font = .systemFont(ofSize: 11)
        count.textColor = .tertiaryLabelColor

        size.font = .systemFont(ofSize: 11, weight: .medium)

        for view in [chevron, checkbox, icon, title, safetyButton, subtitle, count, size] {
            view.translatesAutoresizingMaskIntoConstraints = false
            addSubview(view)
        }
        NSLayoutConstraint.activate([
            chevron.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            chevron.centerYAnchor.constraint(equalTo: centerYAnchor),
            chevron.widthAnchor.constraint(equalToConstant: 18),
            checkbox.leadingAnchor.constraint(equalTo: chevron.trailingAnchor, constant: 4),
            checkbox.centerYAnchor.constraint(equalTo: centerYAnchor),
            icon.leadingAnchor.constraint(equalTo: checkbox.trailingAnchor, constant: 8),
            icon.centerYAnchor.constraint(equalTo: centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 18),
            title.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 10),
            title.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            subtitle.leadingAnchor.constraint(equalTo: title.leadingAnchor),
            subtitle.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 2),
            size.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            size.centerYAnchor.constraint(equalTo: centerYAnchor),
            count.trailingAnchor.constraint(equalTo: size.leadingAnchor, constant: -12),
            count.centerYAnchor.constraint(equalTo: centerYAnchor),
            safetyButton.leadingAnchor.constraint(equalTo: title.trailingAnchor, constant: 4),
            safetyButton.centerYAnchor.constraint(equalTo: title.centerYAnchor),
            safetyButton.widthAnchor.constraint(equalToConstant: 16),
            safetyButton.heightAnchor.constraint(equalToConstant: 16),
            safetyButton.trailingAnchor.constraint(lessThanOrEqualTo: count.leadingAnchor, constant: -8),
            subtitle.trailingAnchor.constraint(lessThanOrEqualTo: count.leadingAnchor, constant: -8),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not used") }

    func configure(
        header: FileListHeader,
        onToggleExpand: @escaping () -> Void,
        onToggleAll: @escaping () -> Void
    ) {
        self.onToggleExpand = onToggleExpand
        self.onToggleAll = onToggleAll
        chevron.image = NSImage(
            systemSymbolName: header.isExpanded ? "chevron.down" : "chevron.right",
            accessibilityDescription: header.isExpanded ? String(localized: "Collapse") : String(localized: "Expand")
        )
        switch header.selection {
        case .all: checkbox.state = .on
        case .mixed: checkbox.state = .mixed
        case .none: checkbox.state = .off
        }
        icon.image = NSImage(
            systemSymbolName: header.category.systemImage, accessibilityDescription: nil
        )
        title.stringValue = header.category.displayName
        subtitle.stringValue = header.category.subtitle

        toolTip = header.category.tooltip
        category = header.category
        let safety = header.category.cleanupSafety
        safetyButton.image = NSImage(
            systemSymbolName: safety.systemImage, accessibilityDescription: safety.label
        )
        safetyButton.contentTintColor = Self.tint(for: safety)
        safetyButton.toolTip = "\(safety.label)\n\(header.category.safetyRationale)"
        safetyButton.setAccessibilityLabel(safety.label)
        safetyButton.setAccessibilityHelp(header.category.safetyRationale)
        count.stringValue = "\(header.selectedCount)/\(header.fileCount) selected"
        size.attributedStringValue = Self.sizeText(
            selected: header.selectedSize, total: header.totalSize
        )
    }

    private static func sizeText(selected: UInt64, total: UInt64) -> NSAttributedString {
        let result = NSMutableAttributedString(
            string: FileSizeFormatter.format(selected),
            attributes: [
                .foregroundColor: NSColor.labelColor,
                .font: NSFont.systemFont(ofSize: 11, weight: .semibold),
            ]
        )
        result.append(NSAttributedString(
            string: " / \(FileSizeFormatter.format(total))",
            attributes: [
                .foregroundColor: NSColor.secondaryLabelColor,
                .font: NSFont.systemFont(ofSize: 11, weight: .regular),
            ]
        ))
        return result
    }

    private static func tint(for safety: ScanCategory.CleanupSafety) -> NSColor {
        switch safety {
        case .regenerates, .safeToRemove: .systemGreen
        case .reviewFirst: .systemOrange
        }
    }

    @objc private func chevronClicked() { onToggleExpand() }
    @objc private func checkboxClicked() { onToggleAll() }

    @objc private func safetyClicked() {
        guard let category else { return }
        let popover = NSPopover()
        popover.behavior = .transient
        popover.contentViewController = SafetyRationaleViewController(category: category)
        popover.show(relativeTo: safetyButton.bounds, of: safetyButton, preferredEdge: .maxY)
    }
}

private final class SafetyRationaleViewController: NSViewController {
    private let category: ScanCategory

    init(category: ScanCategory) {
        self.category = category
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not used") }

    override func loadView() {
        let safety = category.cleanupSafety
        let heading = NSTextField(labelWithString: safety.label)
        heading.font = .boldSystemFont(ofSize: 12)

        let body = NSTextField(wrappingLabelWithString: category.safetyRationale)
        body.font = .systemFont(ofSize: 11)
        body.textColor = .secondaryLabelColor
        body.preferredMaxLayoutWidth = 280

        let stack = NSStackView(views: [heading, body])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 4
        stack.edgeInsets = NSEdgeInsets(top: 10, left: 12, bottom: 10, right: 12)
        stack.translatesAutoresizingMaskIntoConstraints = false
        body.widthAnchor.constraint(equalToConstant: 280).isActive = true
        view = stack
    }
}

private final class ItemCellView: NSTableCellView {
    private let checkbox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let icon = NSImageView()
    private let name = NSTextField(labelWithString: "")
    private let path = NSTextField(labelWithString: "")
    private let badge = BadgeView(text: String(localized: "App open"))
    private let size = NSTextField(labelWithString: "")
    private let infoButton = NSButton()
    private let revealButton = NSButton()
    private var onToggle: () -> Void = {}
    private var onReveal: () -> Void = {}
    private var onInfo: () -> Void = {}

    init() {
        super.init(frame: .zero)

        checkbox.target = self
        checkbox.action = #selector(checkboxClicked)

        icon.contentTintColor = .secondaryLabelColor

        name.font = .systemFont(ofSize: 12)
        name.lineBreakMode = .byTruncatingMiddle
        name.maximumNumberOfLines = 1

        path.font = .systemFont(ofSize: 10)
        path.textColor = .tertiaryLabelColor
        path.lineBreakMode = .byTruncatingHead
        path.maximumNumberOfLines = 1

        for label in [name, path] {
            label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            label.setContentHuggingPriority(.defaultLow, for: .horizontal)
        }

        size.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        size.textColor = .secondaryLabelColor
        size.alignment = .right

        configureIconButton(infoButton, symbol: "info.circle", tooltip: String(localized: "Copy path"), action: #selector(infoClicked))
        configureIconButton(revealButton, symbol: "folder", tooltip: String(localized: "Reveal in Finder"), action: #selector(revealClicked))

        for view in [checkbox, icon, name, path, badge, size, infoButton, revealButton] {
            view.translatesAutoresizingMaskIntoConstraints = false
            addSubview(view)
        }
        NSLayoutConstraint.activate([
            checkbox.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            checkbox.centerYAnchor.constraint(equalTo: centerYAnchor),
            icon.leadingAnchor.constraint(equalTo: checkbox.trailingAnchor, constant: 8),
            icon.centerYAnchor.constraint(equalTo: centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 20),
            name.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 8),
            name.topAnchor.constraint(equalTo: topAnchor, constant: 5),
            path.leadingAnchor.constraint(equalTo: name.leadingAnchor),
            path.topAnchor.constraint(equalTo: name.bottomAnchor, constant: 1),

            revealButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            revealButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            revealButton.widthAnchor.constraint(equalToConstant: 22),
            infoButton.trailingAnchor.constraint(equalTo: revealButton.leadingAnchor, constant: -2),
            infoButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            infoButton.widthAnchor.constraint(equalToConstant: 22),
            size.trailingAnchor.constraint(equalTo: infoButton.leadingAnchor, constant: -10),
            size.centerYAnchor.constraint(equalTo: centerYAnchor),
            size.widthAnchor.constraint(greaterThanOrEqualToConstant: 60),
            badge.trailingAnchor.constraint(equalTo: size.leadingAnchor, constant: -10),
            badge.centerYAnchor.constraint(equalTo: centerYAnchor),

            name.trailingAnchor.constraint(lessThanOrEqualTo: badge.leadingAnchor, constant: -8),
            path.trailingAnchor.constraint(lessThanOrEqualTo: badge.leadingAnchor, constant: -8),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not used") }

    private func configureIconButton(_ button: NSButton, symbol: String, tooltip: String, action: Selector) {
        button.isBordered = false
        button.bezelStyle = .regularSquare
        button.imagePosition = .imageOnly
        button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: tooltip)
        button.contentTintColor = .secondaryLabelColor
        button.toolTip = tooltip
        button.target = self
        button.action = action
    }

    func configure(
        item: FileItem,
        isSelected: Bool,
        appRunning: Bool,
        onToggle: @escaping () -> Void,
        onReveal: @escaping () -> Void,
        onInfo: @escaping () -> Void
    ) {
        self.onToggle = onToggle
        self.onReveal = onReveal
        self.onInfo = onInfo
        checkbox.state = isSelected ? .on : .off
        icon.image = NSImage(
            systemSymbolName: item.isDirectory ? "folder.fill" : Self.symbolName(for: item),
            accessibilityDescription: nil
        )
        name.stringValue = item.name
        path.stringValue = item.url.deletingLastPathComponent().path(percentEncoded: false)
        size.stringValue = item.formattedSize
        badge.isHidden = !appRunning
    }

    @objc private func checkboxClicked() { onToggle() }
    @objc private func revealClicked() { onReveal() }
    @objc private func infoClicked() { onInfo() }

    private static func symbolName(for item: FileItem) -> String {
        switch item.fileExtension {
        case "log", "txt": "doc.text"
        case "plist", "json", "xml": "doc.badge.gearshape"
        case "cache", "db", "sqlite": "cylinder"
        case "dmg": "opticaldisc"
        case "zip", "gz", "tar": "doc.zipper"
        case "lproj": "globe"
        default: "doc"
        }
    }
}

private final class GroupRowView: NSTableRowView {
    enum GroupPosition { case top, middle, bottom, single }
    var groupPosition: GroupPosition = .middle { didSet { needsLayout = true } }

    private let card = CALayer()
    private let hInset: CGFloat = 6
    private let gap: CGFloat = 6
    private let radius: CGFloat = 12

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        card.cornerRadius = radius
        layer?.addSublayer(card)
        updateCardColor()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not used") }

    override func layout() {
        super.layout()
        updateCardColor()

        card.actions = ["position": NSNull(), "bounds": NSNull(), "frame": NSNull()]

        let topGap: CGFloat = (groupPosition == .top || groupPosition == .single) ? gap : 0
        let bottomGap: CGFloat = (groupPosition == .bottom || groupPosition == .single) ? gap : 0

        card.frame = CGRect(
            x: hInset,
            y: topGap,
            width: max(0, bounds.width - hInset * 2),
            height: max(0, bounds.height - topGap - bottomGap)
        )
        switch groupPosition {
        case .top:
            card.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        case .bottom:
            card.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
        case .single:
            card.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner,
                                  .layerMinXMaxYCorner, .layerMaxXMaxYCorner]
        case .middle:
            card.maskedCorners = []
        }
    }

    private func updateCardColor() {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            card.backgroundColor = NSColor.labelColor.withAlphaComponent(0.06).cgColor
        }
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateCardColor()
    }

    override func drawSelection(in dirtyRect: NSRect) {}
}

private final class BadgeView: NSView {
    private let label = NSTextField(labelWithString: "")

    init(text: String) {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 5
        layer?.backgroundColor = NSColor.systemYellow.withAlphaComponent(0.18).cgColor

        label.stringValue = text
        label.font = .systemFont(ofSize: 9, weight: .semibold)
        label.textColor = .systemYellow
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
            label.topAnchor.constraint(equalTo: topAnchor, constant: 2),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -2),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not used") }
}
