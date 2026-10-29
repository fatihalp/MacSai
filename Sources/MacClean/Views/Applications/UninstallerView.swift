import SwiftUI
import AppKit
import MacCleanKit

struct UninstallerView: View {
    @Bindable var controller: UninstallerController
    @Environment(AppState.self) private var appState
    @State private var appPendingUninstall: AppInfo?
    @State private var appPendingReset: AppInfo?
    @State private var showBatchConfirm = false

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
                if !controller.isLoading && !controller.filteredApps.isEmpty {
                    HStack(spacing: 8) {
                        Button("Select All") {
                            for app in controller.filteredApps where !controller.safetyGuard.isProtectedApp(app.bundleIdentifier) {
                                controller.checkedAppIDs.insert(app.id)
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .keyboardShortcut("a", modifiers: .command)

                        Button("Deselect All") {
                            controller.checkedAppIDs.removeAll()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(controller.checkedAppIDs.isEmpty)
                        .keyboardShortcut("a", modifiers: [.command, .option])
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)

            if controller.isLoading {
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
                    TextField("Search apps...", text: $controller.searchText)
                        .textFieldStyle(.roundedBorder)

                    Picker("Filter", selection: $controller.filter) {
                        ForEach(UninstallerController.AppFilter.allCases, id: \.self) { f in
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

                        if let app = controller.selectedApp {
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

                    if !controller.checkedApps.isEmpty {
                        Divider()
                        HStack(spacing: 12) {
                            Text("\(controller.checkedApps.count) app\(controller.checkedApps.count == 1 ? "" : "s") selected · \(FileSizeFormatter.format(controller.checkedTotalSize))")
                                .font(.system(size: 12.5, weight: .medium))
                                .foregroundStyle(.primary)
                            Spacer()
                            Button("Deselect All") {
                                controller.checkedAppIDs.removeAll()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.regular)

                            Button("Uninstall (\(controller.checkedApps.count))") {
                                showBatchConfirm = true
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.red)
                            .controlSize(.regular)
                            .disabled(controller.isUninstalling)
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
        .task {
            await controller.loadApps()
            if let path = appState.pendingUninstallerAppPath {
                appState.pendingUninstallerAppPath = nil
                controller.selectPendingApp(path: path)
            }
        }
        .respondsToModuleShortcuts(
            onScan: { Task { await controller.loadApps() } },
            onClean: {
                if !controller.checkedApps.isEmpty {
                    showBatchConfirm = true
                } else if let app = controller.selectedApp, !controller.safetyGuard.isProtectedApp(app.bundleIdentifier) {
                    appPendingUninstall = app
                }
            },
            canScan: !controller.isLoading && !controller.isUninstalling,
            canClean: !controller.checkedApps.isEmpty || (controller.selectedApp != nil && !controller.safetyGuard.isProtectedApp(controller.selectedApp?.bundleIdentifier ?? ""))
        )
        .onChange(of: appState.pendingUninstallerAppPath) { _, path in
            guard let path else { return }
            appState.pendingUninstallerAppPath = nil
            controller.selectPendingApp(path: path)
        }
        .alert("Move \(controller.checkedApps.count) app\(controller.checkedApps.count == 1 ? "" : "s") to the Trash?",
               isPresented: $showBatchConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Move to Trash", role: .destructive) {
                controller.uninstallBatch(controller.checkedApps)
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
                let target = app; appPendingUninstall = nil; controller.uninstall(target)
            }
        } message: { app in
            Text("\(app.name) and its associated files will be moved to the Trash. You can restore them from the Trash if needed.")
        }
        .alert("Uninstall",
               isPresented: Binding(get: { controller.uninstallError != nil },
                                    set: { if !$0 { controller.uninstallError = nil } })) {
            Button("OK", role: .cancel) { controller.uninstallError = nil }
        } message: {
            Text(controller.uninstallError ?? "")
        }
        .alert(
            "Reset \(appPendingReset?.name ?? "this app") to defaults?",
            isPresented: Binding(get: { appPendingReset != nil },
                                 set: { if !$0 { appPendingReset = nil } }),
            presenting: appPendingReset
        ) { app in
            Button("Cancel", role: .cancel) { appPendingReset = nil }
            Button("Reset to Defaults", role: .destructive) {
                let target = app; appPendingReset = nil; controller.resetToDefaults(target)
            }
        } message: { app in
            let plan = AppReset.plan(app: app, associatedFiles: controller.associatedFiles, selectedFiles: controller.selectedFiles)
            let count = plan?.items.count ?? 0
            let bytes = plan?.items.reduce(0 as UInt64) { $0 + $1.size } ?? 0
            Text("Caches, preferences, and saved state for \(app.name) (\(count) items, \(FileSizeFormatter.format(bytes))) will be moved to the Trash. The app stays installed. Quit the app first if it is running, or it may rewrite these files.")
        }
        .alert("Reset to Defaults",
               isPresented: Binding(get: { controller.resetError != nil },
                                    set: { if !$0 { controller.resetError = nil } })) {
            Button("OK", role: .cancel) { controller.resetError = nil }
        } message: {
            Text(controller.resetError ?? "")
        }
    }

    private var appList: some View {
        List {
            ForEach(controller.filteredApps) { app in
                let isProtected = controller.safetyGuard.isProtectedApp(app.bundleIdentifier)
                HStack(spacing: 8) {
                    Toggle("", isOn: Binding(
                        get: { controller.checkedAppIDs.contains(app.id) },
                        set: { on in
                            if on { controller.checkedAppIDs.insert(app.id) }
                            else { controller.checkedAppIDs.remove(app.id) }
                        }
                    ))
                    .toggleStyle(.checkbox)
                    .labelsHidden()
                    .disabled(isProtected)

                    Button {
                        controller.selectedApp = app
                        controller.loadAssociatedFiles(for: app)
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
                .background(controller.selectedApp?.id == app.id ? Color(nsColor: .systemBlue).opacity(0.12) : .clear)
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

                if controller.isUninstalling || controller.isResetting {
                    ProgressView()
                        .controlSize(.small)
                    Text(controller.isResetting
                         ? String(localized: "Resetting…")
                         : String(localized: "Uninstalling…"))
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                } else {
                    if controller.safetyGuard.isProtectedApp(app.bundleIdentifier) {
                        Text("Protected system app — can't be removed")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    } else {
                        Button("Uninstall") { appPendingUninstall = app }
                            .buttonStyle(.borderedProminent)
                            .tint(.red)
                            .controlSize(.small)
                            .disabled(controller.isLoadingFiles)
                    }

                    Button("Reset to Defaults") {
                        appPendingReset = app
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(AppReset.plan(app: app, associatedFiles: controller.associatedFiles, selectedFiles: controller.selectedFiles) == nil)
                    .help("Clears caches, preferences, and saved state. The app stays installed.")
                }
            }
            .padding()

            if controller.isLoadingFiles {
                Spacer()
                ProgressView("Finding associated files...")
                    .tint(.secondary)
                    .font(.system(size: 12))
                Spacer()
            } else if !controller.associatedFiles.isEmpty {
                let totalSize = controller.associatedFiles.reduce(0 as UInt64) { $0 + $1.size }
                HStack {
                    Text("\(controller.associatedFiles.count) associated files (\(FileSizeFormatter.format(totalSize)))")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Select All") {
                        controller.selectedFiles = Set(controller.associatedFiles.map(\.url))
                    }
                    .buttonStyle(.borderless)
                    .font(.system(size: 11))
                    Button("None") {
                        controller.selectedFiles.removeAll()
                    }
                    .buttonStyle(.borderless)
                    .font(.system(size: 11))
                }
                .padding(.horizontal)

                List(controller.associatedFiles) { file in
                    HStack {
                        Toggle("", isOn: Binding(
                            get: { controller.selectedFiles.contains(file.url) },
                            set: { on in
                                if on { controller.selectedFiles.insert(file.url) }
                                else { controller.selectedFiles.remove(file.url) }
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
}
