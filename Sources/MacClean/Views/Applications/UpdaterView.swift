import SwiftUI
import AppKit
import MacCleanKit

struct UpdaterView: View {
    @AppStorage("removeBackgroundColors") private var removeBackgroundColors = false
    @State private var updates: [AppUpdateChecker.AppUpdate] = []
    @State private var isChecking = false
    @State private var hasChecked = false
    @State private var apps: [AppInfo] = []

    @State private var updatingIDs: Set<UUID> = []

    private let discovery = AppDiscovery()
    private let checker = AppUpdateChecker()

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Updater")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.primary)
                    Text("Check for available app updates")
                        .font(.system(size: 12))
                        .foregroundStyle(.primary.opacity(0.6))
                }
                Spacer()
                if !isChecking {
                    Button(hasChecked ? "Recheck" : "Check for Updates") {
                        checkUpdates()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color(nsColor: .systemBlue))
                    .controlSize(.regular)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)

            if isChecking {
                Spacer()
                ScanProgressRing(progress: 0.5, phase: "Checking for updates...", theme: .applications)
                Spacer()
            } else if hasChecked && updates.isEmpty {
                Spacer()
                VStack(spacing: 14) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(.primary.opacity(0.8))
                    Text("All apps are up to date")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.primary.opacity(0.7))
                }
                Spacer()
            } else if !updates.isEmpty {
                List {
                    ForEach(updates) { update in
                        HStack {
                            Image(nsImage: NSWorkspace.shared.icon(forFile: update.app.path.path(percentEncoded: false)))
                                .resizable()
                                .frame(width: 26, height: 26)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(update.app.name)
                                    .font(.system(size: 13, weight: .medium))
                                Text("\(update.currentVersion) → \(update.availableVersion ?? "?")")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            if updatingIDs.contains(update.id) {
                                ProgressView()
                                    .controlSize(.small)
                                    .frame(width: 60)
                            } else {
                                Button("Update") { startUpdate(update) }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                            }
                        }
                    }
                }
                .listStyle(.inset)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1)
                )
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            } else {
                Spacer()
                VStack(spacing: 14) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 44))
                        .foregroundStyle(.primary.opacity(0.4))
                    Text("Click above to check for updates")
                        .font(.system(size: 14))
                        .foregroundStyle(.primary.opacity(0.55))
                }
                Spacer()
            }
        }
    }

    private func checkUpdates() {
        isChecking = true
        Task {
            apps = await discovery.discoverApps()
            updates = await checker.checkForUpdates(apps: apps)
            isChecking = false
            hasChecked = true
        }
    }

    private func startUpdate(_ update: AppUpdateChecker.AppUpdate) {
        guard !updatingIDs.contains(update.id) else { return }
        updatingIDs.insert(update.id)
        Task {
            UpdaterActions.perform(update)
            try? await Task.sleep(for: .milliseconds(1200))
            updatingIDs.remove(update.id)
        }
    }
}
