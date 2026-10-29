import AppKit
import SwiftUI
import MacCleanKit

struct BrowserExtensionsView: View {
    @State private var controller = BrowserExtensionsController()
    @State private var pending: BrowserExtensionRecord?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Browser Extensions")
                        .font(.system(size: 22, weight: .bold))
                    Text(BrowserExtensionsStrings.subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(.primary.opacity(0.6))
                }
                Spacer()
                Button {
                    Task { await controller.reload() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(controller.isLoading || controller.isWorking)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)

            if !controller.isLoading && !controller.scan.safariListed {
                Label(BrowserExtensionsStrings.safariUnavailable, systemImage: "exclamationmark.triangle")
                    .font(.system(size: 12))
                    .foregroundStyle(.orange)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 10)
            }

            Group {
                if controller.isLoading {
                    VStack {
                        Spacer()
                        ProgressView().controlSize(.large)
                        Text(BrowserExtensionsStrings.reading)
                            .font(.system(size: 13))
                            .foregroundStyle(.primary.opacity(0.6))
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if controller.scan.records.isEmpty {
                    VStack {
                        Spacer()
                        Text(BrowserExtensionsStrings.empty)
                            .foregroundStyle(.primary.opacity(0.4))
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(controller.scan.records) { ext in
                        row(ext)
                    }
                    .listStyle(.inset)
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
        .respondsToModuleShortcuts(onScan: { Task { await controller.reload() } }, canScan: !controller.isLoading && !controller.isWorking)
        .alert(
            BrowserExtensionsStrings.confirmTitle(for: pending),
            isPresented: Binding(
                get: { pending != nil },
                set: { if !$0 { pending = nil } }
            ),
            presenting: pending
        ) { ext in
            Button("Cancel", role: .cancel) { pending = nil }
            Button(actionLabel(for: ext), role: ext.origin == .user ? .destructive : nil) {
                let target = ext
                pending = nil
                Task { await controller.remove(target) }
            }
        } message: { ext in
            Text(BrowserExtensionsStrings.confirmMessage(for: ext))
        }
        .alert(
            String(localized: "Browser Extensions"),
            isPresented: Binding(
                get: { controller.message != nil },
                set: { if !$0 { controller.message = nil } }
            )
        ) {
            Button("OK", role: .cancel) { controller.message = nil }
        } message: {
            Text(controller.message ?? "")
        }
    }

    private func row(_ ext: BrowserExtensionRecord) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(ext.name)
                        .font(.system(size: 13, weight: .medium))
                    if ext.isSuspicious {
                        tag(BrowserExtensionsStrings.suspicious, color: .red)
                            .help(BrowserExtensionsStrings.suspiciousHelp)
                    }
                    switch ext.origin {
                    case .policy: tag(BrowserExtensionsStrings.policyTag, color: .orange)
                    case .component: tag(BrowserExtensionsStrings.builtInTag, color: .gray)
                    case .user, .safariApp: EmptyView()
                    }
                }
                Text(detail(for: ext))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(actionLabel(for: ext)) {
                pending = ext
            }
            .buttonStyle(.bordered)
            .disabled(controller.isWorking)
        }
    }

    private func tag(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 10))
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(color.opacity(0.2))
            .clipShape(Capsule())
    }

    private func detail(for ext: BrowserExtensionRecord) -> String {
        let date = ext.updatedAt?.formatted(date: .abbreviated, time: .omitted)
            ?? BrowserExtensionsStrings.unknownDate
        var parts = [ext.browser.label]
        if !ext.profile.isEmpty { parts.append(ext.profile) }
        parts.append(date)
        return parts.joined(separator: " · ")
    }

    private func actionLabel(for ext: BrowserExtensionRecord) -> String {
        switch ext.origin {
        case .safariApp: String(localized: "Open in Settings")
        case .policy, .component: BrowserExtensionsStrings.details
        case .user: String(localized: "Remove")
        }
    }
}
