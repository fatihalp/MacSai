import Foundation

public enum UpdateChecker {
    public enum CheckResult: Equatable, Sendable {
        case upToDate
        case updateAvailable(version: String, url: URL)
        case failed(message: String)
    }

    private struct LatestRelease: Decodable {
        let tag_name: String
        let html_url: String
    }

    public static func parseLatestRelease(_ data: Data) -> (version: String, url: URL)? {
        guard let release = try? JSONDecoder().decode(LatestRelease.self, from: data),
              let url = URL(string: release.html_url) else { return nil }
        var version = release.tag_name
        if version.hasPrefix("v") { version.removeFirst() }
        guard !version.isEmpty else { return nil }
        return (version, url)
    }

    public static func isNewer(_ candidate: String, than current: String) -> Bool {
        let lhs = candidate.split(separator: ".").map { Int($0) ?? 0 }
        let rhs = current.split(separator: ".").map { Int($0) ?? 0 }
        for i in 0..<max(lhs.count, rhs.count) {
            let l = i < lhs.count ? lhs[i] : 0
            let r = i < rhs.count ? rhs[i] : 0
            if l != r { return l > r }
        }
        return false
    }

    public static func preferredAppcastVersion(
        shortVersion: String?,
        buildVersion: String?
    ) -> String? {
        shortVersion ?? buildVersion
    }

    public static let defaultCaskroomPaths = [
        "/opt/homebrew/Caskroom/mac-sai",
        "/usr/local/Caskroom/mac-sai",
    ]

    public static func isHomebrewInstall(
        caskroomPaths: [String] = defaultCaskroomPaths,
        fileManager: FileManager = .default
    ) -> Bool {
        caskroomPaths.contains { fileManager.fileExists(atPath: $0) }
    }

    public static func updateSourceURL(isHomebrew: Bool) -> URL {
        isHomebrew ? MCConstants.homebrewCaskAPI : MCConstants.latestReleaseAPI
    }

    public static func parseCaskVersion(_ data: Data) -> String? {
        struct Cask: Decodable { let version: String }
        guard let cask = try? JSONDecoder().decode(Cask.self, from: data),
              !cask.version.isEmpty, cask.version != ":latest" else { return nil }
        return cask.version
    }

    public static func check(
        currentVersion: String = MCConstants.appVersion,
        session: URLSession = .shared,
        isHomebrew: Bool = isHomebrewInstall()
    ) async -> CheckResult {
        let sourceURL = updateSourceURL(isHomebrew: isHomebrew)
        var request = URLRequest(url: sourceURL, timeoutInterval: 10)
        request.setValue(
            isHomebrew ? "application/json" : "application/vnd.github+json",
            forHTTPHeaderField: "Accept")
        do {
            let (data, _) = try await session.data(for: request)
            let version: String
            let url: URL
            if isHomebrew {
                guard let caskVersion = parseCaskVersion(data) else {
                    return .failed(message: String(localized: "Unexpected response from Homebrew."))
                }
                version = caskVersion

                url = MCConstants.releasesURL
            } else {
                guard let parsed = parseLatestRelease(data) else {
                    return .failed(message: String(localized: "Unexpected response from GitHub."))
                }
                version = parsed.version
                url = parsed.url
            }
            return isNewer(version, than: currentVersion)
                ? .updateAvailable(version: version, url: url)
                : .upToDate
        } catch {
            return .failed(message: error.localizedDescription)
        }
    }
}
