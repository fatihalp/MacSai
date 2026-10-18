import Foundation

public struct ScanTarget: Sendable, Equatable {
    public let path: URL
    public let recursive: Bool
    public let maxDepth: Int?
    public let fileExtensions: Set<String>?
    public let minAge: TimeInterval?
    public let maxAge: TimeInterval?
    public let minSize: UInt64?
    public let excludePatterns: [String]

    public let skipHiddenDirectories: Bool

    public let excludedPaths: [URL]

    public init(
        path: URL,
        recursive: Bool = true,
        maxDepth: Int? = nil,
        fileExtensions: Set<String>? = nil,
        minAge: TimeInterval? = nil,
        maxAge: TimeInterval? = nil,
        minSize: UInt64? = nil,
        excludePatterns: [String] = [],
        skipHiddenDirectories: Bool = false,
        excludedPaths: [URL] = []
    ) {
        self.path = path
        self.recursive = recursive
        self.maxDepth = maxDepth

        self.fileExtensions = fileExtensions.map { Set($0.map { $0.lowercased() }) }
        self.minAge = minAge
        self.maxAge = maxAge
        self.minSize = minSize
        self.excludePatterns = excludePatterns
        self.skipHiddenDirectories = skipHiddenDirectories
        self.excludedPaths = excludedPaths
    }

    public func isExcludedPath(_ url: URL) -> Bool {
        let path = url.path(percentEncoded: false)
        return excludedPaths.contains {
            PathExclusion.isInside(path, root: $0.path(percentEncoded: false))
        }
    }

    public static func isHiddenEntry(_ url: URL) -> Bool {
        url.lastPathComponent.hasPrefix(".")
    }

    public func matchesByNameRules(_ url: URL) -> Bool {
        let name = url.lastPathComponent

        for pattern in excludePatterns {
            if name.localizedCaseInsensitiveContains(pattern) {
                return false
            }
        }

        if let extensions = fileExtensions, !extensions.isEmpty {
            let ext = url.pathExtension.lowercased()
            if !extensions.contains(ext) {
                return false
            }
        }

        return true
    }

    public func passesSizeFilter(_ size: UInt64) -> Bool {
        guard let minSize else { return true }
        return size >= minSize
    }

    public func passesAgeFilters(modificationDate: Date?, now: Date = Date()) -> Bool {
        guard minAge != nil || maxAge != nil else { return true }
        guard let modDate = modificationDate else { return false }
        let age = now.timeIntervalSince(modDate)
        if let minAge, age < minAge { return false }
        if let maxAge, age > maxAge { return false }
        return true
    }
}
