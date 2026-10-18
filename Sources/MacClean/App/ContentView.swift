import SwiftUI
import AppKit
import MacCleanKit

struct ContentView: View {
    @Environment(AppState.self) private var appState
    @State private var visited: Set<SidebarItem> = []
    @State private var history: [SidebarItem] = []
    @State private var historyIndex: Int = -1
    @State private var updateCoordinator = UpdateCoordinator()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        @Bindable var state = appState

        NavigationSplitView {
            SidebarView(selection: $state.selectedSidebarItem)
                .toolbar(removing: .sidebarToggle)
        } detail: {
            ZStack {
                Color.white
                    .ignoresSafeArea()

                ForEach(SidebarItem.allCases, id: \.self) { item in
                    if visited.contains(item) || item == appState.selectedSidebarItem {
                        let isSelected = item == appState.selectedSidebarItem
                        moduleView(for: item)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .opacity(isSelected ? 1 : 0)
                            .allowsHitTesting(isSelected)
                            .accessibilityHidden(!isSelected)
                            .environment(\.moduleIsSelected, isSelected)
                    }
                }

                if appState.selectedSidebarItem == nil {
                    Text("Select a module from the sidebar")
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.white)
        }
        .navigationTitle(appState.selectedSidebarItem?.title ?? MCConstants.appName)
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
                ControlGroup {
                    Button {
                        if historyIndex > 0 {
                            historyIndex -= 1
                            appState.selectedSidebarItem = history[historyIndex]
                        }
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                    .disabled(historyIndex <= 0)

                    Button {
                        if historyIndex + 1 < history.count {
                            historyIndex += 1
                            appState.selectedSidebarItem = history[historyIndex]
                        }
                    } label: {
                        Image(systemName: "chevron.right")
                    }
                    .disabled(historyIndex >= history.count - 1)
                }
            }
        }
        .onChange(of: appState.selectedSidebarItem, initial: true) { _, newValue in
            guard let newValue else { return }
            visited.insert(newValue)
            if historyIndex >= 0 && historyIndex < history.count && history[historyIndex] == newValue {
                return
            }
            if historyIndex + 1 < history.count {
                history.removeSubrange((historyIndex + 1)...)
            }
            history.append(newValue)
            historyIndex = history.count - 1
        }
        .task {
            try? await Task.sleep(for: .seconds(3))
            await updateCoordinator.runCheckIfDue()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await updateCoordinator.runCheckIfDue() }
            }
        }
        .alert(
            "Update available",
            isPresented: Binding(
                get: { updateCoordinator.pendingUpdate != nil },
                set: { if !$0 { updateCoordinator.dismiss() } }
            ),
            presenting: updateCoordinator.pendingUpdate
        ) { pending in
            switch pending.action {
            case .brewCommand:
                Button("Copy Upgrade Command") {
                    updateCoordinator.performPrimaryAction()
                }
            case .openRelease:
                Button("Download") {
                    updateCoordinator.performPrimaryAction()
                }
            }
            Button("Skip This Version") {
                updateCoordinator.skip(pending.version)
            }
            Button("Later", role: .cancel) {
                updateCoordinator.dismiss()
            }
        } message: { pending in
            switch pending.action {
            case .brewCommand(let cmd):
                Text("Mac Sai \(pending.version) is available. Upgrade with Homebrew:\n\(cmd)")
            case .openRelease:
                Text("Mac Sai \(pending.version) is available.")
            }
        }
    }

    @ViewBuilder
    private func moduleView(for item: SidebarItem) -> some View {
        switch item {
        case .smartScan:
            SmartScanView()
        case .systemJunk:
            SystemJunkView()
        case .mailAttachments:
            MailAttachmentsView()
        case .trashBins:
            TrashBinsView()
        case .diskHogs:
            DiskHogsView()
        case .projectJunk:
            ProjectJunkView()
        case .cleanHistory:
            CleanHistoryView()
        case .malwareRemoval:
            MalwareView()
        case .privacy:
            PrivacyView()
        case .browserExtensions:
            BrowserExtensionsView()
        case .wifiNetworks:
            WiFiNetworksView()
        case .appPermissions:
            AppPermissionsView()
        case .optimization:
            OptimizationView()
        case .maintenance:
            MaintenanceView()
        case .uninstaller:
            UninstallerView()
        case .unusedApps:
            UnusedAppsView()
        case .extensions:
            ExtensionsView()
        case .updater:
            UpdaterView()
        case .spaceLens:
            SpaceLensView()
        case .largeOldFiles:
            LargeOldFilesView()
        case .duplicates:
            DuplicatesView()
        case .shredder:
            ShredderView()
        case .settings:
            SettingsPageView()
        }
    }
}
