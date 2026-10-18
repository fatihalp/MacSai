import Foundation

public struct MenuBarInstance: Equatable, Sendable {
    public let pid: Int32
    public let launchDate: Date?

    public init(pid: Int32, launchDate: Date?) {
        self.pid = pid
        self.launchDate = launchDate
    }
}

public enum MenuBarInstancePolicy {
    public static func shouldExitAsDuplicate(
        selfPID: Int32,
        selfLaunchDate: Date?,
        siblings: [MenuBarInstance]
    ) -> Bool {
        guard !siblings.isEmpty else { return false }
        let selfInstance = MenuBarInstance(pid: selfPID, launchDate: selfLaunchDate)
        let keeper = (siblings + [selfInstance]).min { rank($0) < rank($1) }
        return keeper?.pid != selfPID
    }

    private static func rank(_ instance: MenuBarInstance) -> (Date, Int32) {
        (instance.launchDate ?? .distantFuture, instance.pid)
    }
}

public enum MenuBarKeepAlive {
    public static let userQuitKey = "menuBarWidgetUserQuit"
    public static let preferenceKey = "showMenuBarWidget"

    public static func isUserQuit(_ defaults: UserDefaults) -> Bool {
        defaults.bool(forKey: userQuitKey)
    }

    public static func setUserQuit(_ value: Bool, defaults: UserDefaults) {
        defaults.set(value, forKey: userQuitKey)
    }
}

public enum MenuBarKeepAlivePolicy {
    public enum Action: Equatable, Sendable {
        case none
        case waitThenRecheck
        case launch
        case terminate
    }

    public static let smAppServiceLaunchGrace: Duration = .milliseconds(500)

    public static func action(
        preferenceEnabled: Bool,
        helperIsRunning: Bool,
        userQuit: Bool,
        alreadyWaitedAfterRegister: Bool,
        launchInFlight: Bool
    ) -> Action {
        if !preferenceEnabled {
            return helperIsRunning ? .terminate : .none
        }
        if helperIsRunning || userQuit || launchInFlight {
            return .none
        }
        if !alreadyWaitedAfterRegister {
            return .waitThenRecheck
        }
        return .launch
    }
}
