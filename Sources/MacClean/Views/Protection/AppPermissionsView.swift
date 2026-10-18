import AppKit
import SwiftUI
import UniformTypeIdentifiers
import MacCleanKit

struct AppPermissionsView: View {
    @AppStorage("removeBackgroundColors") private var removeBackgroundColors = false
    @State private var snapshot = AppPermissionsSnapshot(grants: [], listing: .loaded)
    @State private var isLoading = true
    private let client = AppPermissionsClient.live()

    private var apps: [AppPermissionApp] {
        AppPermissionOverview.apps(from: snapshot.grants)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Permissions")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.primary)
                    Text("See which privacy grants each app holds. This list is read-only — buttons open System Settings. Mac Sai cannot turn a permission off.")
                    .font(.system(size: 12))
                    .foregroundStyle(.primary.opacity(0.6))
                }
                Spacer()
                Button {
                    Task { await reload() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(isLoading)
                .help("Reload the permission list")
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
                        Text("Reading permissions…")
                            .font(.system(size: 13))
                            .foregroundStyle(.primary.opacity(0.6))
                        Spacer()
                    }
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
        .respondsToModuleShortcuts(onScan: { Task { await reload() } }, canScan: !isLoading)
    }

    private var list: some View {
        List {
            if snapshot.listing != .loaded {
                listingBanner
            }

            if snapshot.listing == .loaded {
                if apps.isEmpty {
                    Text("No apps listed.")
                    .font(.system(size: 13))
                    .foregroundStyle(.primary.opacity(0.4))
                    .listRowSeparator(.hidden)
                } else {
                    ForEach(apps) { app in
                        appSection(app)
                    }
                }
            }

            settingsJumpSection
        }
        .listStyle(.inset)
    }

    private func appSection(_ app: AppPermissionApp) -> some View {
        Section {
            ForEach(app.grants) { grant in
                grantRow(grant)
            }
        } header: {
            HStack(spacing: 8) {
                Image(nsImage: icon(for: app))
                    .resizable()
                    .frame(width: 18, height: 18)
                Text(displayName(for: app))
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Text(grantCountLabel(app.grants.count))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func grantRow(_ grant: AppPermissionGrant) -> some View {
        HStack(spacing: 10) {
            Image(systemName: permissionIcon(grant.permission))
                .foregroundStyle(.secondary)
                .frame(width: 16)
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text(permissionTitle(grant.permission))
                        .font(.system(size: 13, weight: .medium))
                    if grant.isLimited {
                        Text("Limited")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                if let target = grant.indirectObjectIdentifier, !target.isEmpty {
                    Text("Controls \(target)")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer()
            Button("Open in System Settings") {
                client.openSettings(for: grant.permission)
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 2)
    }

    private var settingsJumpSection: some View {
        Section {
            ForEach(PrivacyPermission.allCases) { permission in
                Button {
                    client.openSettings(for: permission)
                } label: {
                    HStack {
                        Label(permissionTitle(permission), systemImage: permissionIcon(permission))
                            .foregroundStyle(.primary)
                        Spacer()
                        Text("Open in System Settings")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
            }
        } header: {
            Text("Open a category in System Settings")
                .font(.system(size: 13, weight: .semibold))
        } footer: {
            Text("Changing a grant can only be done in System Settings.")
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
        }
    }

    private var listingBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(
                snapshot.listing == .needsFullDiskAccess
                    ? String(localized: "Full Disk Access needed to list apps")
                    : String(localized: "Couldn't read the permission database")
            )
            .font(.system(size: 13, weight: .semibold))
            Text(
                snapshot.listing == .needsFullDiskAccess
                    ? "macOS is blocking the by-app overview. Grant \(MCConstants.appName) Full Disk Access, then refresh. The buttons below still open System Settings."
                    : String(localized: "This app can't list which apps hold which grants. You can still open System Settings with the buttons below.")
            )
            .font(.system(size: 12))
            .foregroundStyle(.primary.opacity(0.7))
            if snapshot.listing == .needsFullDiskAccess {
                Button("Open in System Settings") {
                    client.openFullDiskAccessSettings()
                }
                .buttonStyle(.borderedProminent)
                .tint(.primary)
                .controlSize(.small)
            }
        }
        .padding(.vertical, 6)
    }

    private func reload() async {
        isLoading = true
        snapshot = await client.load()
        isLoading = false
    }

    private func grantCountLabel(_ count: Int) -> String {
        count == 1 ? "1 grant" : "\(count) grants"
    }

    private func permissionTitle(_ permission: PrivacyPermission) -> String {
        switch permission {
        case .camera: String(localized: "Camera")
        case .microphone: String(localized: "Microphone")
        case .fullDiskAccess: String(localized: "Full Disk Access")
        case .screenRecording: String(localized: "Screen Recording")
        case .automation: String(localized: "Automation")
        }
    }

    private func permissionIcon(_ permission: PrivacyPermission) -> String {
        switch permission {
        case .camera: "web.camera"
        case .microphone: "mic"
        case .fullDiskAccess: "externaldrive"
        case .screenRecording: "rectangle.dashed.badge.record"
        case .automation: "gearshape.2"
        }
    }

    private func displayName(for app: AppPermissionApp) -> String {
        if app.clientIsPath {
            return URL(filePath: app.client).deletingPathExtension().lastPathComponent
        }
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: app.client) {
            return FileManager.default.displayName(atPath: url.path(percentEncoded: false))
        }
        return app.client
    }

    private func icon(for app: AppPermissionApp) -> NSImage {
        if app.clientIsPath {
            return NSWorkspace.shared.icon(forFile: app.client)
        }
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: app.client) {
            return NSWorkspace.shared.icon(forFile: url.path(percentEncoded: false))
        }
        return NSWorkspace.shared.icon(for: .application)
    }
}
