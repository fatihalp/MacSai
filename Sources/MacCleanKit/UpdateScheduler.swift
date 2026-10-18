import Foundation

public enum UpdateAction: Equatable, Sendable {

    case brewCommand(String)

    case openRelease(URL)
}

public enum UpdateScheduler {

    public static let checkInterval: TimeInterval = 24 * 60 * 60

    public static func isCheckDue(
        now: Date,
        lastCheck: Date?,
        interval: TimeInterval = checkInterval
    ) -> Bool {
        guard let lastCheck else { return true }
        return now.timeIntervalSince(lastCheck) >= interval
    }

    public static func shouldPrompt(
        result: UpdateChecker.CheckResult,
        skippedVersion: String?
    ) -> Bool {
        guard case .updateAvailable(let version, _) = result else { return false }
        return version != skippedVersion
    }

    public static func updateAction(
        isHomebrew: Bool,
        releaseURL: URL,
        brewCommand: String
    ) -> UpdateAction {
        isHomebrew ? .brewCommand(brewCommand) : .openRelease(releaseURL)
    }
}
