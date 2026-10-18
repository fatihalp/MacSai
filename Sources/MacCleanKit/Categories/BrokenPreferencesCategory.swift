import Foundation

public struct BrokenPreferencesCategory: JunkCategory {
    public init() {}

    public let scanCategory = ScanCategory.brokenPreferences

    public var targets: [ScanTarget] {
        [
            ScanTarget(
                path: MCConstants.userPreferences,
                recursive: false,
                fileExtensions: ["plist"]
            ),
        ]
    }

    public func filterBroken(
        _ items: [FileItem],
        loadData: (URL) -> Data?,
        appExistsForBundleID: (String) -> Bool
    ) -> [FileItem] {
        items.filter { item in
            PlistJunkFilter.isLikelyBroken(
                at: item.url,
                loadData: loadData,
                appExistsForBundleID: appExistsForBundleID
            )
        }
    }
}
