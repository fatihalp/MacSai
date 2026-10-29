import SwiftUI
import AppKit
import MacCleanKit

struct ResourceHogsView: View {
    @State private var controller = ResourceHogsController()
    @State private var showQuitConfirm = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Picker("Sort", selection: $controller.sortBy) {
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
                if controller.isLoading && controller.rows.isEmpty {
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
                } else if controller.rows.isEmpty {
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
                        ForEach(controller.rows) { row in
                            ResourceHogRowView(row: row) {
                                controller.pendingQuit = row
                                showQuitConfirm = true
                            }
                        }
                    }
                    .listStyle(.inset)
                }
            }
        }
        .task {
            await controller.monitorProcesses()
        }
        .onChange(of: controller.sortBy) { _, _ in
            Task { await controller.refresh() }
        }
        .alert(
            "Force Quit \(controller.pendingQuit?.snapshot.name ?? "")?",
            isPresented: $showQuitConfirm
        ) {
            Button("Cancel", role: .cancel) {
                controller.pendingQuit = nil
            }
            Button("Force Quit", role: .destructive) {
                controller.quitPending()
            }
        } message: {
            Text("Unsaved work may be lost.")
        }
        .alert(controller.statusMessage ?? "", isPresented: $controller.showStatus) {
            Button("OK") { controller.showStatus = false }
        }
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
                Button("Quit", action: onQuit)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .tint(.red)
            } else {
                Image(systemName: "lock.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .frame(width: 52)
                    .help("Protected — cannot quit")
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
