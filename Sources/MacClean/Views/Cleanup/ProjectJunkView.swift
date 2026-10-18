import AppKit
import SwiftUI
import MacCleanKit
import UniformTypeIdentifiers

struct ProjectJunkView: View {
    @Environment(AppState.self) private var appState
    @State private var controller = ProjectJunkController()
    @State private var showPicker = false

    private var subtitle: String {
        if let rootURL = controller.rootURL {
            let noAutoSelect = String(localized: "Nothing is auto-selected.")
            return "\(rootURL.path(percentEncoded: false)) · \(noAutoSelect)"
        }
        let defaults = controller.availableDefaultRoots
        if !defaults.isEmpty {
            let names = defaults.prefix(3).map { "~/" + $0.lastPathComponent }.joined(separator: ", ")
            return "Scans discovered project folders (\(names)) for regenerable build directories like node_modules, target, .venv, and .build, or choose a folder manually."
        }
        return String(localized: "Choose a projects folder (e.g. ~/Code) to find regenerable folders like node_modules, venvs, target, and build.")
    }

    private var emptyMessage: String {
        if controller.rootRefused {
            return String(localized: "Choose your projects folder, not a system folder or Library.")
        }
        return String(localized: "No project junk found")
    }

    var body: some View {
        ModuleContainerView(
            title: String(localized: "Project Junk"),
            subtitle: subtitle,
            theme: .cleanup,
            emptyMessage: emptyMessage,
            results: controller.results,
            selectedItems: $controller.selectedItems,
            isScanning: controller.isScanning,
            scanProgress: controller.scanProgress,
            scanPhase: controller.scanPhase,
            scanComplete: controller.scanComplete,
            completion: controller.completion,
            cleaning: controller.cleaning,
            onScan: {
                if !controller.availableDefaultRoots.isEmpty {
                    controller.scanDefaultRoots()
                } else {
                    showPicker = true
                }
            },
            onClean: { controller.clean(engine: appState.cleaningEngine) },
            onCancelClean: { controller.cancelClean() },
            onReset: { controller.reset() },
            resultsContent: {
                AnyView(projectResultsList)
            }
        )
        .overlay(alignment: .bottom) {
            if !controller.isScanning && !controller.scanComplete && controller.completion == nil && !controller.availableDefaultRoots.isEmpty {
                Button {
                    showPicker = true
                } label: {
                    Label(
                        String(localized: "Choose Custom Folder…"),
                        systemImage: "folder.badge.plus"
                    )
                    .font(.system(size: 12.5, weight: .medium))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .padding(.bottom, 32)
            }
        }
        .fileImporter(
            isPresented: $showPicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                controller.runScan(root: url)
            }
        }
        .onDisappear {
            if controller.isScanning { controller.reset() }
        }
    }

    private var projectResultsList: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button(String(localized: "Select All")) {
                    controller.selectedItems = Set(controller.items.map { URL(filePath: $0.path, directoryHint: .isDirectory) })
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button(String(localized: "Select Clean Git Repos")) {
                    let cleanURLs = controller.items.filter { item in
                        guard let status = controller.gitStatuses[item.projectPath] else {
                            return false
                        }
                        return !status.hasUnsavedWork
                    }.map { URL(filePath: $0.path, directoryHint: .isDirectory) }
                    controller.selectedItems = Set(cleanURLs)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button(String(localized: "Deselect All")) {
                    controller.selectedItems.removeAll()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Spacer()

                Button {
                    showPicker = true
                } label: {
                    Label(
                        String(localized: "Choose Folder…"),
                        systemImage: "folder"
                    )
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(nsColor: .underPageBackgroundColor))

            Divider()

            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(controller.items) { item in
                        projectRow(item)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .background(Color(nsColor: .controlBackgroundColor))
        }
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
        )
    }

    private func projectRow(_ item: ProjectJunkItem) -> some View {
        let itemURL = URL(filePath: item.path, directoryHint: .isDirectory)
        let isSelected = controller.selectedItems.contains(itemURL)
        let gitStatus = controller.gitStatuses[item.projectPath]
        let projectName = (item.projectPath as NSString).lastPathComponent
        let folderName = (item.path as NSString).lastPathComponent
        return HStack(spacing: 12) {
            ReviewCheckbox(state: isSelected ? .on : .off) {
                if isSelected {
                    controller.selectedItems.remove(itemURL)
                } else {
                    controller.selectedItems.insert(itemURL)
                }
            }

            ReviewFileIcon(path: item.projectPath)
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(projectName)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                    Text("› \(folderName)")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Text(item.projectPath)
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 8)

            Text(item.kind.label)
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 7)
                .padding(.vertical, 2.5)
                .background(Color.primary.opacity(0.06), in: Capsule())

            if let gitStatus {
                gitBadge(gitStatus)
            }

            Text(FileSizeFormatter.format(item.bytes))
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .frame(width: 76, alignment: .trailing)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .contentShape(Rectangle())
        .onTapGesture {
            if isSelected {
                controller.selectedItems.remove(itemURL)
            } else {
                controller.selectedItems.insert(itemURL)
            }
        }
        .contextMenu {
            Button(String(localized: "Reveal in Finder")) {
                NSWorkspace.shared.activateFileViewerSelecting([itemURL])
            }
        }
    }

    @ViewBuilder
    private func gitBadge(_ status: GitRepoStatus) -> some View {
        let isWarning = status.hasUnsavedWork
        HStack(spacing: 4) {
            Image(systemName: isWarning ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                .font(.system(size: 10))
            Text(gitStatusSummary(status))
                .font(.system(size: 10.5, weight: .medium))
                .lineLimit(1)
        }
        .foregroundStyle(isWarning ? Color.orange : Color.green)
        .padding(.horizontal, 7)
        .padding(.vertical, 2.5)
        .background((isWarning ? Color.orange : Color.green).opacity(0.12), in: Capsule())
        .help(
            isWarning
                ? String(localized: "This Git repository has uncommitted or unpushed changes")
                : String(localized: "Working tree clean")
        )
    }

    private func gitStatusSummary(_ status: GitRepoStatus) -> String {
        var parts: [String] = []
        if status.dirty > 0 {
            parts.append("\(status.dirty) dirty")
        }
        if status.ahead > 0 {
            parts.append("↑\(status.ahead)")
        }
        if !status.hasUpstream {
            parts.append(String(localized: "unpushed"))
        }
        if parts.isEmpty {
            return status.branch
        }
        return parts.joined(separator: " · ")
    }
}
