import AppKit
import SwiftUI
import MacCleanKit

struct UnusedAppsView: View {
    @Environment(AppState.self) private var appState
    @State private var horizon: UnusedAppHorizon = .sixMonths
    @State private var records: [UnusedAppRecord] = []
    @State private var selectedPaths: Set<String> = []
    @State private var isLoading = true
    @State private var isUninstalling = false
    @State private var showBatchConfirm = false
    @State private var loadGeneration = 0

    private let discovery = AppDiscovery()
    private let pathFinder = AppPathFinder()
    private let safetyGuard = SafetyGuard()

    private var apps: [UnusedAppRecord] { UnusedApps.unused(from: records, horizon: horizon) }

    private var selectedApps: [UnusedAppRecord] {
        apps.filter { selectedPaths.contains($0.path) }
    }

    private var selectedTotalBytes: UInt64 {
        selectedApps.reduce(0) { $0 + $1.totalBytes }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Unused Apps")
                        .font(.system(size: 20, weight: .semibold))
                    Text("Apps you have not opened recently, sorted by how much space they use. One click hands them to the Uninstaller.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if !isLoading && !apps.isEmpty {
                    Button("Select All") {
                        selectedPaths = Set(apps.map(\.path))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .keyboardShortcut("a", modifiers: .command)

                    Button("Deselect All") {
                        selectedPaths.removeAll()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(selectedPaths.isEmpty)
                    .keyboardShortcut("a", modifiers: [.command, .option])
                }
                Picker("Horizon", selection: $horizon) {
                    ForEach(UnusedAppHorizon.allCases) { h in
                        Text(h.label).tag(h)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 240)
                Button {
                    Task { await reload() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(isLoading)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)

            VStack(spacing: 0) {
                if isLoading || isUninstalling {
                    VStack(spacing: 12) {
                        Spacer()
                        ProgressView().controlSize(.large)
                        Text(isUninstalling ? "Uninstalling…" : "Looking for unused apps…")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if UnusedApps.usageDataUnavailable(in: records) {
                    VStack(spacing: 8) {
                        Spacer()
                        Text("Spotlight has no usage history for your apps")
                            .font(.system(size: 13, weight: .medium))
                        Text("Mac Sai can't tell which apps are unused. Check that Spotlight indexing is turned on.")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if apps.isEmpty {
                    VStack {
                        Spacer()
                        Text("No unused apps in this window")
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(apps) { app in
                        HStack(spacing: 12) {
                            Toggle("", isOn: Binding(
                                get: { selectedPaths.contains(app.path) },
                                set: { on in
                                    if on { selectedPaths.insert(app.path) }
                                    else { selectedPaths.remove(app.path) }
                                }
                            ))
                            .toggleStyle(.checkbox)
                            .labelsHidden()

                            Image(nsImage: NSWorkspace.shared.icon(forFile: app.path))
                                .resizable()
                                .frame(width: 28, height: 28)
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(app.name)
                                        .font(.system(size: 13, weight: .medium))
                                    if app.runsInBackground {
                                        Text("Background")
                                            .font(.system(size: 10))
                                            .padding(.horizontal, 5)
                                            .padding(.vertical, 1)
                                            .background(Color.secondary.opacity(0.12))
                                            .clipShape(Capsule())
                                    }
                                }
                                Text(subtitle(for: app))
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(FileSizeFormatter.format(app.totalBytes))
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.secondary)
                            Button("Uninstall…") {
                                appState.openUninstaller(forAppPath: app.path)
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding(.vertical, 2)
                    }
                    .listStyle(.inset)
                }

                if !selectedApps.isEmpty && !isLoading && !isUninstalling {
                    Divider()
                    HStack(spacing: 12) {
                        Text("\(selectedApps.count) app\(selectedApps.count == 1 ? "" : "s") selected · \(FileSizeFormatter.format(selectedTotalBytes))")
                            .font(.system(size: 12.5, weight: .medium))
                        Spacer()
                        Button("Deselect All") {
                            selectedPaths.removeAll()
                        }
                        .buttonStyle(.bordered)

                        Button("Move to Trash (\(selectedApps.count))") {
                            showBatchConfirm = true
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
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
        .background(Color.white)
        .task { await reload() }
        .respondsToModuleShortcuts(
            onScan: { Task { await reload() } },
            onClean: { showBatchConfirm = true },
            canScan: !isLoading && !isUninstalling,
            canClean: !selectedApps.isEmpty
        )
        .alert("Move \(selectedApps.count) app\(selectedApps.count == 1 ? "" : "s") to the Trash?",
               isPresented: $showBatchConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Move to Trash", role: .destructive) {
                uninstallSelectedApps()
            }
        } message: {
            Text("Selected unused applications and their associated support files will be moved to the Trash.")
        }
    }

    private func subtitle(for app: UnusedAppRecord) -> String {
        let last: String
        if let date = app.lastUsed {
            last = date.formatted(date: .abbreviated, time: .omitted)
        } else {
            last = String(localized: "Unknown")
        }
        let support = FileSizeFormatter.format(app.supportBytes)
        let lastLabel = String(localized: "Last opened")
        let supportLabel = String(localized: "Support files")
        return "\(lastLabel) \(last) · \(supportLabel) \(support)"
    }

    private func reload() async {
        loadGeneration &+= 1
        let generation = loadGeneration
        isLoading = true
        let running = Set(NSWorkspace.shared.runningApplications.compactMap {
            $0.bundleURL?.path(percentEncoded: false)
        })
        let listed = await Task.detached {
            await UnusedAppsClient().records(runningAppPaths: running)
        }.value
        guard generation == loadGeneration else { return }
        records = listed
        selectedPaths = selectedPaths.intersection(Set(listed.map(\.path)))
        isLoading = false
    }

    private func uninstallSelectedApps() {
        let pathsToRemove = selectedPaths
        guard !pathsToRemove.isEmpty, !isUninstalling else { return }
        isUninstalling = true
        Task {
            let discovered = await discovery.discoverApps()
            var allItems: [FileItem] = []
            var allSelection: Set<URL> = []
            for app in discovered where pathsToRemove.contains(app.path.path(percentEncoded: false)) {
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
                _ = await CleanActions.executeUserClean(
                    items: allItems,
                    selectedItems: allSelection,
                    engine: appState.cleaningEngine
                )
            }
            selectedPaths.removeAll()
            isUninstalling = false
            await reload()
        }
    }
}
