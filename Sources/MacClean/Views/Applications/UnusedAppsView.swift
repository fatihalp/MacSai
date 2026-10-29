import AppKit
import SwiftUI
import MacCleanKit

struct UnusedAppsView: View {
    @Environment(AppState.self) private var appState
    @Bindable var controller: UnusedAppsController
    @State private var showBatchConfirm = false

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
                if !controller.isLoading && !controller.apps.isEmpty {
                    Button("Select All") {
                        controller.selectedPaths = Set(controller.apps.map(\.path))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .keyboardShortcut("a", modifiers: .command)

                    Button("Deselect All") {
                        controller.selectedPaths.removeAll()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(controller.selectedPaths.isEmpty)
                    .keyboardShortcut("a", modifiers: [.command, .option])
                }
                Picker("Horizon", selection: $controller.horizon) {
                    ForEach(UnusedAppHorizon.allCases) { h in
                        Text(h.label).tag(h)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 240)
                Button {
                    Task { await controller.reload() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(controller.isLoading)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)

            VStack(spacing: 0) {
                if controller.isLoading || controller.isUninstalling {
                    VStack(spacing: 12) {
                        Spacer()
                        ProgressView().controlSize(.large)
                        Text(controller.isUninstalling ? "Uninstalling…" : "Looking for unused apps…")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if UnusedApps.usageDataUnavailable(in: controller.records) {
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
                } else if controller.apps.isEmpty {
                    VStack {
                        Spacer()
                        Text("No unused apps in this window")
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(controller.apps) { app in
                        HStack(spacing: 12) {
                            Toggle("", isOn: Binding(
                                get: { controller.selectedPaths.contains(app.path) },
                                set: { on in
                                    if on { controller.selectedPaths.insert(app.path) }
                                    else { controller.selectedPaths.remove(app.path) }
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

                if !controller.selectedApps.isEmpty && !controller.isLoading && !controller.isUninstalling {
                    Divider()
                    HStack(spacing: 12) {
                        Text("\(controller.selectedApps.count) app\(controller.selectedApps.count == 1 ? "" : "s") selected · \(FileSizeFormatter.format(controller.selectedTotalBytes))")
                            .font(.system(size: 12.5, weight: .medium))
                        Spacer()
                        Button("Deselect All") {
                            controller.selectedPaths.removeAll()
                        }
                        .buttonStyle(.bordered)

                        Button("Move to Trash (\(controller.selectedApps.count))") {
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
        .task { await controller.reload() }
        .respondsToModuleShortcuts(
            onScan: { Task { await controller.reload() } },
            onClean: { showBatchConfirm = true },
            canScan: !controller.isLoading && !controller.isUninstalling,
            canClean: !controller.selectedApps.isEmpty
        )
        .alert("Move \(controller.selectedApps.count) app\(controller.selectedApps.count == 1 ? "" : "s") to the Trash?",
               isPresented: $showBatchConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Move to Trash", role: .destructive) {
                controller.uninstallSelectedApps()
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
}
