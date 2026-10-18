import SwiftUI
import AppKit
import MacCleanKit

struct FileHandlerView: View {
    @StateObject private var viewModel = FileHandlerViewModel()

    var body: some View {
        VStack(spacing: 0) {

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 12))
                TextField("Search file type or app...",
                          text: $viewModel.searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                if !viewModel.searchText.isEmpty {
                    Button(action: { viewModel.searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.borderless)
                }
                Spacer()
                Button(action: {
                    viewModel.loadBackups()
                    viewModel.showRestoreSheet = true
                }) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 12))
                }
                .buttonStyle(.borderless)
                .help("Version history")
                Button(action: { viewModel.loadHandlers() }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12))
                }
                .buttonStyle(.borderless)
                .help("Refresh")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            if viewModel.isLoading {
                Spacer()
                ProgressView()
                    .controlSize(.large)
                    .tint(.primary)
                Spacer()
            } else if viewModel.handlers.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "doc.badge.gearshape")
                        .font(.system(size: 32))
                        .foregroundStyle(.tertiary)
                    Text("No custom file associations")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            } else if viewModel.filteredHandlers.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 32))
                        .foregroundStyle(.tertiary)
                    Text("No matching results")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            } else {
                List {
                    ForEach(viewModel.filteredHandlers) { handler in
                        HandlerRowView(
                            handler: handler,
                            appInfo: viewModel.getAppInfo(for: handler),
                            onDelete: { viewModel.deleteHandler(handler) }
                        )
                    }
                }
                .listStyle(.inset)
            }
        }
        .sheet(isPresented: $viewModel.showRestoreSheet) {
            restoreSheet
        }
        .alert(String(localized: "Error"), isPresented: $viewModel.showError) {
            Button("OK") { viewModel.showError = false }
        } message: {
            Text(viewModel.errorMessage ?? String(localized: "An unknown error occurred"))
        }
        .onAppear { viewModel.loadHandlers() }
    }

    private var restoreSheet: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Restore Version")
                    .font(.headline)
                Spacer()
                Button(action: { viewModel.showRestoreSheet = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
            }
            .padding()

            Divider()

            if viewModel.backups.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "clock.badge.questionmark")
                        .font(.system(size: 32))
                        .foregroundStyle(.tertiary)
                    Text("No backups available")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, minHeight: 200)
            } else {
                List {
                    ForEach(Array(viewModel.backups.enumerated()), id: \.offset) { _, url in
                        BackupRowView(
                            url: url,
                            isRestoring: viewModel.isRestoring,
                            onRestore: { viewModel.restoreBackup(from: url) }
                        )
                    }
                }
                .listStyle(.inset)
            }
        }
        .frame(width: 420, height: 320)
    }
}

private struct BackupRowView: View {
    let url: URL
    let isRestoring: Bool
    let onRestore: () -> Void

    var body: some View {
        HStack {
            Image(systemName: "doc.badge.clock")
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(formattedDate)
                    .font(.system(size: 13, weight: .medium))
                Text(url.lastPathComponent)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
            Spacer()
            Button(action: onRestore) {
                Text("Restore")
                    .font(.system(size: 12))
            }
            .buttonStyle(.bordered)
            .disabled(isRestoring)
        }
        .padding(.vertical, 2)
    }

    private var formattedDate: String {

        let isoStr = url.lastPathComponent
            .replacingOccurrences(of: "launchservices-", with: "")
            .replacingOccurrences(of: ".plist", with: "")
            .replacingOccurrences(of: "_", with: ":")
        let isoFmt = ISO8601DateFormatter()
        isoFmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = isoFmt.date(from: isoStr) {
            let display = DateFormatter()
            display.dateStyle = .medium
            display.timeStyle = .medium
            return display.string(from: date)
        }
        return url.lastPathComponent
    }
}

private struct HandlerRowView: View {
    let handler: HandlerEntry
    let appInfo: (name: String, icon: NSImage)?
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 8) {

            if let info = appInfo {
                Image(nsImage: info.icon)
                    .resizable()
                    .frame(width: 28, height: 28)
            } else {
                Image(systemName: "app.dashed")
                    .font(.system(size: 20))
                    .foregroundStyle(.tertiary)
                    .frame(width: 28, height: 28)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(handler.fileTypeDescription)
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .lineLimit(1)

                if let ct = handler.contentType {
                    Text("UTI: \(ct)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                } else if handler.urlScheme != nil {
                    Text("URL Scheme")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            if let info = appInfo {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(info.name)
                        .font(.system(size: 13))
                    if let bid = handler.appBundleIdentifier {
                        Text(bid)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                }
            } else {
                Text("Unknown app")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 11))
                    .foregroundStyle(.red)
            }
            .buttonStyle(.borderless)
            .help("Remove (auto-backup created)")
        }
        .padding(.vertical, 2)
    }
}
