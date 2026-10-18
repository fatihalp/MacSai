import AppKit
import SwiftUI
import MacCleanKit

struct ExtensionsView: View {
    @Environment(AppState.self) private var appState
    @AppStorage("removeBackgroundColors") private var removeBackgroundColors = false
    @State private var items: [ManagedExtension] = []
    @State private var isLoading = true
    @State private var isRemoving = false
    @State private var pendingRemove: ManagedExtension?
    @State private var errorMessage: String?
    private let client = ManagedExtensionsClient.live()

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Extensions")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.primary)
                    Text("Review third-party preference panes, Internet Plug-Ins, and Safari extensions. User-installed panes and plug-ins can go to the Trash.")
                    .font(.system(size: 12))
                    .foregroundStyle(.primary.opacity(0.6))
                }
                Spacer()
                Button {
                    Task { await reload() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(isLoading || isRemoving)
                .help("Reload the extension list")
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)

            Group {
                if isLoading {
                    VStack(spacing: 12) {
                        Spacer()
                        ProgressView()
                            .controlSize(.large)
                            .tint(.primary)
                        Text("Looking for extensions…")
                            .font(.system(size: 13))
                            .foregroundStyle(.primary.opacity(0.6))
                        Spacer()
                    }

                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    list
                }
            }
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1)
            )
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .task { await reload() }
        .respondsToModuleShortcuts(
            onScan: { Task { await reload() } },
            canScan: !isLoading && !isRemoving
        )
        .alert(
            String(localized: "Move to Trash?"),
            isPresented: Binding(
                get: { pendingRemove != nil },
                set: { if !$0 { pendingRemove = nil } }
            ),
            presenting: pendingRemove
        ) { item in
            Button("Cancel", role: .cancel) { pendingRemove = nil }
            Button("Move to Trash", role: .destructive) {
                let captured = item
                pendingRemove = nil
                Task { await remove(captured) }
            }
        } message: { item in
            Text("\(item.name) will be moved to the Trash. You can restore it from the Trash if needed.")
        }
        .alert(
            String(localized: "Extensions"),
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var list: some View {
        List {
            if items.isEmpty {
                Text("No third-party extensions, plug-ins, or preference panes found.")
                .font(.system(size: 13))
                .foregroundStyle(.primary.opacity(0.4))
                .listRowSeparator(.hidden)
            } else {

                if items.contains(where: { $0.kind == .preferencePane }) {
                    section(
                        kind: .preferencePane,
                        title: String(localized: "Preference Panes"),
                        icon: "slider.horizontal.3"
                    )
                }
                if items.contains(where: { $0.kind == .internetPlugin }) {
                    section(
                        kind: .internetPlugin,
                        title: String(localized: "Internet Plug-Ins"),
                        icon: "puzzlepiece.extension"
                    )
                }
                if items.contains(where: { $0.kind == .safariExtension }) {
                    safariSection
                }
            }
        }
        .listStyle(.inset)
    }

    private var safariSection: some View {
        let rows = items.filter { $0.kind == .safariExtension }
        return Section {
            if rows.isEmpty {
                Text("No Safari extensions listed")
                    .font(.system(size: 13))
                    .foregroundStyle(.primary.opacity(0.4))
            } else {
                ForEach(rows) { item in
                    row(item)
                }
            }
            Text("Safari extensions can't be turned on, off, or deleted here — that would break the host app's signature. Manage them in Safari Settings.")
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            .padding(.top, 4)
        } header: {
            HStack {
                Label(
                    String(localized: "Safari Extensions"),
                    systemImage: "safari"
                )
                .font(.system(size: 13, weight: .semibold))
                Spacer()
                Button("Open Safari Settings") {
                    client.openSafariSettings()
                }
                .buttonStyle(.borderless)
            }
        }
    }

    private func section(kind: ManagedExtensionKind, title: String, icon: String) -> some View {
        let rows = items.filter { $0.kind == kind }
        return Section {
            if rows.isEmpty {
                Text("Nothing found")
                    .font(.system(size: 13))
                    .foregroundStyle(.primary.opacity(0.4))
            } else {
                ForEach(rows) { item in
                    row(item)
                }
            }
        } header: {
            Label(title, systemImage: icon)
                .font(.system(size: 13, weight: .semibold))
        }
    }

    private func row(_ item: ManagedExtension) -> some View {
        HStack(spacing: 10) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: item.path.path(percentEncoded: false)))
                .resizable()
                .frame(width: 22, height: 22)
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text(item.name)
                        .font(.system(size: 13, weight: .medium))
                    if item.election == .enabled {
                        Text("On")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.secondary)
                    } else if item.election == .disabled {
                        Text("Off")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                Text(subtitle(for: item))
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
            Spacer()
            actions(for: item)
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private func actions(for item: ManagedExtension) -> some View {
        let action = client.removal(for: item)
        if item.kind == .safariExtension, action == .none {
            Button("Open Settings") {
                client.openSafariSettings()
            }
            .buttonStyle(.borderless)
            if let host = item.hostAppPath {
                Button("Show Host App") {
                    client.revealInFinder(host)
                }
                .buttonStyle(.borderless)
            }
        } else {
            Button("Reveal in Finder") {
                client.revealInFinder(item.path)
            }
            .buttonStyle(.borderless)
            if action == .trash {
                Button("Remove") {
                    pendingRemove = item
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.red)
                .disabled(isRemoving)
            }
        }
    }

    private func subtitle(for item: ManagedExtension) -> String {
        let location = item.domain == .user
            ? String(localized: "User")
            : String(localized: "This Mac")
        if let host = item.hostAppPath {
            return "\(location) · \(host.deletingPathExtension().lastPathComponent)"
        }
        if !item.bundleIdentifier.isEmpty {
            return "\(location) · \(item.bundleIdentifier)"
        }
        return location
    }

    private func reload() async {
        isLoading = true
        items = await client.load()
        isLoading = false
    }

    private func remove(_ item: ManagedExtension) async {
        guard !isRemoving else { return }
        isRemoving = true
        let urls = client.trashURLs(from: [item])
        guard !urls.isEmpty else {
            errorMessage = String(localized: "This item was refused for safety reasons.")
            isRemoving = false
            return
        }
        let fileItems = urls.map { url in
            FileItem(
                url: url,
                name: url.lastPathComponent,
                size: 0,
                allocatedSize: 0,
                isDirectory: true,
                isPackage: true
            )
        }
        let result = await CleanActions.executeUserClean(
            items: fileItems,
            selectedItems: Set(urls),
            engine: appState.cleaningEngine
        )
        if !result.errors.isEmpty {
            errorMessage = "Couldn't move \(item.name) to the Trash."
        }
        await reload()
        isRemoving = false
    }
}
