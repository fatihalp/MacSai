import SwiftUI
import AppKit
import ServiceManagement
import MacCleanKit

struct SettingsPageView: View {
    enum UpdateUIState: Equatable {
        case idle
        case checking
        case upToDate
        case available(version: String, url: URL)
        case failed(message: String)
    }

    @AppStorage("showMenuBarWidget") private var showMenuBarWidget = true
    @AppStorage(MenuBarMetric.defaultsKey, store: SharedAppState.defaults) private var menuBarMetricRaw = MenuBarMetric.diskFree.rawValue
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @AppStorage("removeBackgroundColors") private var removeBackgroundColors = false
    @AppStorage("automaticUpdateChecks") private var automaticUpdateChecks = true
    @AppStorage("lastUpdateCheckDate") private var lastUpdateCheckTimestamp: Double = 0
    @AppStorage(AppearanceManager.defaultsKey) private var appearanceRaw = AppearanceMode.light.rawValue
    @AppStorage(Localization.defaultsKey, store: SharedAppState.defaults) private var appLanguage = "en"
    @State private var launcher = MenuBarLauncher.shared
    @State private var loginLauncher = LaunchAtLoginManager.shared
    @State private var updateState: UpdateUIState = .idle
    @State private var keptLanguages: Set<String> = []
    @State private var selectable: [(name: String, lprojs: [String])] = []
    @State private var languageSearch: String = ""
    @State private var excludedFolders: [String] = FolderExclusionPreferences.paths
    @State private var exclusionError: String?

    private var filteredLanguages: [(name: String, lprojs: [String])] {
        guard !languageSearch.isEmpty else { return selectable }
        return selectable.filter { $0.name.localizedCaseInsensitiveContains(languageSearch) }
    }

    var body: some View {
        Form {
            headerSection
            generalSection
            interfaceLanguageSection
            appearanceSection
            languageSection
            excludedFoldersSection
            aboutSection
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .frame(maxWidth: 680)
        .frame(maxWidth: .infinity)
        .onAppear {
            launchAtLogin = loginLauncher.refreshStatus()
            keptLanguages = LanguagePreferences.userKept
            selectable = LanguagePreferences.selectableLanguages()
            excludedFolders = FolderExclusionPreferences.paths
            Task.detached(priority: .userInitiated) {
                let found = LanguageScanner().discoverLproj(in: LanguageScanner.defaultRoots)
                await MainActor.run {
                    LanguagePreferences.discoveredLproj = found
                    selectable = LanguagePreferences.selectableLanguages()
                }
            }
        }
    }

    private var headerSection: some View {
        Section {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(MCConstants.appName)
                        .font(.title2.weight(.semibold))
                    Text("Version \(MCConstants.appVersion)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                updateControl
            }
            if case .available(let version, let url) = updateState {
                updateAvailableRow(version: version, url: url)
            }
            Toggle("Automatically check for updates",
                   isOn: $automaticUpdateChecks)
            if lastUpdateCheckTimestamp > 0 {
                Text("Last checked: \(lastCheckedDescription)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var lastCheckedDescription: String {
        let date = Date(timeIntervalSinceReferenceDate: lastUpdateCheckTimestamp)
        return date.formatted(date: .abbreviated, time: .shortened)
    }

    @ViewBuilder
    private var updateControl: some View {
        switch updateState {
        case .idle:
            Button("Check for Updates") { startUpdateCheck() }
        case .checking:
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text("Checking…").foregroundStyle(.secondary)
            }
        case .upToDate:
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                Text("Up to date")
            }
        case .available:
            EmptyView()
        case .failed(let message):
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                Text(message).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                Button("Retry") { startUpdateCheck() }
            }
        }
    }

    @ViewBuilder
    private func updateAvailableRow(version: String, url: URL) -> some View {
        if UpdateChecker.isHomebrewInstall() {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Version \(version) is available. Update with Homebrew:")
                    Text(Self.brewUpgradeCommand)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                }
                Spacer()
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(Self.brewUpgradeCommand, forType: .string)
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }
            }
        } else {
            HStack {
                Text("Version \(version) is available.")
                Spacer()
                Button("View Release") { NSWorkspace.shared.open(url) }
                    .buttonStyle(.borderedProminent)
            }
        }
    }

    static let brewUpgradeCommand = "brew upgrade --cask mac-sai"

    @MainActor
    private func startUpdateCheck() {
        updateState = .checking
        Task {
            let result = await UpdateChecker.check()
            switch result {
            case .upToDate:
                updateState = .upToDate
            case .updateAvailable(let version, let url):
                updateState = .available(version: version, url: url)
            case .failed(let message):
                updateState = .failed(message: message)
            }
        }
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { launchAtLogin },
            set: { requestedValue in
                launchAtLogin = requestedValue
                Task {
                    launchAtLogin = await loginLauncher.setEnabled(requestedValue)
                }
            }
        )
    }

    private var generalSection: some View {
        Section(String(localized: "General")) {

            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Launch at login")
                    Text("Open \(MCConstants.appName) automatically when you sign in to macOS. You can also manage this in System Settings → General → Login Items.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if loginLauncher.isBusy {
                    ProgressView().controlSize(.small)
                }
                Toggle("Launch at login", isOn: launchAtLoginBinding)
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .disabled(loginLauncher.isBusy)
            }
            .animation(.easeInOut(duration: 0.18), value: loginLauncher.isBusy)
            if loginLauncher.status == .requiresApproval {
                Label("Needs approval in System Settings → General → Login Items",
                      systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .font(.caption)
            }
            if let err = loginLauncher.lastError {
                Label(err.localizedDescription, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .font(.caption)
            }

            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Show \(MCConstants.appName) in the menu bar")
                    Text("Live CPU, memory, disk, battery, and network at the top of your screen. Click to expand the popover.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if launcher.isBusy {
                    ProgressView().controlSize(.small)
                }
                Toggle("Show \(MCConstants.appName) in the menu bar", isOn: $showMenuBarWidget)
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .disabled(launcher.isBusy)
            }
            .animation(.easeInOut(duration: 0.18), value: launcher.isBusy)
            .onChange(of: showMenuBarWidget) { _, newValue in
                Task { await launcher.setEnabled(newValue) }
            }
            widgetStatusRow
            Picker(selection: $menuBarMetricRaw) {
                ForEach(MenuBarMetric.allCases) { metric in
                    Text(metric.localizedName).tag(metric.rawValue)
                }
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Menu bar display")
                    Text("Choose the compact value shown next to the app icon. Unavailable GPU or battery sensors appear as --.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
            .pickerStyle(.menu)
            .disabled(!showMenuBarWidget)
            if let err = launcher.lastError {
                Label(err.localizedDescription, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .font(.caption)
            }
        }
    }

    private var interfaceLanguageSection: some View {
        Section(String(localized: "Interface Language")) {
            Picker("Language", selection: $appLanguage) {
                ForEach(AppLanguage.all) { language in
                    Text(language.name).tag(language.id)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: appLanguage) { _, newValue in
                Localization.currentID = newValue
                selectable = LanguagePreferences.selectableLanguages()
            }

            Text("Changes apply immediately to the main window and menu-bar widget.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var appearanceSection: some View {
        Section(String(localized: "Appearance")) {
            Picker("Theme", selection: $appearanceRaw) {
                ForEach(AppearanceMode.allCases) { mode in
                    Text(mode.label).tag(mode.rawValue)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: appearanceRaw) { _, newValue in
                AppearanceManager.apply(AppearanceMode(rawValue: newValue) ?? .system)
            }

            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Remove background colors")
                    Text("Replace module gradient backgrounds with a neutral dark color for better readability.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Toggle("Remove background colors", isOn: $removeBackgroundColors)
                    .toggleStyle(.switch)
                    .labelsHidden()
            }
        }
    }

    private var languageSection: some View {
        Section(String(localized: "Language Cleanup")) {
            Text("English, Base resources, Chinese, Russian, and German are always kept. Checked languages are preserved; unchecked language files can be removed by System Junk.")
                .font(.caption)
                .foregroundStyle(.secondary)

            if selectable.isEmpty {
                Text("Detecting installed languages…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                TextField("Search languages", text: $languageSearch)
                    .textFieldStyle(.roundedBorder)

                if filteredLanguages.isEmpty {
                    Text("No languages match “\(languageSearch)”.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredLanguages, id: \.name) { lang in

                            HStack {
                                Text(lang.name)
                                Spacer()
                                Toggle(lang.name, isOn: Binding(
                                    get: { lang.lprojs.allSatisfy { keptLanguages.contains($0) } },
                                    set: { on in
                                        if on { keptLanguages.formUnion(lang.lprojs) }
                                        else { lang.lprojs.forEach { keptLanguages.remove($0) } }
                                        LanguagePreferences.userKept = keptLanguages
                                    }
                                ))
                                .toggleStyle(.switch)
                                .controlSize(.small)
                                .labelsHidden()
                            }
                            .padding(.vertical, 5)
                            .padding(.trailing, 6)
                            Divider().opacity(0.5)
                        }
                    }
                }
                .frame(height: 250)
            }
        }
    }

    private var excludedFoldersSection: some View {
        Section(String(localized: "Excluded Folders")) {
            Text("These folders and their contents are hidden from cleanup scans and cannot be deleted by \(MCConstants.appName) (including Shredder). Only paths under your home folder or /Volumes.")
            .font(.caption)
            .foregroundStyle(.secondary)

            if excludedFolders.isEmpty {
                Text("No folders excluded yet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(excludedFolders, id: \.self) { path in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(path)
                            .font(.system(.body, design: .monospaced))
                            .lineLimit(2)
                            .textSelection(.enabled)
                        Spacer(minLength: 8)
                        Button("Remove", role: .destructive) {
                            FolderExclusionPreferences.remove(path)
                            excludedFolders = FolderExclusionPreferences.paths
                            exclusionError = nil
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }

            Button("Add Folder…") {
                addExcludedFolder()
            }

            if let exclusionError {
                Label(exclusionError, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .font(.caption)
            }
        }
    }

    private func addExcludedFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = String(localized: "Exclude")
        panel.message = String(localized: "Choose a folder to exclude from cleanup.")
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let path = url.path(percentEncoded: false)
        if FolderExclusionPreferences.add(path) {
            excludedFolders = FolderExclusionPreferences.paths
            exclusionError = nil
        } else {
            exclusionError = rejectionMessage(for: path)
        }
    }

    private func rejectionMessage(for path: String) -> String {
        switch PathExclusion.candidateDecision(
            for: path,
            home: NSHomeDirectory(),
            maxCount: FolderExclusionPreferences.defaultMaxCount,
            existing: FolderExclusionPreferences.paths
        ) {
        case .allow:
            return String(localized: "Couldn't add that folder.")
        case .reject(.notAbsolute):
            return String(localized: "Choose an absolute path.")
        case .reject(.entireHome):
            return String(localized: "You can't exclude your entire home folder.")
        case .reject(.entireVolumesRoot):
            return String(localized: "You can't exclude all of /Volumes.")
        case .reject(.outsideAllowedRoots):
            return String(localized: "Only folders under your home directory or /Volumes can be excluded.")
        case .reject(.atCapacity):
            return "You can exclude at most \(FolderExclusionPreferences.defaultMaxCount) folders."
        case .reject(.alreadyCovered):
            return String(localized: "That path is already covered by an existing exclusion.")
        }
    }

    private var aboutSection: some View {
        Section(String(localized: "About")) {
            aboutRow(icon: "chevron.left.forwardslash.chevron.right", tint: .orange,
                     title: String(localized: "Source code"), caption: String(localized: "Browse the codebase on GitHub"),
                     url: MCConstants.repoURL)
            aboutRow(icon: "exclamationmark.bubble", tint: .blue,
                     title: String(localized: "Report an issue"), caption: String(localized: "Bug reports and feature requests"),
                     url: MCConstants.issuesURL)
            aboutRow(icon: "tag", tint: .green,
                     title: String(localized: "Release notes"), caption: String(localized: "Changelog and previous versions"),
                     url: MCConstants.releasesURL)
            aboutRow(icon: "cup.and.saucer.fill", tint: .yellow,
                     title: String(localized: "Support Mac Sai"), caption: String(localized: "Buy the developer a coffee"),
                     url: MCConstants.supportURL)
        }
    }

    private func aboutRow(icon: String, tint: Color, title: String, caption: String, url: URL) -> some View {
        Button {
            NSWorkspace.shared.open(url)
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(tint.opacity(0.18)).frame(width: 32, height: 32)
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(tint)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                    Text(caption).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(.isLink)
    }

    @ViewBuilder
    private var widgetStatusRow: some View {
        HStack {
            Image(systemName: statusGlyph)
                .foregroundStyle(statusColor)
            Text("Widget status:")
                .foregroundStyle(.secondary)
            Text(statusText)
                .font(.system(.body, design: .monospaced))
            Spacer()
        }
        .font(.caption)
    }

    private var statusGlyph: String {
        switch launcher.statusSnapshot {
        case .enabled: return "checkmark.circle.fill"
        case .notRegistered: return "minus.circle"
        case .notFound: return "questionmark.circle"
        case .requiresApproval: return "exclamationmark.triangle.fill"
        @unknown default: return "questionmark.circle"
        }
    }

    private var statusColor: Color {
        switch launcher.statusSnapshot {
        case .enabled: return .green
        case .requiresApproval: return .orange
        default: return .secondary
        }
    }

    private var statusText: String {
        switch launcher.statusSnapshot {
        case .enabled: return String(localized: "Running")
        case .notRegistered: return String(localized: "not registered")
        case .notFound: return String(localized: "helper not found in bundle")
        case .requiresApproval: return String(localized: "needs approval in System Settings → Login Items")
        @unknown default: return String(localized: "Unknown")
        }
    }
}
