import Foundation
import AppKit
import ServiceManagement
import MacCleanKit

@MainActor
@Observable
public final class MenuBarLauncher {
    public enum LauncherError: Error, LocalizedError {
        case registrationFailed(String)
        case unregisterFailed(String)

        public var errorDescription: String? {
            switch self {
            case .registrationFailed(let msg):
                return "Couldn't enable the menu bar widget: \(msg)"
            case .unregisterFailed(let msg):
                return "Couldn't disable the menu bar widget: \(msg)"
            }
        }
    }

    public static let shared = MenuBarLauncher()

    public internal(set) var lastError: LauncherError?

    public internal(set) var isBusy = false

    public internal(set) var statusSnapshot: SMAppService.Status = .notRegistered

    private let service = SMAppService.loginItem(identifier: MCConstants.menuBundleIdentifier)
    private var helperTerminationObserver: NSObjectProtocol?
    private var isLaunchingHelper = false

    public var isRegistered: Bool {
        service.status == .enabled
    }

    public var status: SMAppService.Status {
        service.status
    }

    private init() {
        statusSnapshot = service.status
        startWatchingHelperTermination()
    }

    public func startWatchingHelperTermination() {
        guard helperTerminationObserver == nil else { return }
        helperTerminationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification,
            object: nil,
            queue: .main
        ) { note in
            guard
                let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                app.bundleIdentifier == MCConstants.menuBundleIdentifier
            else { return }
            Task { @MainActor in
                await MenuBarLauncher.shared.ensureHelperRunningIfPreferred()
            }
        }
    }

    public func ensureHelperRunningIfPreferred() async {
        let enabled = UserDefaults.standard.object(forKey: MenuBarKeepAlive.preferenceKey) as? Bool ?? true
        await reconcileHelper(
            preferenceEnabled: enabled,
            afterRegister: false,
            honorUserQuit: true
        )
    }

    public func register() throws {
        do {
            try service.register()
            lastError = nil
        } catch {
            let wrapped = LauncherError.registrationFailed(error.localizedDescription)
            lastError = wrapped
            throw wrapped
        }
    }

    public func unregister() throws {
        do {
            try service.unregister()
            lastError = nil
        } catch {
            let wrapped = LauncherError.unregisterFailed(error.localizedDescription)
            lastError = wrapped
            throw wrapped
        }
    }

    static let minimumBusyDuration: Duration = .milliseconds(450)

    public func setEnabled(_ enabled: Bool) async {
        isBusy = true
        let started = ContinuousClock.now
        defer { isBusy = false }

        let failure: String? = await Task.detached(priority: .userInitiated) {
            let service = SMAppService.loginItem(identifier: MCConstants.menuBundleIdentifier)
            do {
                if enabled { try service.register() } else { try service.unregister() }
                return nil
            } catch {
                return error.localizedDescription
            }
        }.value
        lastError = failure.map {
            enabled ? .registrationFailed($0) : .unregisterFailed($0)
        }
        if enabled {
            MenuBarKeepAlive.setUserQuit(false, defaults: SharedAppState.defaults)
        }
        await reconcileHelper(
            preferenceEnabled: enabled,
            afterRegister: enabled,
            honorUserQuit: false
        )
        statusSnapshot = service.status

        let elapsed = ContinuousClock.now - started
        if elapsed < Self.minimumBusyDuration {
            try? await Task.sleep(for: Self.minimumBusyDuration - elapsed)
        }
    }

    public func helperAppURL() -> URL? {
        let helper = Bundle.main.bundleURL
            .appending(path: "Contents")
            .appending(path: "Library")
            .appending(path: "LoginItems")
            .appending(path: "MacCleanMenu.app")
        guard FileManager.default.fileExists(atPath: helper.path) else { return nil }
        return helper
    }

    private func isHelperRunning() -> Bool {
        NSWorkspace.shared.runningApplications.contains {
            $0.bundleIdentifier == MCConstants.menuBundleIdentifier
        }
    }

    func reconcileHelper(
        preferenceEnabled: Bool,
        afterRegister: Bool,
        honorUserQuit: Bool
    ) async {
        var waited = !afterRegister
        let userQuit = honorUserQuit && MenuBarKeepAlive.isUserQuit(SharedAppState.defaults)
        while true {
            switch MenuBarKeepAlivePolicy.action(
                preferenceEnabled: preferenceEnabled,
                helperIsRunning: isHelperRunning(),
                userQuit: userQuit,
                alreadyWaitedAfterRegister: waited,
                launchInFlight: isLaunchingHelper
            ) {
            case .none:
                return
            case .waitThenRecheck:
                try? await Task.sleep(for: MenuBarKeepAlivePolicy.smAppServiceLaunchGrace)
                waited = true
            case .launch:
                guard let url = helperAppURL() else { return }
                isLaunchingHelper = true
                defer { isLaunchingHelper = false }
                await openHelper(at: url)
                return
            case .terminate:
                terminateRunningHelper()
                return
            }
        }
    }

    func openHelper(at url: URL) async {
        let config = Self.helperOpenConfiguration()
        do {
            _ = try await NSWorkspace.shared.openApplication(at: url, configuration: config)
        } catch {
            lastError = .registrationFailed(error.localizedDescription)
        }
    }

    nonisolated static func helperOpenConfiguration() -> NSWorkspace.OpenConfiguration {
        let config = NSWorkspace.OpenConfiguration()
        config.activates = false
        config.hides = false
        config.promptsUserIfNeeded = false
        return config
    }

    private func terminateRunningHelper() {
        for app in NSWorkspace.shared.runningApplications
        where app.bundleIdentifier == MCConstants.menuBundleIdentifier {
            app.terminate()
        }
    }
}
