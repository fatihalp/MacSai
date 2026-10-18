import Foundation

public enum AppCacheOwnership {

    public static func runningOwnedURLs(
        in results: [ScanResult],
        runningBundleIDs: Set<String>
    ) -> Set<URL> {
        guard !runningBundleIDs.isEmpty else { return [] }
        var urls: Set<URL> = []
        for result in results {
            for item in result.items {
                if let id = owningBundleID(for: item.url), runningBundleIDs.contains(id) {
                    urls.insert(item.url)
                }
            }
        }
        return urls
    }

    public static func owningBundleID(for url: URL) -> String? {
        let components = url.pathComponents

        let anchors = ["Caches", "Containers", "HTTPStorages", "WebKit", "Application Scripts"]
        for anchor in anchors {
            guard let i = components.firstIndex(of: anchor), i + 1 < components.count else { continue }
            let candidate = components[i + 1]
            if looksLikeBundleID(candidate) { return candidate }
        }

        let path = url.path
        for entry in browserMap where path.contains(entry.needle) {
            return entry.bundleID
        }
        return nil
    }

    private static func looksLikeBundleID(_ string: String) -> Bool {
        guard string.split(separator: ".").count >= 2 else { return false }
        return string.allSatisfy { $0.isLetter || $0.isNumber || $0 == "." || $0 == "-" || $0 == "_" }
    }

    private static let browserMap: [(needle: String, bundleID: String)] = [
        ("/Google/Chrome/", "com.google.Chrome"),
        ("/Firefox/", "org.mozilla.firefox"),
        ("/Arc/", "company.thebrowser.Browser"),
        ("/BraveSoftware/Brave-Browser/", "com.brave.Browser"),
        ("/Microsoft Edge/", "com.microsoft.edgemac"),
        ("/Vivaldi/", "com.vivaldi.Vivaldi"),
    ]
}
