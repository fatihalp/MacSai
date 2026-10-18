import Foundation
import Darwin

public enum CleanFilter {
    public static func isCleanableByCurrentProcess(_ url: URL) -> Bool {
        let path = url.path(percentEncoded: false)

        let parent = (path as NSString).deletingLastPathComponent
        guard access(parent, W_OK) == 0 else { return false }

        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDir) else {
            return false
        }

        if isDir.boolValue {
            guard access(path, W_OK) == 0 else { return false }
        }

        return true
    }

    public static func isActionable(
        _ url: URL,
        excludedFolders: [String] = FolderExclusionPreferences.paths
    ) -> Bool {
        isCleanableByCurrentProcess(url) && !PathExclusion.isExcluded(url, by: excludedFolders)
    }
}

public extension Array where Element == ScanResult {

    func filteringUncleanable(
        excludedFolders: [String] = FolderExclusionPreferences.paths
    ) -> [ScanResult] {
        map { result in
            ScanResult(
                category: result.category,
                items: result.items.filter {
                    CleanFilter.isActionable($0.url, excludedFolders: excludedFolders)
                },
                autoSelect: result.autoSelect
            )
        }
    }

    func selectedSize(_ selected: Set<URL>) -> UInt64 {
        var counted = Set<URL>()
        var total: UInt64 = 0
        for result in self {
            for item in result.items
            where selected.contains(item.url) && counted.insert(item.url).inserted {
                total += item.size
            }
        }
        return total
    }
}
