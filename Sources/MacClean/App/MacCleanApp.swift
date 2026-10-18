import SwiftUI
import AppKit
import MacCleanKit

@main
struct MacCleanApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var appState = AppState()
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("showMenuBarWidget") private var showMenuBarWidget = true
    @AppStorage("menuBarFirstLaunchDone") private var menuBarFirstLaunchDone = false
    @AppStorage(Localization.defaultsKey, store: SharedAppState.defaults) private var appLanguage = "en"
    @State private var showOnboarding = false

    var body: some Scene {
        Window(MCConstants.appName, id: "main") {
            ContentView()
                .environment(appState)
                .environment(\.locale, Localization.locale(for: appLanguage))
                .preferredColorScheme(.light)
                .id(appLanguage)
                .frame(minWidth: 880, minHeight: 580)
                .sheet(isPresented: $showOnboarding) {
                    OnboardingView(isPresented: $showOnboarding)
                        .environment(\.locale, Localization.locale(for: appLanguage))
                        .preferredColorScheme(.light)
                        .id(appLanguage)
                }
                .onAppear {
                    AppearanceManager.apply(.light)
                    if !hasCompletedOnboarding {
                        showOnboarding = true
                        hasCompletedOnboarding = true
                    }
                    syncMenuBarOnLaunch()
                }
                .onOpenURL { url in
                    guard url.scheme == "macclean", url.host == "module",
                          url.pathComponents.count == 2,
                          let id = url.pathComponents.last,
                          let item = SidebarItem(deepLinkID: id) else { return }
                    appState.selectedSidebarItem = item
                }
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: true))
        .defaultSize(width: 1000, height: 650)
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("Settings…") {
                    appState.selectedSidebarItem = .settings
                }
                .keyboardShortcut(",", modifiers: .command)
            }
            CommandGroup(after: .sidebar) {
                Button("Scan") {
                    appState.requestScanShortcut()
                }
                .keyboardShortcut("r", modifiers: .command)

                Button("Clean Selected") {
                    appState.requestCleanShortcut()
                }
                .keyboardShortcut("k", modifiers: .command)

                Divider()

                ForEach(1...9, id: \.self) { digit in
                    if let item = SidebarItem.item(forShortcutDigit: digit) {
                        Button(item.title) {
                            appState.selectedSidebarItem = item
                        }
                        .keyboardShortcut(KeyEquivalent(Character(String(digit))), modifiers: .command)
                    }
                }
            }
        }
    }

    private func syncMenuBarOnLaunch() {
        if !menuBarFirstLaunchDone {
            menuBarFirstLaunchDone = true
        }
        Task { await MenuBarLauncher.shared.setEnabled(showMenuBarWidget) }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        UserDefaults.standard.set(AppearanceMode.light.rawValue, forKey: AppearanceManager.defaultsKey)
        AppearanceManager.apply(.light)
        MenuBarLauncher.shared.startWatchingHelperTermination()
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}
