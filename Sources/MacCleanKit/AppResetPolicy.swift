import Foundation

public enum AppResetPolicy {

    public enum Decision: Equatable, Sendable {
        case resetable
        case keepBundle
        case keepUserData
        case keepSystemIntegration
    }

    public static func isResetable(url: URL, appBundle: URL) -> Bool {
        decision(for: url, appBundle: appBundle) == .resetable
    }

    public static func decision(for url: URL, appBundle: URL) -> Decision {
        let path = url.path(percentEncoded: false)
        let bundlePath = appBundle.path(percentEncoded: false)
        if isInside(path, root: bundlePath) {
            return .keepBundle
        }
        if isUnderAny(path, of: resetableRoots) {
            return .resetable
        }
        if isUnderAny(path, of: userDataRoots) {
            return .keepUserData
        }
        return .keepSystemIntegration
    }

    public static func resetableItems(
        from associatedFiles: [FileItem],
        selected: Set<URL>,
        appBundle: URL
    ) -> [FileItem] {
        associatedFiles.filter { item in
            selected.contains(item.url) && isResetable(url: item.url, appBundle: appBundle)
        }
    }

    private static let resetableRoots: [URL] = [
        MCConstants.userCaches,
        MCConstants.userPreferences,
        MCConstants.userSavedAppState,
        MCConstants.userLogs,
        MCConstants.userCookies,
        MCConstants.userHTTPStorages,
        MCConstants.userWebKit,
    ]

    private static let userDataRoots: [URL] = [
        MCConstants.userAppSupport,
        MCConstants.userContainers,
        MCConstants.userGroupContainers,
        MCConstants.userAppScripts,
    ]

    private static func isInside(_ path: String, root: String) -> Bool {
        if path == root { return true }
        let prefix = root.hasSuffix("/") ? root : root + "/"
        return path.hasPrefix(prefix)
    }

    private static func isUnderAny(_ path: String, of roots: [URL]) -> Bool {
        roots.contains { isInside(path, root: $0.path(percentEncoded: false)) }
    }
}
