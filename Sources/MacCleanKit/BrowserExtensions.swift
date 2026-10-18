import Foundation

public enum BrowserKind: String, Equatable, Sendable, CaseIterable, Identifiable {
    case safari
    case chrome
    case brave
    case edge
    case arc
    case firefox

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .safari: "Safari"
        case .chrome: "Chrome"
        case .brave: "Brave"
        case .edge: "Edge"
        case .arc: "Arc"
        case .firefox: "Firefox"
        }
    }

    public var bundleIdentifiers: Set<String> {
        switch self {
        case .safari: ["com.apple.Safari"]
        case .chrome: ["com.google.Chrome"]
        case .brave: ["com.brave.Browser"]
        case .edge: ["com.microsoft.edgemac"]
        case .arc: ["company.thebrowser.Browser"]
        case .firefox: [
            "org.mozilla.firefox",
            "org.mozilla.firefoxbeta",
            "org.mozilla.firefoxdeveloperedition",
            "org.mozilla.nightly",
        ]
        }
    }

    public var primaryBundleIdentifier: String {
        switch self {
        case .safari: "com.apple.Safari"
        case .chrome: "com.google.Chrome"
        case .brave: "com.brave.Browser"
        case .edge: "com.microsoft.edgemac"
        case .arc: "company.thebrowser.Browser"
        case .firefox: "org.mozilla.firefox"
        }
    }

    public var chromiumUserDataRelativePath: String? {
        switch self {
        case .chrome: "Google/Chrome"
        case .brave: "BraveSoftware/Brave-Browser"
        case .edge: "Microsoft Edge"
        case .arc: "Arc/User Data"
        case .safari, .firefox: nil
        }
    }

    public static let chromiumFamily: [BrowserKind] = [.chrome, .brave, .edge, .arc]
}

public enum BrowserExtensionOrigin: String, Equatable, Hashable, Sendable {

    case user

    case policy

    case component

    case safariApp
}

public struct BrowserExtensionRecord: Equatable, Hashable, Sendable, Identifiable {

    public var id: String { "\(browser.rawValue)|\(profile)|\(identifier)" }

    public let browser: BrowserKind

    public let profile: String
    public let identifier: String
    public let name: String

    public let updatedAt: Date?
    public let path: String
    public let origin: BrowserExtensionOrigin

    public let isSuspicious: Bool

    public init(
        browser: BrowserKind,
        profile: String,
        identifier: String,
        name: String,
        updatedAt: Date?,
        path: String,
        origin: BrowserExtensionOrigin,
        isSuspicious: Bool
    ) {
        self.browser = browser
        self.profile = profile
        self.identifier = identifier
        self.name = name
        self.updatedAt = updatedAt
        self.path = path
        self.origin = origin
        self.isSuspicious = isSuspicious
    }
}

public enum MaliciousExtensionIDs {
    public static let known: Set<String> = []

    public static func contains(_ extensionID: String, in known: Set<String> = known) -> Bool {
        known.contains(extensionID.lowercased())
    }
}

public struct BrowserExtensionScan: Equatable, Sendable {
    public let records: [BrowserExtensionRecord]

    public let safariListed: Bool

    public init(records: [BrowserExtensionRecord], safariListed: Bool) {
        self.records = records
        self.safariListed = safariListed
    }
}

public enum BrowserExtensionSuspicion {
    public static func isSuspicious(
        identifier: String,
        name: String,
        knownBadIDs: Set<String> = MaliciousExtensionIDs.known
    ) -> Bool {
        MaliciousExtensionIDs.contains(identifier, in: knownBadIDs)
            || MalwareSignatures.nameMatchesKnownPattern(name)
    }
}

public enum BrowserExtensionRemovalPlan: Equatable, Sendable {

    case removeInBrowser(BrowserKind)
    case deleteFolder(String)
    case managedByPolicy(BrowserKind)
    case builtIn(BrowserKind)
    case safariSettings

    case refuse
}

public enum BrowserExtensionRemoval {
    public static func plan(
        record: BrowserExtensionRecord,
        browserIsRunning: Bool
    ) -> BrowserExtensionRemovalPlan {
        switch record.origin {
        case .safariApp: return .safariSettings
        case .policy: return .managedByPolicy(record.browser)
        case .component: return .builtIn(record.browser)
        case .user: break
        }
        if record.browser == .safari { return .safariSettings }
        if browserIsRunning { return .removeInBrowser(record.browser) }
        guard isSafeDeletionPath(record) else { return .refuse }
        return .deleteFolder(record.path)
    }

    public static func isSafeDeletionPath(_ record: BrowserExtensionRecord) -> Bool {
        let path = URL(filePath: record.path).standardizedFileURL
        let components = path.pathComponents
        guard !record.path.contains("/../"), components.count >= 4 else { return false }
        let leaf = components[components.count - 1]
        let parent = components[components.count - 2]
        let profile = components[components.count - 3]
        guard profile == record.profile else { return false }
        switch record.browser {
        case .chrome, .brave, .edge, .arc:
            return parent == "Extensions"
                && leaf == record.identifier
                && ChromiumExtensionID.isValid(leaf)
        case .firefox:
            return parent == "extensions" && !leaf.isEmpty && leaf != "." && leaf != ".."
        case .safari:
            return false
        }
    }
}

public enum ChromiumExtensionID {

    public static func isValid(_ id: String) -> Bool {
        id.count == 32 && id.unicodeScalars.allSatisfy { $0.value >= 97 && $0.value <= 112 }
    }
}

public enum ChromiumVersionFolder {

    public static func newest(_ names: [String]) -> String? {
        names.max { isOrderedBefore($0, $1) }
    }

    static func isOrderedBefore(_ lhs: String, _ rhs: String) -> Bool {
        let a = numbers(lhs), b = numbers(rhs)
        for index in 0..<max(a.count, b.count) {
            let x = index < a.count ? a[index] : 0
            let y = index < b.count ? b[index] : 0
            if x != y { return x < y }
        }
        return lhs < rhs
    }

    private static func numbers(_ name: String) -> [Int] {
        name.split(whereSeparator: { $0 == "." || $0 == "_" }).map { Int($0) ?? 0 }
    }
}

public enum ChromiumPreferences {
    public static let componentLocations: Set<Int> = [5, 10]
    public static let policyLocations: Set<Int> = [7, 9]

    public static func locations(fromPreferencesJSON data: Data) -> [String: Int] {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let extensions = root["extensions"] as? [String: Any],
              let settings = extensions["settings"] as? [String: Any]
        else { return [:] }
        var result: [String: Int] = [:]
        for (id, value) in settings {
            if let entry = value as? [String: Any], let location = entry["location"] as? Int {
                result[id] = location
            }
        }
        return result
    }

    public static func forcedIDs(fromPolicyPlist plist: [String: Any]) -> Set<String> {
        guard let list = plist["ExtensionInstallForcelist"] as? [String] else { return [] }
        return Set(list.compactMap { entry in
            entry.split(separator: ";").first.map { String($0).trimmingCharacters(in: .whitespaces).lowercased() }
        })
    }

    public static func origin(for id: String, location: Int?, forcedIDs: Set<String>) -> BrowserExtensionOrigin {
        if forcedIDs.contains(id.lowercased()) { return .policy }
        guard let location else { return .user }
        if policyLocations.contains(location) { return .policy }
        if componentLocations.contains(location) { return .component }
        return .user
    }
}

public enum BrowserExtensionManifest {

    public static func chromeFamily(
        json: Data,
        extensionID: String,
        browser: BrowserKind,
        profile: String,
        path: String,
        updatedAt: Date?,
        origin: BrowserExtensionOrigin = .user,
        knownBadIDs: Set<String> = MaliciousExtensionIDs.known,
        messages: (String) -> Data? = { _ in nil }
    ) -> BrowserExtensionRecord? {
        guard ChromiumExtensionID.isValid(extensionID) else { return nil }
        struct Manifest: Decodable {
            let name: String?
            let default_locale: String?
        }
        guard let manifest = try? JSONDecoder().decode(Manifest.self, from: json) else { return nil }
        var name = manifest.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if name.hasPrefix("__MSG_"), name.hasSuffix("__"), name.count > 8 {
            let key = String(name.dropFirst(6).dropLast(2))
            var locales: [String] = []
            if let preferred = manifest.default_locale, !preferred.isEmpty { locales.append(preferred) }
            locales += ["en", "en_US", "en_GB"]
            var seen = Set<String>()
            name = ""
            for locale in locales where seen.insert(locale).inserted {
                if let data = messages(locale), let localized = localizedMessage(key: key, from: data),
                   !localized.trimmingCharacters(in: .whitespaces).isEmpty {
                    name = localized.trimmingCharacters(in: .whitespacesAndNewlines)
                    break
                }
            }
        }
        if name.isEmpty { name = extensionID }
        return BrowserExtensionRecord(
            browser: browser,
            profile: profile,
            identifier: extensionID,
            name: name,
            updatedAt: updatedAt,
            path: path,
            origin: origin,
            isSuspicious: BrowserExtensionSuspicion.isSuspicious(
                identifier: extensionID, name: name, knownBadIDs: knownBadIDs
            )
        )
    }

    public static func firefox(
        json: Data,
        profilePath: String,
        knownBadIDs: Set<String> = MaliciousExtensionIDs.known
    ) -> [BrowserExtensionRecord] {
        struct Payload: Decodable {
            struct Addon: Decodable {
                struct Locale: Decodable { let name: String? }
                let id: String
                let type: String?
                let defaultLocale: Locale?
                let installDate: Double?
                let updateDate: Double?
                let path: String?
                let location: String?
            }
            let addons: [Addon]
        }
        guard let payload = try? JSONDecoder().decode(Payload.self, from: json) else { return [] }
        let profileURL = URL(filePath: profilePath).standardizedFileURL
        let profileName = profileURL.lastPathComponent
        let extensionsDir = profileURL.appending(path: "extensions").standardizedFileURL
        return payload.addons.compactMap { addon in
            guard (addon.type ?? "extension") == "extension" else { return nil }

            guard addon.location == "app-profile", let rawPath = addon.path,
                  !rawPath.split(separator: "/").contains("..")
            else { return nil }
            let fileURL = URL(filePath: rawPath).standardizedFileURL
            guard fileURL.deletingLastPathComponent().pathComponents == extensionsDir.pathComponents
            else { return nil }
            let stamp = addon.updateDate ?? addon.installDate
            let name = addon.defaultLocale?.name?.trimmingCharacters(in: .whitespacesAndNewlines)
            let displayName = (name?.isEmpty == false ? name : nil) ?? addon.id
            return BrowserExtensionRecord(
                browser: .firefox,
                profile: profileName,
                identifier: addon.id,
                name: displayName,
                updatedAt: stamp.map { Date(timeIntervalSince1970: $0 / 1000) },
                path: fileURL.path(percentEncoded: false),
                origin: .user,
                isSuspicious: BrowserExtensionSuspicion.isSuspicious(
                    identifier: addon.id, name: displayName, knownBadIDs: knownBadIDs
                )
            )
        }
    }

    public static func safari(_ items: [ManagedExtension], updatedAt: (URL) -> Date? = { _ in nil }) -> [BrowserExtensionRecord] {
        items

            .filter { $0.kind == .safariExtension && !$0.isApple && $0.path.pathExtension.lowercased() == "appex" }
            .map { item in
                BrowserExtensionRecord(
                    browser: .safari,
                    profile: "",
                    identifier: item.bundleIdentifier.isEmpty ? item.id : item.bundleIdentifier,
                    name: item.name,
                    updatedAt: updatedAt(item.path),
                    path: item.path.path(percentEncoded: false),
                    origin: .safariApp,
                    isSuspicious: MalwareSignatures.nameMatchesKnownPattern(item.name)
                )
            }
    }

    private static func localizedMessage(key: String, from data: Data) -> String? {
        struct Entry: Decodable { let message: String? }
        guard let dict = try? JSONDecoder().decode([String: Entry].self, from: data) else { return nil }

        if let exact = dict[key]?.message { return exact }
        return dict.first { $0.key.caseInsensitiveCompare(key) == .orderedSame }?.value.message
    }
}
