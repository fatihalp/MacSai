import Foundation

public struct SafetyGuard: Sendable {
    public enum SafetyError: Error, LocalizedError, Equatable {
        case protectedPath(String)
        case tooManyFiles(Int)
        case symlinkTarget(String)
        case sipProtected(String)
        case outsideUserScope(String)
        case invalidPath(String)
        case userExcluded(String)

        public var errorDescription: String? {
            switch self {
            case .protectedPath(let path):
                "Cannot modify protected system path: \(path)"
            case .tooManyFiles(let count):
                "Operation exceeds safety limit of \(MCConstants.maxFilesPerOperation) files (attempted: \(count))"
            case .symlinkTarget(let path):
                "Path resolves through symlink to unexpected location: \(path)"
            case .sipProtected(let path):
                "Path is protected by System Integrity Protection: \(path)"
            case .outsideUserScope(let path):
                "Path is outside the allowed user scope: \(path)"
            case .invalidPath(let path):
                "Path is invalid or contains illegal characters: \(path)"
            case .userExcluded(let path):
                "Path is inside an excluded folder: \(path)"
            }
        }
    }

    public init() {}

    public func validateDeletion(paths: [URL]) throws {
        if paths.count > MCConstants.maxFilesPerOperation {
            throw SafetyError.tooManyFiles(paths.count)
        }

        for path in paths {
            try validatePath(path)
        }
    }

    public func validatePath(
        _ url: URL,
        excludedFolders: [String] = FolderExclusionPreferences.paths
    ) throws {
        let original = url.path(percentEncoded: false)

        if original.isEmpty {
            throw SafetyError.invalidPath("(empty)")
        }
        if original.contains("\0") {
            throw SafetyError.invalidPath(original)
        }

        let resolvedPath = url.resolvingSymlinksInPath().path(percentEncoded: false)

        let originalCanonical = Self.canonicalizeMacOSFirmlinks(original)
        let resolvedCanonical = Self.canonicalizeMacOSFirmlinks(resolvedPath)

        if resolvedCanonical.hasPrefix("/System/") || resolvedCanonical == "/System" {
            throw SafetyError.sipProtected(resolvedPath)
        }

        for protected in Self.canonicalProtectedPaths {
            if resolvedCanonical.hasPrefix(protected + "/") || resolvedCanonical == protected {
                throw SafetyError.protectedPath(resolvedPath)
            }
        }

        if PathExclusion.isExcluded(path: resolvedCanonical, by: excludedFolders)
            || PathExclusion.isExcluded(path: originalCanonical, by: excludedFolders) {
            throw SafetyError.userExcluded(resolvedPath)
        }

        if originalCanonical != resolvedCanonical {
            let originalComponents = originalCanonical.components(separatedBy: "/")
            let resolvedComponents = resolvedCanonical.components(separatedBy: "/")
            if originalComponents.prefix(3) != resolvedComponents.prefix(3) {
                throw SafetyError.symlinkTarget(resolvedPath)
            }
        }
    }

    private static let canonicalProtectedPaths: Set<String> =
        Set(MCConstants.protectedPaths.map(SafetyGuard.canonicalizeMacOSFirmlinks))

    static func canonicalizeMacOSFirmlinks(_ path: String) -> String {
        for firmlink in ["var", "tmp", "etc"] {
            let privatePrefix = "/private/\(firmlink)"
            if path == privatePrefix {
                return "/\(firmlink)"
            }
            if path.hasPrefix(privatePrefix + "/") {
                return "/\(firmlink)" + path.dropFirst(privatePrefix.count)
            }
        }
        return path
    }

    public func isProtectedApp(_ bundleID: String) -> Bool {
        MCConstants.protectedApps.contains(bundleID)
    }

    public func isSafeForOrphanDeletion(_ url: URL) -> Bool {
        let path = url.path(percentEncoded: false)
        let safePrefixes = [
            MCConstants.userCaches.path(percentEncoded: false),
            MCConstants.userLogs.path(percentEncoded: false),
            MCConstants.userHTTPStorages.path(percentEncoded: false),
            MCConstants.userSavedAppState.path(percentEncoded: false),
            MCConstants.userWebKit.path(percentEncoded: false),
        ]
        return safePrefixes.contains { path.hasPrefix($0) }
    }
}
