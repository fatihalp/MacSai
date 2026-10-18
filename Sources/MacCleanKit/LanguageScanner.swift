import Foundation

public struct LanguageScanner: Sendable {
    public init() {}

    public static var defaultRoots: [URL] {
        [URL(filePath: "/Applications"),
         FileManager.default.homeDirectoryForCurrentUser.appending(path: "Applications")]
    }

    public func discoverLproj(in roots: [URL]) -> Set<String> {
        let fm = FileManager.default
        var found: Set<String> = []
        for root in roots {
            guard let apps = try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: nil) else { continue }
            for app in apps where app.pathExtension == "app" {
                let resources = app.appending(path: "Contents/Resources")
                guard let entries = try? fm.contentsOfDirectory(at: resources, includingPropertiesForKeys: nil) else { continue }
                for e in entries where e.pathExtension == "lproj" {
                    found.insert(e.lastPathComponent)
                }
            }
        }
        return found
    }
}
