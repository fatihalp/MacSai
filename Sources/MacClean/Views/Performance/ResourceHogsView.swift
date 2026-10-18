import SwiftUI
import AppKit
import MacCleanKit

struct ResourceHogsView: View {
    @State private var rows: [ResourceHogRow] = []
    @State private var sortBy: ResourceHogsPolicy.SortKey = .cpu
    @State private var isLoading = true
    @State private var pendingQuit: ResourceHogRow?
    @State private var showQuitConfirm = false
    @State private var statusMessage: String?
    @State private var showStatus = false

    private let collector = ProcessStatsCollector()
    private let monitor = ProcessMonitor()
    private let listLimit = 40

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Picker(String(localized: "Sort"), selection: $sortBy) {
                    Text("CPU").tag(ResourceHogsPolicy.SortKey.cpu)
                    Text("Memory").tag(ResourceHogsPolicy.SortKey.memory)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(maxWidth: 220)

                Spacer()

                Text("Force Quit asks for confirmation first")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Group {
                if isLoading && rows.isEmpty {
                    VStack(spacing: 12) {
                        Spacer()
                        ProgressView()
                            .controlSize(.large)
                            .tint(.primary)
                        Text("Reading processes…")
                            .font(.system(size: 13))
                            .foregroundStyle(.primary.opacity(0.6))
                        Spacer()
                    }
                } else if rows.isEmpty {
                    VStack(spacing: 8) {
                        Spacer()
                        Image(systemName: "gauge.with.dots.needle.67percent")
                            .font(.system(size: 32))
                            .foregroundStyle(.tertiary)
                        Text("No apps to show")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    List {
                        ForEach(rows) { row in
                            ResourceHogRowView(row: row) {
                                pendingQuit = row
                                showQuitConfirm = true
                            }
                        }
                    }
                    .listStyle(.inset)
                }
            }
        }
        .task {
            await refresh()

            try? await Task.sleep(nanoseconds: 1_200_000_000)
            await refresh()
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 2_500_000_000)
                await refresh()
            }
        }
        .onChange(of: sortBy) { _, _ in
            Task { await refresh() }
        }
        .alert(
            "Force Quit \(pendingQuit?.snapshot.name ?? "")?",
            isPresented: $showQuitConfirm
        ) {
            Button(String(localized: "Cancel"), role: .cancel) {
                pendingQuit = nil
            }
            Button(String(localized: "Force Quit"), role: .destructive) {
                quitPending()
            }
        } message: {
            Text("Unsaved work may be lost.")
        }
        .alert(statusMessage ?? "", isPresented: $showStatus) {
            Button("OK") { showStatus = false }
        }
    }

    @MainActor
    private func refresh() async {
        let stats = await collector.getProcessStats()
        let snapshots = stats.map {
            ResourceHogSnapshot(
                pid: $0.id,
                name: $0.name,
                cpuPercent: $0.cpuPercent,
                memoryBytes: $0.memoryBytes,
                bundleIdentifier: $0.bundleIdentifier
            )
        }
        rows = ResourceHogsPolicy.rows(from: snapshots, sortBy: sortBy, limit: listLimit)
        isLoading = false
    }

    private func quitPending() {
        guard let row = pendingQuit else { return }
        pendingQuit = nil
        guard row.canQuit else {
            statusMessage = String(localized: "That process is protected and cannot be quit.")
            showStatus = true
            return
        }

        guard let live = NSRunningApplication(processIdentifier: row.snapshot.pid),
              live.bundleIdentifier == row.snapshot.bundleIdentifier,
              ResourceHogsPolicy.canQuit(bundleIdentifier: live.bundleIdentifier) else {
            statusMessage = String(localized: "That process is no longer running.")
            showStatus = true
            return
        }
        monitor.forceQuit(pid: row.snapshot.pid)
        Task { await refresh() }
    }
}

private struct ResourceHogRowView: View {
    let row: ResourceHogRow
    let onQuit: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            appIcon
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(row.snapshot.name)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                Text("PID \(row.snapshot.pid)")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: "%.1f%%", row.snapshot.cpuPercent))
                    .font(.system(size: 12, weight: .semibold).monospacedDigit())
                Text(FileSizeFormatter.format(row.snapshot.memoryBytes))
                    .font(.system(size: 10).monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .frame(minWidth: 72, alignment: .trailing)

            if row.canQuit {
                Button(String(localized: "Quit"), action: onQuit)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .tint(.red)
            } else {
                Image(systemName: "lock.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .frame(width: 52)
                    .help(String(localized: "Protected — cannot quit"))
            }
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private var appIcon: some View {
        if let bid = row.snapshot.bundleIdentifier,
           let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bid) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path(percentEncoded: false)))
                .resizable()
        } else {
            Image(systemName: "app.dashed")
                .font(.system(size: 20))
                .foregroundStyle(.tertiary)
        }
    }
}
