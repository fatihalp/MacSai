import AppKit
import SwiftUI
import MacCleanKit

struct BrowserExtensionsView: View {
    @AppStorage("removeBackgroundColors") private var removeBackgroundColors = false
    @State private var scan = BrowserExtensionScan(records: [], safariListed: true)
    @State private var isLoading = true
    @State private var isWorking = false
    @State private var pending: BrowserExtensionRecord?
    @State private var message: String?
    private let client = BrowserExtensionsClient()

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
                    Task { await reload() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(isLoading || isWorking)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)

            if !isLoading && !scan.safariListed {
                Label(BrowserExtensionsStrings.safariUnavailable, systemImage: "exclamationmark.triangle")
                    .font(.system(size: 12))
                    .foregroundStyle(.orange)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 10)
            }

            Group {
                if isLoading {
                    VStack {
                        Spacer()
                        ProgressView().controlSize(.large)
                        Text(BrowserExtensionsStrings.reading)
                            .font(.system(size: 13))
                            .foregroundStyle(.primary.opacity(0.6))
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if scan.records.isEmpty {
                    VStack {
                        Spacer()
                        Text(BrowserExtensionsStrings.empty)
                            .foregroundStyle(.primary.opacity(0.4))
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(scan.records) { ext in
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
        .task { await reload() }
        .respondsToModuleShortcuts(onScan: { Task { await reload() } }, canScan: !isLoading && !isWorking)
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
                Task { await remove(target) }
            }
        } message: { ext in
            Text(BrowserExtensionsStrings.confirmMessage(for: ext))
        }
        .alert(
            String(localized: "Browser Extensions"),
            isPresented: Binding(
                get: { message != nil },
                set: { if !$0 { message = nil } }
            )
        ) {
            Button("OK", role: .cancel) { message = nil }
        } message: {
            Text(message ?? "")
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
            .disabled(isWorking)
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

    private func reload() async {
        isLoading = true
        scan = await client.list()
        isLoading = false
    }

    private func remove(_ record: BrowserExtensionRecord) async {
        isWorking = true
        let outcome = await client.applyRemoval(record)
        message = BrowserExtensionsStrings.message(for: outcome)
        if outcome == .trashed { scan = await client.list() }
        isWorking = false
    }
}

enum BrowserExtensionsStrings {
    static var subtitle: String {
        String(localized: "Extensions from Chrome, Brave, Edge, Arc, Firefox, and Safari. Names that match known adware families are marked Suspicious.")
    }

    static var reading: String {
        String(localized: "Reading extensions…")
    }

    static var empty: String {
        String(localized: "No extensions found in Chrome, Brave, Edge, Arc, Firefox, or Safari")
    }

    static var safariUnavailable: String {
        String(localized: "Couldn't read the list of Safari extensions. Check Safari Settings > Extensions instead.")
    }

    static var suspicious: String { String(localized: "Suspicious") }

    static var suspiciousHelp: String {
        String(localized: "The name matches a known adware family. This is a hint, not a confirmed detection.")
    }

    static var policyTag: String { String(localized: "Installed by policy") }
    static var builtInTag: String { String(localized: "Built in") }
    static var unknownDate: String { String(localized: "Unknown date") }
    static var details: String { String(localized: "Details") }

    static func confirmTitle(for record: BrowserExtensionRecord?) -> String {
        guard let record, record.origin == .user else {
            return String(localized: "About this extension")
        }
        return String(localized: "Remove extension?")
    }

    static func confirmMessage(for record: BrowserExtensionRecord) -> String {
        switch record.origin {
        case .safariApp:
            return String(localized: "Safari extensions come with apps and are managed by macOS, so this list is read-only. Settings will open instead.")
        case .policy:
            return fill(policyText, record.browser)
        case .component:
            return fill(builtInText, record.browser)
        case .user:
            return fill(String(localized: "If {browser} is closed, the extension folder moves to the Trash. If it is open, nothing is deleted and you'll see where to remove it. If you use {browser} sync, it may reinstall the extension."), record.browser)
        }
    }

    static func message(for outcome: BrowserExtensionsClient.RemovalOutcome) -> String? {
        switch outcome {
        case .openedSafariSettings:
            return nil
        case .trashed:
            return String(localized: "The extension was moved to the Trash.")
        case .removeInBrowser(let browser):
            return removeInBrowserText(browser)
        case .managedByPolicy(let browser):
            return fill(policyText, browser)
        case .builtIn(let browser):
            return fill(builtInText, browser)
        case .refused:
            return String(localized: "Mac Sai couldn't confirm this extension's folder is safe to remove, so nothing was deleted.")
        case .failed(let error):
            return String(localized: "Couldn't move it to the Trash: ") + error
        }
    }

    static func removeInBrowserText(_ browser: BrowserKind) -> String {
        switch browser {
        case .chrome:
            return String(localized: "Chrome is open, so nothing was deleted. Remove the extension in Chrome from Window > Extensions.")
        case .firefox:
            return String(localized: "Firefox is open, so nothing was deleted. Remove the extension in Firefox from Tools > Add-ons and Themes.")
        case .brave, .edge, .arc, .safari:
            let url: String
            switch browser {
            case .brave: url = "brave://extensions"
            case .edge: url = "edge://extensions"
            default: url = "arc://extensions"
            }
            return fill(String(localized: "{browser} is open, so nothing was deleted. Remove the extension in {browser} by opening {url} in the address bar."), browser).replacingOccurrences(of: "{url}", with: url)
        }
    }

    static var policyText: String {
        String(localized: "This extension was installed by a management policy, so {browser} would reinstall it. If you don't recognize it, search System Settings for Profiles or Device Management and remove any profile you don't recognize.")
    }

    static var builtInText: String {
        String(localized: "This extension is built into {browser} and can't be removed.")
    }

    static func fill(_ text: String, _ browser: BrowserKind) -> String {
        text.replacingOccurrences(of: "{browser}", with: browser.label)
    }
}
