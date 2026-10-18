import Foundation

public enum PlistJunkFilter {

    public static func isLikelyBroken(
        at url: URL,
        loadData: (URL) -> Data?,
        appExistsForBundleID: (String) -> Bool
    ) -> Bool {
        guard url.pathExtension == "plist" else { return false }

        let name = url.deletingPathExtension().lastPathComponent
        if isAppleSystemDomain(name) { return false }

        _ = appExistsForBundleID

        guard let data = loadData(url) else {

            return false
        }

        do {
            _ = try PropertyListSerialization.propertyList(from: data, format: nil)
            return false
        } catch {
            return true
        }
    }

    public static func isAppleSystemDomain(_ identifier: String) -> Bool {
        let lower = identifier.lowercased()
        return lower.hasPrefix("com.apple.")
            || lower.hasPrefix("group.com.apple.")
    }
}
