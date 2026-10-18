import Foundation

public enum DiskHogsText {
    public static var title: String { String(localized: "Disk Hogs") }
    public static var subtitle: String {
        String(localized: "Space used by Docker and Xcode simulators. Only the tools found on this Mac are shown, and nothing is selected for you.")
    }
    public static var refresh: String { String(localized: "Refresh") }
    public static var size: String { String(localized: "Size") }
    public static var xcodeSection: String { String(localized: "Xcode Simulators") }
    public static var unavailableSimulator: String { String(localized: "Unavailable simulator") }
    public static var olderRuntime: String { String(localized: "Older runtime") }
    public static var pruneButton: String {
        String(localized: "Prune Selected Docker Items…")
    }
    public static var deleteButton: String {
        String(localized: "Delete Selected Simulator Items…")
    }
    public static var dockerNotResponding: String {
        String(localized: "Docker is installed but not responding. Start Docker Desktop, then click Refresh.")
    }
    public static var nothingFound: String {
        String(localized: "No Docker or Xcode simulators found on this Mac.")
    }
    public static var pruneConfirmTitle: String {
        String(localized: "Permanently prune the selected Docker items?")
    }
    public static var pruneConfirmButton: String { String(localized: "Prune Permanently") }
    public static var deleteConfirmTitle: String {
        String(localized: "Permanently delete the selected simulator items?")
    }
    public static var deleteConfirmButton: String { String(localized: "Delete Permanently") }
    public static var runtimeShutdownNote: String {
        String(localized: "Deleting a runtime first shuts down any simulator using it, and those simulators become unavailable.")
    }
    public static var permanentNote: String {
        String(localized: "This is permanent. Nothing goes to the Trash.")
    }
    public static var cancel: String { String(localized: "Cancel") }
    public static var pruned: String { String(localized: "Pruned") }
    public static var deleted: String { String(localized: "Deleted") }
    public static var failed: String { String(localized: "Failed") }
    public static var timedOut: String { String(localized: "Timed out and was stopped") }
    public static var stopped: String { String(localized: "Stopped") }

    static var all: [String] {
        [title, subtitle, refresh, size, xcodeSection, unavailableSimulator, olderRuntime, pruneButton,
         deleteButton, dockerNotResponding, nothingFound, pruneConfirmTitle, pruneConfirmButton,
         deleteConfirmTitle, deleteConfirmButton, runtimeShutdownNote, permanentNote, cancel, pruned,
         deleted, failed, timedOut, stopped]
        + DockerDiskCategory.allCases.flatMap { [$0.label, $0.pruneNote] }
    }

    public static func statusLine(name: String, outcome: BoundedProcess.Outcome, success: String) -> String {
        switch outcome {
        case .exited(0, _, _):
            return "\(name): \(success)"
        case .timedOut:
            return "\(name): \(timedOut)"
        case .cancelled:
            return "\(name): \(stopped)"
        case .exited, .launchFailed:
            let detail = outcome.failureDetail
            return detail.isEmpty ? "\(name): \(failed)" : "\(name): \(failed) (\(detail))"
        }
    }
}
