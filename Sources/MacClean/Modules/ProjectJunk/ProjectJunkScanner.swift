import Foundation
import MacCleanKit

public struct ProjectJunkScanner: Sendable {
    public init() {}

    static let junkNames: Set<String> = [
        "node_modules", "target", "build", ".build", "dist", ".next", ".nuxt",
        ".turbo", ".parcel-cache", "Pods", ".venv", "venv", "__pycache__",
        ".pytest_cache", ".gradle", ".dart_tool", "vendor",
    ]

    private static let hiddenJunkNames: Set<String> = [
        ".next", ".nuxt", ".turbo", ".parcel-cache", ".venv", ".build",
        ".pytest_cache", ".gradle", ".dart_tool",
    ]

    public static func defaultProjectRoots(
        home: URL = FileManager.default.homeDirectoryForCurrentUser
    ) -> [URL] {
        let candidates = [
            "Projects",
            "Code",
            "Developer",
            "Development",
            "workspace",
            "github",
            "repos",
            "src",
            "Documents/projects",
            "Documents/Projects",
            "Desktop/Projects",
        ]
        var seen: Set<String> = []
        var result: [URL] = []
        let fm = FileManager.default
        for rel in candidates {
            let url = home.appending(path: rel, directoryHint: .isDirectory)
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: url.path(percentEncoded: false), isDirectory: &isDir),
                  isDir.boolValue,
                  isAllowedRoot(url) else { continue }
            let norm = normalized(url.resolvingSymlinksInPath()).lowercased()
            if seen.insert(norm).inserted {
                result.append(url)
            }
        }
        return result
    }

    static let walkShare = 0.4

    public func scan(
        root: URL,
        maxDepth: Int = 6,
        onProgress: (@Sendable (Double) -> Void)? = nil
    ) -> [ProjectJunkItem] {
        scan(roots: [root], maxDepth: maxDepth, onProgress: onProgress)
    }

    public func scan(
        roots: [URL],
        maxDepth: Int = 6,
        onProgress: (@Sendable (Double) -> Void)? = nil
    ) -> [ProjectJunkItem] {
        let allowedRoots = roots.filter { Self.isAllowedRoot($0) }
        guard !allowedRoots.isEmpty else { return [] }

        var allNodes: [ProjectTreeNode] = []
        for root in allowedRoots {
            if Task.isCancelled { return [] }
            allNodes.append(contentsOf: collectNodes(root: root, maxDepth: maxDepth))
        }
        let matches = ProjectJunkFinder.find(nodes: allNodes)
        onProgress?(Self.walkShare)

        var items: [ProjectJunkItem] = []
        for (index, item) in matches.enumerated() {
            if Task.isCancelled { return [] }
            items.append(ProjectJunkItem(
                path: item.path,
                projectPath: item.projectPath,
                kind: item.kind,
                bytes: Self.directoryBytes(URL(filePath: item.path, directoryHint: .isDirectory)),
                projectModified: item.projectModified
            ))
            onProgress?(Self.walkShare + (1 - Self.walkShare) * Double(index + 1) / Double(matches.count))
        }
        return items
    }

    public func gitStatuses(for items: [ProjectJunkItem]) async -> [String: GitRepoStatus] {
        let uniqueProjects = Array(Set(items.map(\.projectPath)))
        var statuses: [String: GitRepoStatus] = [:]
        for projectPath in uniqueProjects {
            if Task.isCancelled { break }
            let outcome = await BoundedProcess.run(
                "/usr/bin/git",
                ["-C", projectPath, "status", "--porcelain=v1", "-b"],
                timeout: .seconds(2)
            )
            if outcome.succeeded {
                statuses[projectPath] = GitRepoStatus.parse(outcome.stdoutText)
            }
        }
        return statuses
    }

    static func isAllowedRoot(_ root: URL) -> Bool {
        let path = normalized(root.resolvingSymlinksInPath())
        if path == "/" { return false }
        let home = normalized(FileManager.default.homeDirectoryForCurrentUser)
        let forbidden = ["/System", "/Library", "/Applications", "/usr", "/bin", "/sbin",
                         "/opt", home + "/Library"]
        return !forbidden.contains { path == $0 || path.hasPrefix($0 + "/") }
    }

    static func normalized(_ url: URL) -> String {
        var path = url.standardizedFileURL.path(percentEncoded: false)
        while path.count > 1 && path.hasSuffix("/") { path.removeLast() }
        return path
    }

    public func asScanResults(_ items: [ProjectJunkItem]) -> [ScanResult] {
        guard !items.isEmpty else { return [] }
        let files = items.map { item in
            FileItem(
                url: URL(filePath: item.path, directoryHint: .isDirectory),
                name: (item.path as NSString).lastPathComponent,
                size: item.bytes,
                allocatedSize: item.bytes,
                isDirectory: true,
                modificationDate: item.projectModified
            )
        }
        return [
            ScanResult(
                category: .projectJunk,
                items: files,
                autoSelect: false
            )
        ]
    }

    private func collectNodes(root: URL, maxDepth: Int) -> [ProjectTreeNode] {
        let fm = FileManager.default
        let home = Self.normalized(fm.homeDirectoryForCurrentUser)
        guard let enumerator = fm.enumerator(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey, .contentModificationDateKey],
            options: [.skipsPackageDescendants]
        ) else { return [] }

        var nodes: [ProjectTreeNode] = []

        nodes.append(node(path: Self.normalized(root), url: root, fm: fm))

        while let url = enumerator.nextObject() as? URL {
            if Task.isCancelled { return [] }
            let name = url.lastPathComponent
            let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])

            guard values?.isDirectory == true, values?.isSymbolicLink != true else { continue }
            let path = Self.normalized(url)
            if path == home + "/Library" || (name.hasPrefix(".") && !Self.hiddenJunkNames.contains(name)) {
                enumerator.skipDescendants()
                continue
            }
            if enumerator.level > maxDepth {
                enumerator.skipDescendants()
                continue
            }
            nodes.append(node(path: path, url: url, fm: fm))
            if Self.junkNames.contains(name) {
                enumerator.skipDescendants()
            }
        }
        return nodes
    }

    private func node(path: String, url: URL, fm: FileManager) -> ProjectTreeNode {
        let children = (try? fm.contentsOfDirectory(atPath: path)) ?? []
        let modified = try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
        return ProjectTreeNode(
            path: path,
            bytes: 0,
            modified: modified,
            childNames: children,
            gitignoreLines: children.contains(".gitignore") ? Self.gitignoreLines(in: path) : []
        )
    }

    private static func gitignoreLines(in directory: String) -> [String] {
        let path = (directory as NSString).appendingPathComponent(".gitignore")
        guard let handle = FileHandle(forReadingAtPath: path) else { return [] }
        defer { try? handle.close() }
        guard let data = try? handle.read(upToCount: 256 * 1024),
              let text = String(data: data, encoding: .utf8) else { return [] }
        return text.components(separatedBy: .newlines)
    }

    static func directoryBytes(_ url: URL) -> UInt64 {
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [.totalFileAllocatedSizeKey, .isRegularFileKey],
            options: []
        ) else { return 0 }
        var total: UInt64 = 0
        for case let fileURL as URL in enumerator {
            if Task.isCancelled { break }
            let values = try? fileURL.resourceValues(forKeys: [
                .totalFileAllocatedSizeKey, .isRegularFileKey,
            ])
            if values?.isRegularFile == true {
                total += UInt64(values?.totalFileAllocatedSize ?? 0)
            }
        }
        return total
    }
}
