import Foundation

public enum UnusedAppHorizon: String, CaseIterable, Sendable, Identifiable {
    case threeMonths = "3"
    case sixMonths = "6"
    case twelveMonths = "12"

    public var id: String { rawValue }

    public var months: Int {
        switch self {
        case .threeMonths: 3
        case .sixMonths: 6
        case .twelveMonths: 12
        }
    }

    public func cutoff(from now: Date, calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: .month, value: -months, to: now) ?? now
    }

    public var label: String {
        switch self {
        case .threeMonths:
            String(localized: "3 months")
        case .sixMonths:
            String(localized: "6 months")
        case .twelveMonths:
            String(localized: "12 months")
        }
    }
}

public struct UnusedAppRecord: Equatable, Hashable, Sendable, Identifiable {
    public var id: String { path }

    public let name: String
    public let bundleIdentifier: String
    public let path: String
    public let appBytes: UInt64
    public let supportBytes: UInt64
    public let lastUsed: Date?
    public let isApple: Bool
    public let runsInBackground: Bool

    public let isRunning: Bool

    public var totalBytes: UInt64 { appBytes &+ supportBytes }

    public init(
        name: String,
        bundleIdentifier: String,
        path: String,
        appBytes: UInt64,
        supportBytes: UInt64,
        lastUsed: Date?,
        isApple: Bool,
        runsInBackground: Bool,
        isRunning: Bool = false
    ) {
        self.name = name
        self.bundleIdentifier = bundleIdentifier
        self.path = path
        self.appBytes = appBytes
        self.supportBytes = supportBytes
        self.lastUsed = lastUsed
        self.isApple = isApple
        self.runsInBackground = runsInBackground
        self.isRunning = isRunning
    }
}

public enum UnusedApps {

    public static func unused(
        from apps: [UnusedAppRecord],
        horizon: UnusedAppHorizon,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [UnusedAppRecord] {
        let cutoff = horizon.cutoff(from: now, calendar: calendar)
        return apps
            .filter { !$0.isApple && !$0.isRunning }
            .filter { app in
                guard let lastUsed = app.lastUsed else { return false }
                return lastUsed <= cutoff
            }
            .sorted { lhs, rhs in
                if lhs.totalBytes != rhs.totalBytes {
                    return lhs.totalBytes > rhs.totalBytes
                }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
    }
}

extension UnusedApps {

    public static func usageDataUnavailable(in apps: [UnusedAppRecord]) -> Bool {
        let thirdParty = apps.filter { !$0.isApple }
        guard !thirdParty.isEmpty else { return false }
        let missing = thirdParty.filter { $0.lastUsed == nil }.count
        return Double(missing) / Double(thirdParty.count) >= 0.8
    }
}

public enum AppRuntimeRole {
    public static func runsInBackground(infoPlist: [String: Any]) -> Bool {
        truthy(infoPlist["LSUIElement"]) || truthy(infoPlist["LSBackgroundOnly"])
    }

    private static func truthy(_ value: Any?) -> Bool {
        switch value {
        case let flag as Bool:
            return flag
        case let number as NSNumber:
            return number.boolValue
        case let text as String:
            let lowered = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            return lowered == "yes" || lowered == "true" || lowered == "1"
        default:
            return false
        }
    }
}
