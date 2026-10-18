import Foundation

public enum AppMatching {

    public enum MatchLevel: Int, CaseIterable, Sendable {
        case bundleIDExact = 1
        case displayName = 2
        case appDirName = 3
        case normalizedName = 4
        case bundleIDComponents = 5
        case baseBundleID = 6
        case versionStripped = 7
        case companyName = 8
        case teamIdentifier = 9
        case entitlements = 10
    }

    public static let librarySubdirectories: [String] = [
        "Application Support",
        "Caches",
        "Containers",
        "Group Containers",
        "Preferences",
        "Logs",
        "Application Scripts",
        "Cookies",
        "HTTPStorages",
        "LaunchAgents",
        "Saved Application State",
        "Internet Plug-Ins",
        "PreferencePanes",
        "PrivilegedHelperTools",
        "Services",
        "WebKit",
        "Frameworks",
    ]

    public static func generatePatterns(
        for app: AppInfo,
        maxLevel: MatchLevel = .versionStripped
    ) -> Set<String> {
        var patterns: Set<String> = []
        let levels = MatchLevel.allCases.filter { $0.rawValue <= maxLevel.rawValue }

        for level in levels {
            switch level {
            case .bundleIDExact:
                patterns.insert(app.bundleIdentifier.lowercased())

            case .displayName:
                patterns.insert(app.name.lowercased())

            case .appDirName:
                let dirName = app.path.deletingPathExtension().lastPathComponent.lowercased()
                patterns.insert(dirName)

            case .normalizedName:
                let normalized = app.name.lowercased().filter(\.isLetter)
                if normalized.count >= 3 {
                    patterns.insert(normalized)
                }

            case .bundleIDComponents:
                let components = app.bundleIdentifier.components(separatedBy: ".")
                if components.count >= 2 {
                    let last2 = components.suffix(2).joined(separator: ".").lowercased()
                    patterns.insert(last2)
                }

            case .baseBundleID:
                var baseID = app.bundleIdentifier.lowercased()
                for suffix in [".helper", ".agent", ".daemon", ".launcher", ".updater"] {
                    if baseID.hasSuffix(suffix) {
                        baseID = String(baseID.dropLast(suffix.count))
                    }
                }
                patterns.insert(baseID)

            case .versionStripped:
                let stripped = app.name.replacingOccurrences(
                    of: "\\d+(\\.\\d+)*",
                    with: "",
                    options: .regularExpression
                ).trimmingCharacters(in: .whitespaces).lowercased()
                if stripped.count >= 3 {
                    patterns.insert(stripped)
                }

            case .companyName:
                let components = app.bundleIdentifier.components(separatedBy: ".")
                if components.count >= 2 {
                    let company = components[1].lowercased()
                    if company.count >= 3 && company != "apple" {
                        patterns.insert(company)
                    }
                }

            case .teamIdentifier:

                break
            case .entitlements:

                break
            }
        }

        let genericPatterns: Set<String> = ["app"]
        return patterns.filter {
            $0.count >= 3 && !genericPatterns.contains($0)
        }
    }

    public static func filenameMatches(_ fileName: String, patterns: Set<String>) -> Bool {

        patterns.contains { !$0.isEmpty && containsWord($0, in: fileName) }
    }

    private static func containsWord(_ pattern: String, in fileName: String) -> Bool {
        var searchStart = fileName.startIndex
        while let range = fileName.range(of: pattern, options: .caseInsensitive,
                                         range: searchStart..<fileName.endIndex) {
            if isBoundary(in: fileName, at: range.lowerBound)
                && isBoundary(in: fileName, at: range.upperBound) {
                return true
            }
            searchStart = fileName.index(after: range.lowerBound)
        }
        return false
    }

    private static func isBoundary(in string: String, at index: String.Index) -> Bool {
        guard index > string.startIndex, index < string.endIndex else { return true }
        let before = string[string.index(before: index)]
        let after = string[index]

        func isWordCharacter(_ c: Character) -> Bool { c.isASCII && (c.isLetter || c.isNumber) }
        guard isWordCharacter(before), isWordCharacter(after) else { return true }
        if before.isLowercase && after.isUppercase { return true }
        return before.isNumber != after.isNumber
    }
}
