import Foundation

public enum LanguagePreferences {

    public static let alwaysKept: Set<String> = MCConstants.preservedLanguages

    private static let discoveredKey = "discoveredLanguages"

    public static var discoveredLproj: Set<String> {
        get { Set(UserDefaults.standard.stringArray(forKey: discoveredKey) ?? []) }
        set { UserDefaults.standard.set(Array(newValue).sorted(), forKey: discoveredKey) }
    }

    public static func displayName(
        forLproj lproj: String,
        locale: Locale = Localization.currentLocale
    ) -> String {
        let code = lproj.hasSuffix(".lproj") ? String(lproj.dropLast(6)) : lproj

        return locale.localizedString(forIdentifier: code)
            ?? locale.localizedString(forLanguageCode: code)
            ?? code
    }

    public static func selectableLanguages(
        locale: Locale = Localization.currentLocale
    ) -> [(name: String, lprojs: [String])] {
        let candidates = discoveredLproj.subtracting(alwaysKept)
        return Dictionary(grouping: candidates) { displayName(forLproj: $0, locale: locale) }
            .map { (name: $0.key, lprojs: $0.value.sorted()) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private static let userKeptKey = "keptLanguages"

    public static var userKept: Set<String> {
        get { Set(UserDefaults.standard.stringArray(forKey: userKeptKey) ?? []) }
        set { UserDefaults.standard.set(Array(newValue).sorted(), forKey: userKeptKey) }
    }

    public static func effectivePreserved(userKept extra: Set<String>? = nil) -> Set<String> {
        alwaysKept.union(extra ?? userKept)
    }
}
