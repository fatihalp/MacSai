import Foundation
import MacCleanKit

public enum AppLeftoversScanner {

    private static let appSearchRoots: [URL] = [
        URL(filePath: "/Applications"),
        URL(filePath: "/Applications/Utilities"),
        URL(filePath: "/System/Applications"),
        URL(filePath: "/System/Applications/Utilities"),
        MCConstants.home.appending(path: "Applications"),
    ]

    private static var safeRoots: [URL] {
        [
            MCConstants.userCaches,
            MCConstants.userLogs,
            MCConstants.userHTTPStorages,
            MCConstants.userSavedAppState,
            MCConstants.userWebKit,
        ]
    }

    public static func scan(
        roots: [URL]? = nil,
        installedBundleIDs: Set<String>? = nil
    ) -> [FileItem] {
        let installed = installedBundleIDs ?? Self.installedBundleIDs()

        guard !installed.isEmpty else { return [] }

        let fm = FileManager.default
        var items: [FileItem] = []
        var seenURLs: Set<URL> = []

        for root in roots ?? safeRoots {
            guard let entries = try? fm.contentsOfDirectory(
                at: root, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]
            ) else { continue }

            for entry in entries {

                let candidate = entry.lastPathComponent
                guard OrphanedAppFiles.isOrphan(bundleID: candidate, installedBundleIDs: installed)
                else { continue }
                guard seenURLs.insert(entry.standardizedFileURL).inserted else { continue }

                let size = directorySize(at: entry)
                guard size > 0 else { continue }
                let isDir = (try? entry.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? true
                items.append(FileItem(
                    url: entry,
                    name: candidate,
                    size: size,
                    allocatedSize: size,
                    isDirectory: isDir
                ))
            }
        }

        return items.sorted { $0.size > $1.size }
    }

    static func installedBundleIDs() -> Set<String> {
        installedBundleIDs(in: appSearchRoots)
    }

    static func installedBundleIDs(in roots: [URL]) -> Set<String> {
        var ids: Set<String> = []
        for root in roots {
            for app in AppDiscovery.appBundles(in: root) {
                let infoURL = app.appending(path: "Contents/Info.plist")
                guard let data = try? Data(contentsOf: infoURL),
                      let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
                      let id = plist["CFBundleIdentifier"] as? String
                else { continue }
                ids.insert(id.lowercased())
            }
        }
        return ids
    }

    private static func directorySize(at url: URL) -> UInt64 {
        let fm = FileManager.default
        var values = try? url.resourceValues(forKeys: [.isDirectoryKey, .totalFileAllocatedSizeKey, .fileAllocatedSizeKey])
        if values?.isDirectory != true {
            return UInt64(values?.totalFileAllocatedSize ?? values?.fileAllocatedSize ?? 0)
        }
        var total: UInt64 = 0
        if let enumerator = fm.enumerator(
            at: url,
            includingPropertiesForKeys: [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey, .isRegularFileKey],
            options: []
        ) {
            for case let fileURL as URL in enumerator {
                values = try? fileURL.resourceValues(forKeys: [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey, .isRegularFileKey])
                guard values?.isRegularFile == true else { continue }
                total += UInt64(values?.totalFileAllocatedSize ?? values?.fileAllocatedSize ?? 0)
            }
        }
        return total
    }
}
