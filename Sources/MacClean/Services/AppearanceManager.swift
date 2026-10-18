import AppKit
import MacCleanKit

public enum AppearanceMode: String, CaseIterable, Identifiable {
    case light
    case system
    case dark

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .system: String(localized: "System")
        case .light: String(localized: "Light")
        case .dark: String(localized: "Dark")
        }
    }

    public var nsAppearance: NSAppearance? {
        switch self {
        case .system: nil
        case .light: NSAppearance(named: .aqua)
        case .dark: NSAppearance(named: .darkAqua)
        }
    }
}

@MainActor
public enum AppearanceManager {
    public static let defaultsKey = "appearanceMode"

    public static var storedMode: AppearanceMode {
        let raw = UserDefaults.standard.string(forKey: defaultsKey) ?? ""
        return AppearanceMode(rawValue: raw) ?? .light
    }

    public static func applyStored() {
        apply(storedMode)
    }

    public static func apply(_ mode: AppearanceMode) {
        NSApp.appearance = mode.nsAppearance
    }
}
