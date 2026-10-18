import Foundation

public struct AppLanguage: Identifiable, Hashable, Sendable {
    public let id: String

    public init(id: String) {
        self.id = id
    }

    public var name: String {
        id == "system" ? "System" : (Locale(identifier: id).localizedString(forIdentifier: id)?.capitalized ?? id)
    }

    public static let all: [AppLanguage] = ["system", "en", "de", "fr", "it", "ru", "zh-Hans", "zh-Hant"].map(AppLanguage.init)
}

public enum Localization {
    public static let defaultsKey = "appLanguage"

    public static var currentID: String {
        get {
            SharedAppState.defaults.string(forKey: defaultsKey)
                ?? UserDefaults.standard.string(forKey: defaultsKey)
                ?? "en"
        }
        set {
            SharedAppState.defaults.set(newValue, forKey: defaultsKey)
            UserDefaults.standard.set(newValue, forKey: defaultsKey)
            if newValue == "system" {
                UserDefaults.standard.removeObject(forKey: "AppleLanguages")
            } else {
                UserDefaults.standard.set([newValue], forKey: "AppleLanguages")
            }
        }
    }

    public static var currentLocale: Locale {
        currentID == "system" ? .current : Locale(identifier: currentID)
    }

    public static func locale(for id: String) -> Locale {
        id == "system" ? .current : Locale(identifier: id)
    }

    public static var currentCode: String {
        if currentID == "system" {
            return Locale.preferredLanguages.first?.components(separatedBy: "-").first ?? "en"
        }
        return currentID
    }

    public static func string(_ key: String) -> String {
        let code = currentCode
        if let bundle = bundle(for: code) {
            let res = bundle.localizedString(forKey: key, value: "\u{1}", table: nil)
            if res != "\u{1}" { return res }
        }
        if code != "en", let enBundle = bundle(for: "en") {
            let res = enBundle.localizedString(forKey: key, value: "\u{1}", table: nil)
            if res != "\u{1}" { return res }
        }
        return key
    }

    private static func bundle(for code: String) -> Bundle? {
        if let path = Bundle.main.path(forResource: code, ofType: "lproj") {
            return Bundle(path: path)
        }
        if let res = Bundle.main.resourceURL {
            return Bundle(url: res.appendingPathComponent("\(code).lproj"))
                ?? Bundle(url: res.appendingPathComponent("MacClean_MacCleanKit.bundle/\(code).lproj"))
        }
        return nil
    }
}

extension String {
    public init(localized key: String) {
        self = Localization.string(key)
    }
}
