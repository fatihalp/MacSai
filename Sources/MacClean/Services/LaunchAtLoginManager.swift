import Foundation
import ServiceManagement
import MacCleanKit

@MainActor
@Observable
public final class LaunchAtLoginManager {
    public enum LaunchAtLoginError: Error, LocalizedError {
        case updateFailed(enabling: Bool, message: String)

        public var errorDescription: String? {
            switch self {
            case .updateFailed(let enabling, let message):
                let action = enabling ? String(localized: "enable") : String(localized: "disable")
                return "Couldn't \(action) launch at login: \(message)"
            }
        }
    }

    public static let shared = LaunchAtLoginManager()

    public internal(set) var lastError: LaunchAtLoginError?
    private let statusProvider: @MainActor () -> SMAppService.Status
    private let registrationUpdater: @Sendable (Bool) -> String?
    private let busyDuration: Duration

    public internal(set) var isBusy = false

    public internal(set) var status: SMAppService.Status = .notRegistered

    public var isEnabled: Bool { status == .enabled }

    private init() {
        statusProvider = { SMAppService.mainApp.status }
        registrationUpdater = { enabled in
            do {
                if enabled { try SMAppService.mainApp.register() }
                else { try SMAppService.mainApp.unregister() }
                return nil
            } catch {
                return error.localizedDescription
            }
        }
        busyDuration = Self.minimumBusyDuration
        status = statusProvider()
    }

    init(
        statusProvider: @escaping @MainActor () -> SMAppService.Status,
        registrationUpdater: @escaping @Sendable (Bool) -> String?,
        minimumBusyDuration: Duration
    ) {
        self.statusProvider = statusProvider
        self.registrationUpdater = registrationUpdater
        busyDuration = minimumBusyDuration
        status = statusProvider()
    }

    static let minimumBusyDuration: Duration = .milliseconds(450)

    @discardableResult
    public func refreshStatus() -> Bool {
        status = statusProvider()
        return isEnabled
    }

    @discardableResult
    public func setEnabled(_ enabled: Bool) async -> Bool {
        isBusy = true
        let started = ContinuousClock.now
        defer { isBusy = false }

        let registrationUpdater = registrationUpdater
        let failure: String? = await Task.detached(priority: .userInitiated) {
            registrationUpdater(enabled)
        }.value
        lastError = failure.map { .updateFailed(enabling: enabled, message: $0) }

        let elapsed = ContinuousClock.now - started
        if elapsed < busyDuration {
            try? await Task.sleep(for: busyDuration - elapsed)
        }
        return refreshStatus()
    }
}
