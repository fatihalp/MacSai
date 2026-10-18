import Foundation
import AppKit
import MacCleanKit

public struct SystemJunkModule: ScanModule {
    public let id = "system_junk"
    public var name: String { String(localized: "System Junk") }
    public let category = ModuleCategory.cleanup

    private let scanner = TargetedScanner()

    public init() {}

    public static let allCategories: [JunkCategory] = [
        UserCacheCategory(),
        SystemCacheCategory(),
        UserLogCategory(),
        SystemLogCategory(),
        LanguageFilesCategory(),
        BrokenPreferencesCategory(),
        BrokenLoginItemsCategory(),
        DocumentVersionsCategory(),
        BrokenDownloadsCategory(),
        IOSDeviceBackupsCategory(),
        OldUpdatesCategory(),
        UniversalBinariesCategory(),
        XcodeJunkCategory(),
        DeletedUsersCategory(),
        UnusedDiskImagesCategory(),
        IncompleteDownloadsCategory(),
        AppLeftoversCategory(),
        PackageManagerCachesCategory(),
        IDECachesCategory(),
        AIToolCachesCategory(),
    ]

    public func scan() async -> [ScanResult] {
        let categories = Self.allCategories

        return await withTaskGroup(of: ScanResult?.self) { group in
            for cat in categories {
                group.addTask {

                    if cat.scanCategory == .universalBinaries {
                        let items = UniversalBinariesScanner.scanAllApplicationsDirectories()
                        guard !items.isEmpty else { return nil }
                        return ScanResult(
                            category: .universalBinaries,
                            items: items,
                            autoSelect: cat.scanCategory.autoSelect
                        )
                    }

                    if cat.scanCategory == .appLeftovers {
                        let items = AppLeftoversScanner.scan()
                        guard !items.isEmpty else { return nil }
                        return ScanResult(
                            category: .appLeftovers,
                            items: items,
                            autoSelect: cat.scanCategory.autoSelect
                        )
                    }

                    if cat.scanCategory == .deletedUsers {
                        let items = DeletedUsersScanner.scanForDeletedUserFolders()
                        guard !items.isEmpty else { return nil }
                        return ScanResult(
                            category: .deletedUsers,
                            items: items,
                            autoSelect: cat.scanCategory.autoSelect
                        )
                    }
                    let items = await scanner.scan(targets: cat.targets)
                    var filtered = items

                    if let brokenPrefs = cat as? BrokenPreferencesCategory {
                        filtered = brokenPrefs.filterBroken(
                            items,
                            loadData: { try? Data(contentsOf: $0) },
                            appExistsForBundleID: {
                                NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0) != nil
                            }
                        )
                    } else if let brokenLogin = cat as? BrokenLoginItemsCategory {
                        filtered = brokenLogin.filterBroken(
                            items,
                            loadData: { try? Data(contentsOf: $0) },
                            fileExists: { FileManager.default.fileExists(atPath: $0) },
                            appExistsForBundleID: {
                                NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0) != nil
                            }
                        )
                    }

                    guard !filtered.isEmpty else { return nil }
                    return ScanResult(
                        category: cat.scanCategory,
                        items: filtered,
                        autoSelect: cat.scanCategory.autoSelect
                    )
                }
            }

            var results: [ScanResult] = []
            for await result in group {
                if let result {
                    results.append(result)
                }
            }
            return results
                .filteringUncleanable()
                .sorted { $0.totalSize > $1.totalSize }
        }
    }
}
