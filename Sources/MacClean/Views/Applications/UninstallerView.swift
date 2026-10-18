import SwiftUI
import AppKit
import MacCleanKit

struct UninstallerView: View {
    @Environment(AppState.self) private var appState
    @State private var apps: [AppInfo] = []
    @State private var selectedApp: AppInfo?
    @State private var checkedAppIDs: Set<UUID> = []
    @State private var associatedFiles: [FileItem] = []
    @State private var selectedFiles: Set<URL> = []
    @State private var isLoading = true
    @State private var isLoadingFiles = false
    @State private var isUninstalling = false
    @State private var isResetting = false
    @State private var appPendingUninstall: AppInfo?
    @State private var appPendingReset: AppInfo?
    @State private var showBatchConfirm = false
    @State private var uninstallError: String?
    @State private var resetError: String?
    @State private var filter: AppFilter = .all
    @State private var searchText = ""

    enum AppFilter: String, CaseIterable {
        case all = "All"
        case unused = "Unused"
        case thirdParty = "Third-party"

        var label: String { String(localized: rawValue) }
    }

    private let discovery = AppDiscovery()
    private let pathFinder = AppPathFinder()
    private let safetyGuard = SafetyGuard()

    private var checkedApps: [AppInfo] {
        apps.filter { checkedAppIDs.contains($0.id) && !safetyGuard.isProtectedApp($0.bundleIdentifier) }
    }

    private var checkedTotalSize: UInt64 {
        checkedApps.reduce(0) { $0 + $1.size }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Uninstaller")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text("Completely remove apps and their leftover files")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if !isLoading && !filteredApps.isEmpty {
                    HStack(spacing: 8) {
                        Button("Select All") {
                            for app in filteredApps where !safetyGuard.isProtectedApp(app.bundleIdentifier) {
                                checkedAppIDs.insert(app.id)
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .keyboardShortcut("a", modifiers: .command)

                        Button("Deselect All") {
                            checkedAppIDs.removeAll()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(checkedAppIDs.isEmpty)
                        .keyboardShortcut("a", modifiers: [.command, .option])
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)

            if isLoading {
                Spacer()
                VStack(spacing: 12) {
                    ProgressView()
                        .controlSize(.large)
                    Text("Discovering installed apps...")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            } else {
                HStack(spacing: 10) {
                    TextField("Search apps...", text: $searchText)
                        .textFieldStyle(.roundedBorder)

                    Picker("Filter", selection: $filter) {
                        ForEach(AppFilter.allCases, id: \.self) { f in
                            Text(f.label).tag(f)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 240)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 10)

                VStack(spacing: 0) {
                    HSplitView {
                        appList
                            .frame(minWidth: 260)

                        if let app = selectedApp {
                            appDetailView(app)
                                .frame(minWidth: 300)
                                .background(Color.white)
                        } else {
                            VStack {
                                Spacer()
                                Text("Select an app to see its files")
                                    .foregroundStyle(.secondary)
                                    .font(.system(size: 13))
                                Spacer()
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color.white)
                        }
                    }

                    if !checkedApps.isEmpty {
                        Divider()
                        HStack(spacing: 12) {
                            Text("\(checkedApps.count) app\(checkedApps.count == 1 ? "" : "s") selected · \(FileSizeFormatter.format(checkedTotalSize))")
                                .font(.system(size: 12.5, weight: .medium))
                                .foregroundStyle(.primary)
                            Spacer()
                            Button("Deselect All") {
                                checkedAppIDs.removeAll()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.regular)

                            Button("Uninstall (\(checkedApps.count))") {
                                showBatchConfirm = true
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.red)
                            .controlSize(.regular)
                            .disabled(isUninstalling)
                        }
                        .padding(.horizontal, 16)
                        .frame(height: 48)
                        .background(Color(white: 0.975))
                    }
                }
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1)
                )
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
        .background(Color.white)
        .task { await loadApps() }
        .respondsToModuleShortcuts(
            onScan: { Task { await loadApps() } },
            onClean: {
                if !checkedApps.isEmpty {
                    showBatchConfirm = true
                } else if let app = selectedApp, !safetyGuard.isProtectedApp(app.bundleIdentifier) {
                    appPendingUninstall = app
                }
            },
            canScan: !isLoading && !isUninstalling,
            canClean: !checkedApps.isEmpty || (selectedApp != nil && !safetyGuard.isProtectedApp(selectedApp?.bundleIdentifier ?? ""))
        )
        .onChange(of: appState.pendingUninstallerAppPath) { _, path in
            guard let path else { return }
            selectPendingApp(path: path)
        }
        .alert("Move \(checkedApps.count) app\(checkedApps.count == 1 ? "" : "s") to the Trash?",
               isPresented: $showBatchConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Move to Trash", role: .destructive) {
                uninstallBatch(checkedApps)
            }
        } message: {
            Text("Selected applications and their associated support files will be moved to the Trash.")
        }
        .alert("Move \(appPendingUninstall?.name ?? "this app") to the Trash?",
               isPresented: Binding(get: { appPendingUninstall != nil },
                                    set: { if !$0 { appPendingUninstall = nil } }),
               presenting: appPendingUninstall) { app in
            Button("Cancel", role: .cancel) { appPendingUninstall = nil }
            Button("Move to Trash", role: .destructive) {
                let target = app; appPendingUninstall = nil; uninstall(target)
            }
        } message: { app in
            Text("\(app.name) and its associated files will be moved to the Trash. You can restore them from the Trash if needed.")
        }
        .alert("Uninstall",
               isPresented: Binding(get: { uninstallError != nil },
                                    set: { if !$0 { uninstallError = nil } })) {
            Button("OK", role: .cancel) { uninstallError = nil }
        } message: {
            Text(uninstallError ?? "")
        }
        .alert(
            "Reset \(appPendingReset?.name ?? "this app") to defaults?",
            isPresented: Binding(get: { appPendingReset != nil },
                                 set: { if !$0 { appPendingReset = nil } }),
            presenting: appPendingReset
        ) { app in
            Button("Cancel", role: .cancel) { appPendingReset = nil }
            Button("Reset to Defaults", role: .destructive) {
                let target = app; appPendingReset = nil; resetToDefaults(target)
            }
        } message: { app in
            let plan = AppReset.plan(app: app, associatedFiles: associatedFiles, selectedFiles: selectedFiles)
            let count = plan?.items.count ?? 0
            let bytes = plan?.items.reduce(0 as UInt64) { $0 + $1.size } ?? 0
            Text("Caches, preferences, and saved state for \(app.name) (\(count) items, \(FileSizeFormatter.format(bytes))) will be moved to the Trash. The app stays installed. Quit the app first if it is running, or it may rewrite these files.")
        }
        .alert("Reset to Defaults",
               isPresented: Binding(get: { resetError != nil },
                                    set: { if !$0 { resetError = nil } })) {
            Button("OK", role: .cancel) { resetError = nil }
        } message: {
            Text(resetError ?? "")
        }
    }

    private var filteredApps: [AppInfo] {
        var filtered = apps
        switch filter {
        case .all: break
        case .unused: filtered = filtered.filter(\.isUnused)
        case .thirdParty: filtered = filtered.filter { !$0.isAppleApp }
        }
        if !searchText.isEmpty {
            filtered = filtered.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.bundleIdentifier.localizedCaseInsensitiveContains(searchText)
            }
        }
        return filtered
    }

    private var appList: some View {
        List {
            ForEach(filteredApps) { app in
                let isProtected = safetyGuard.isProtectedApp(app.bundleIdentifier)
                HStack(spacing: 8) {
                    Toggle("", isOn: Binding(
                        get: { checkedAppIDs.contains(app.id) },
                        set: { on in
                            if on { checkedAppIDs.insert(app.id) }
                            else { checkedAppIDs.remove(app.id) }
                        }
                    ))
                    .toggleStyle(.checkbox)
                    .labelsHidden()
                    .disabled(isProtected)

                    Button {
                        selectedApp = app
                        loadAssociatedFiles(for: app)
                    } label: {
                        HStack(spacing: 10) {
                            Image(nsImage: NSWorkspace.shared.icon(forFile: app.path.path(percentEncoded: false)))
                                .resizable()
                                .frame(width: 24, height: 24)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(app.name)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(.primary)
                                Text(app.formattedSize)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            if app.isUnused {
                                Text("Unused")
                                    .font(.system(size: 10))
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1)
                                    .background(Color.secondary.opacity(0.12))
                                    .clipShape(Capsule())
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 2)
                .padding(.horizontal, 4)
                .background(selectedApp?.id == app.id ? Color(nsColor: .systemBlue).opacity(0.12) : .clear)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
        .listStyle(.inset)
    }

    private func appDetailView(_ app: AppInfo) -> some View {
        VStack(spacing: 12) {
            HStack {
                Image(nsImage: NSWorkspace.shared.icon(forFile: app.path.path(percentEncoded: false)))
                    .resizable()
                    .frame(width: 32, height: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(app.name).font(.headline)
                    Text(app.bundleIdentifier).font(.caption).foregroundStyle(.secondary)
                    if let version = app.version {
                        Text("v\(version)").font(.caption2).foregroundStyle(.tertiary)
                    }
                }
                Spacer()

                if isUninstalling || isResetting {
                    ProgressView()
                        .controlSize(.small)
                    Text(isResetting
                         ? String(localized: "Resetting…")
                         : String(localized: "Uninstalling…"))
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                } else {
                    if safetyGuard.isProtectedApp(app.bundleIdentifier) {
                        Text("Protected system app — can't be removed")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    } else {
                        Button("Uninstall") { appPendingUninstall = app }
                            .buttonStyle(.borderedProminent)
                            .tint(.red)
                            .controlSize(.small)
                    }

                    Button("Reset to Defaults") {
                        appPendingReset = app
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(AppReset.plan(app: app, associatedFiles: associatedFiles, selectedFiles: selectedFiles) == nil)
                    .help("Clears caches, preferences, and saved state. The app stays installed.")
                }
            }
            .padding()

            if isLoadingFiles {
                Spacer()
                ProgressView("Finding associated files...")
                    .tint(.secondary)
                    .font(.system(size: 12))
                Spacer()
            } else if !associatedFiles.isEmpty {
                let totalSize = associatedFiles.reduce(0 as UInt64) { $0 + $1.size }
                HStack {
                    Text("\(associatedFiles.count) associated files (\(FileSizeFormatter.format(totalSize)))")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Select All") {
                        selectedFiles = Set(associatedFiles.map(\.url))
                    }
                    .buttonStyle(.borderless)
                    .font(.system(size: 11))
                    Button("None") {
                        selectedFiles.removeAll()
                    }
                    .buttonStyle(.borderless)
                    .font(.system(size: 11))
                }
                .padding(.horizontal)

                List(associatedFiles) { file in
                    HStack {
                        Toggle("", isOn: Binding(
                            get: { selectedFiles.contains(file.url) },
                            set: { on in
                                if on { selectedFiles.insert(file.url) }
                                else { selectedFiles.remove(file.url) }
                            }
                        ))
                        .toggleStyle(.checkbox)
                        .labelsHidden()

                        Image(systemName: file.isDirectory ? "folder" : "doc")
                            .foregroundStyle(.secondary)
                            .font(.system(size: 12))

                        VStack(alignment: .leading, spacing: 1) {
                            Text(file.name).font(.system(size: 12))
                            Text(file.url.deletingLastPathComponent().path(percentEncoded: false))
                                .font(.system(size: 10))
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                        }

                        Spacer()
                        Text(file.formattedSize)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
                .listStyle(.inset)
            } else {
                Spacer()
                Text("No associated files found")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 12))
                Spacer()
            }
        }
    }

    private func resetToDefaults(_ app: AppInfo) {
        guard !isResetting, !isUninstalling else { return }
        guard let plan = AppReset.plan(
            app: app,
            associatedFiles: associatedFiles,
            selectedFiles: selectedFiles
        ) else { return }

        isResetting = true
        Task {
            let result = await CleanActions.executeUserClean(
                items: plan.items,
                selectedItems: plan.selection,
                engine: appState.cleaningEngine
            )
            if !result.errors.isEmpty {
                resetError = "Some items couldn't be reset for \(app.name) (\(result.errors.count)). Quit the app if it is running and try again."
            }
            loadAssociatedFiles(for: app)
            isResetting = false
        }
    }

    private func loadApps() async {
        apps = await discovery.discoverApps()
        checkedAppIDs = checkedAppIDs.intersection(Set(apps.map(\.id)))
        isLoading = false
        if let path = appState.pendingUninstallerAppPath {
            selectPendingApp(path: path)
        }
    }

    private func selectPendingApp(path: String) {
        appState.pendingUninstallerAppPath = nil
        guard let match = apps.first(where: {
            $0.path.path(percentEncoded: false) == path
        }) else { return }
        selectedApp = match
        loadAssociatedFiles(for: match)
        filter = .all
    }

    private func loadAssociatedFiles(for app: AppInfo) {
        isLoadingFiles = true
        associatedFiles = []
        Task {
            let files = pathFinder.findAssociatedFiles(for: app)
            associatedFiles = files
            selectedFiles = Set(files.map(\.url))
            isLoadingFiles = false
        }
    }

    private func uninstall(_ app: AppInfo) {
        guard !isUninstalling else { return }
        guard let plan = AppUninstaller.plan(
            app: app,
            associatedFiles: associatedFiles,
            selectedFiles: selectedFiles,
            safetyGuard: safetyGuard
        ) else {
            uninstallError = "\(app.name) is a protected system app and can't be removed."
            return
        }

        isUninstalling = true
        Task {
            let result = await CleanActions.executeUserClean(
                items: plan.items,
                selectedItems: plan.selection,
                engine: appState.cleaningEngine
            )
            if !result.errors.isEmpty {
                uninstallError = "Some items couldn't be removed while uninstalling \(app.name) (\(result.errors.count)). Check whether the app is still there and try again."
            }
            checkedAppIDs.remove(app.id)
            await loadApps()
            isUninstalling = false
            selectedApp = nil
            associatedFiles = []
        }
    }

    private func uninstallBatch(_ targets: [AppInfo]) {
        guard !isUninstalling, !targets.isEmpty else { return }
        isUninstalling = true
        Task {
            var allItems: [FileItem] = []
            var allSelection: Set<URL> = []
            for app in targets {
                let files = pathFinder.findAssociatedFiles(for: app)
                let fileURLs = Set(files.map(\.url))
                if let plan = AppUninstaller.plan(
                    app: app,
                    associatedFiles: files,
                    selectedFiles: fileURLs,
                    safetyGuard: safetyGuard
                ) {
                    allItems.append(contentsOf: plan.items)
                    allSelection.formUnion(plan.selection)
                }
            }
            if !allItems.isEmpty {
                let result = await CleanActions.executeUserClean(
                    items: allItems,
                    selectedItems: allSelection,
                    engine: appState.cleaningEngine
                )
                if !result.errors.isEmpty {
                    uninstallError = "Some items couldn't be removed (\(result.errors.count))."
                }
            }
            checkedAppIDs.removeAll()
            await loadApps()
            isUninstalling = false
            selectedApp = nil
            associatedFiles = []
        }
    }
}
