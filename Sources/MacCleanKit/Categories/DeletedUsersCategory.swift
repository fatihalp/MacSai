import Foundation

public struct DeletedUsersCategory: JunkCategory {
    public init() {}

    public let scanCategory = ScanCategory.deletedUsers

    public var targets: [ScanTarget] { [] }

    public static let systemFolders: Set<String> = ["Shared", ".localized", "Guest"]

    public static func isResidualHomeFolder(name: String, activeUsers: Set<String>) -> Bool {
        if systemFolders.contains(name) { return false }
        if name.hasPrefix(".") { return false }
        return !activeUsers.contains(name)
    }

    public static func parseDsclOutput(_ output: String) -> Set<String> {
        Set(
            output
                .components(separatedBy: "\n")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty && !$0.hasPrefix("_") }
        )
    }
}
