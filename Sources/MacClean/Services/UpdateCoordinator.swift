import SwiftUI
import AppKit
import MacCleanKit

@MainActor
@Observable
final class UpdateCoordinator {
    struct PendingUpdate: Identifiable, Equatable {
        let version: String
        let action: UpdateAction
        var id: String { version }
    }

    var pendingUpdate: PendingUpdate?

    private let defaults = UserDefaults.standard
    private enum Key {
        static let autoCheck = "automaticUpdateChecks"
        static let lastCheck = "lastUpdateCheckDate"
        static let skipped = "skippedUpdateVersion"
    }

    private var automaticChecksEnabled: Bool {
        defaults.object(forKey: Key.autoCheck) == nil ? true : defaults.bool(forKey: Key.autoCheck)
    }

    private var lastCheck: Date? {
        let t = defaults.double(forKey: Key.lastCheck)
        return t == 0 ? nil : Date(timeIntervalSinceReferenceDate: t)
    }

    func runCheckIfDue() async {
        guard automaticChecksEnabled, pendingUpdate == nil else { return }
        guard UpdateScheduler.isCheckDue(now: Date(), lastCheck: lastCheck) else { return }

        let result = await UpdateChecker.check()

        defaults.set(Date().timeIntervalSinceReferenceDate, forKey: Key.lastCheck)

        guard UpdateScheduler.shouldPrompt(
            result: result,
            skippedVersion: defaults.string(forKey: Key.skipped)
        ), case .updateAvailable(let version, let url) = result else { return }

        let action = UpdateScheduler.updateAction(
            isHomebrew: UpdateChecker.isHomebrewInstall(),
            releaseURL: url,
            brewCommand: "brew upgrade --cask mac-sai"
        )
        pendingUpdate = PendingUpdate(version: version, action: action)
    }

    func skip(_ version: String) {
        defaults.set(version, forKey: Key.skipped)
        pendingUpdate = nil
    }

    func dismiss() {
        pendingUpdate = nil
    }

    func performPrimaryAction() {
        switch pendingUpdate?.action {
        case .brewCommand(let cmd):
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(cmd, forType: .string)
        case .openRelease(let url):
            NSWorkspace.shared.open(url)
        case nil:
            break
        }
        pendingUpdate = nil
    }
}
