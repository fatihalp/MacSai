import AppKit
import SwiftUI
import MacCleanKit

struct ExtensionsView: View {
    @Bindable var controller: ExtensionsController
    @State private var pendingRemove: ManagedExtension?

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
                    Task { await controller.reload() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(controller.isLoading || controller.isRemoving)
                .help("Reload the extension list")
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)

            Group {
                if controller.isLoading {
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
        .task { await controller.reload() }
        .respondsToModuleShortcuts(
            onScan: { Task { await controller.reload() } },
            canScan: !controller.isLoading && !controller.isRemoving
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
                Task { await controller.remove(captured) }
            }
        } message: { item in
            Text("\(item.name) will be moved to the Trash. You can restore it from the Trash if needed.")
        }
        .alert(
            String(localized: "Extensions"),
            isPresented: Binding(
                get: { controller.errorMessage != nil },
                set: { if !$0 { controller.errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) { controller.errorMessage = nil }
        } message: {
            Text(controller.errorMessage ?? "")
        }
    }

    private var list: some View {
        List {
            if controller.items.isEmpty {
                Text("No third-party extensions, plug-ins, or preference panes found.")
                .font(.system(size: 13))
                .foregroundStyle(.primary.opacity(0.4))
                .listRowSeparator(.hidden)
            } else {

                if controller.items.contains(where: { $0.kind == .preferencePane }) {
                    section(
                        kind: .preferencePane,
                        title: String(localized: "Preference Panes"),
                        icon: "slider.horizontal.3"
                    )
                }
                if controller.items.contains(where: { $0.kind == .internetPlugin }) {
                    section(
                        kind: .internetPlugin,
                        title: String(localized: "Internet Plug-Ins"),
                        icon: "puzzlepiece.extension"
                    )
                }
                if controller.items.contains(where: { $0.kind == .safariExtension }) {
                    safariSection
                }
            }
        }
        .listStyle(.inset)
    }

    private var safariSection: some View {
        let rows = controller.items.filter { $0.kind == .safariExtension }
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
                    controller.client.openSafariSettings()
                }
                .buttonStyle(.borderless)
            }
        }
    }

    private func section(kind: ManagedExtensionKind, title: String, icon: String) -> some View {
        let rows = controller.items.filter { $0.kind == kind }
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
        let action = controller.client.removal(for: item)
        if item.kind == .safariExtension, action == .none {
            Button("Open Settings") {
                controller.client.openSafariSettings()
            }
            .buttonStyle(.borderless)
            if let host = item.hostAppPath {
                Button("Show Host App") {
                    controller.client.revealInFinder(host)
                }
                .buttonStyle(.borderless)
            }
        } else {
            Button("Reveal in Finder") {
                controller.client.revealInFinder(item.path)
            }
            .buttonStyle(.borderless)
            if action == .trash {
                Button("Remove") {
                    pendingRemove = item
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.red)
                .disabled(controller.isRemoving)
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
}
