import Foundation

public struct ProjectTreeNode: Equatable, Sendable {
    public let path: String
    public let bytes: UInt64
    public let modified: Date?
    public let childNames: [String]

    public let gitignoreLines: [String]

    public init(
        path: String,
        bytes: UInt64,
        modified: Date?,
        childNames: [String],
        gitignoreLines: [String] = []
    ) {
        self.path = path
        self.bytes = bytes
        self.modified = modified
        self.childNames = childNames
        self.gitignoreLines = gitignoreLines
    }

    public var name: String { (path as NSString).lastPathComponent }
}

public enum ProjectJunkKind: String, Equatable, Sendable, CaseIterable {
    case nodeModules
    case nextBuild
    case nuxtBuild
    case turboCache
    case parcelCache
    case dist
    case rustTarget
    case swiftBuild
    case pythonVenv
    case pythonCache
    case pytestCache
    case gradleBuild
    case gradleCache
    case mavenBuild
    case cocoaPods
    case dartTool
    case vendorDeps

    public var label: String {
        switch self {
        case .nodeModules: "node_modules"
        case .nextBuild: "Next.js (.next)"
        case .nuxtBuild: "Nuxt (.nuxt)"
        case .turboCache: "Turborepo (.turbo)"
        case .parcelCache: "Parcel (.parcel-cache)"
        case .dist: "dist"
        case .rustTarget: "Rust (target)"
        case .swiftBuild: "SwiftPM (.build)"
        case .pythonVenv: "Python (venv)"
        case .pythonCache: "Python (__pycache__)"
        case .pytestCache: "Pytest (.pytest_cache)"
        case .gradleBuild: "Gradle (build)"
        case .gradleCache: "Gradle (.gradle)"
        case .mavenBuild: "Maven (target)"
        case .cocoaPods: "CocoaPods (Pods)"
        case .dartTool: "Flutter/Dart (.dart_tool)"
        case .vendorDeps: "Vendor (vendor)"
        }
    }
}

public struct ProjectJunkItem: Equatable, Sendable, Identifiable {
    public var id: String { path }

    public let path: String
    public let projectPath: String
    public let kind: ProjectJunkKind
    public let bytes: UInt64
    public let projectModified: Date?

    public init(
        path: String,
        projectPath: String,
        kind: ProjectJunkKind,
        bytes: UInt64,
        projectModified: Date?
    ) {
        self.path = path
        self.projectPath = projectPath
        self.kind = kind
        self.bytes = bytes
        self.projectModified = projectModified
    }
}

public enum ProjectJunkFinder {

    public static let defaultSelection: Set<String> = []

    private static let nodeMarkers: Set<String> = ["package.json"]
    private static let rustMarkers: Set<String> = ["Cargo.toml"]
    private static let swiftMarkers: Set<String> = ["Package.swift"]
    private static let pythonMarkers: Set<String> = [
        "pyproject.toml", "requirements.txt", "setup.py", "Pipfile",
    ]
    private static let gradleMarkers: Set<String> = [
        "build.gradle", "build.gradle.kts", "settings.gradle", "settings.gradle.kts",
    ]
    private static let mavenMarkers: Set<String> = ["pom.xml"]
    private static let podsMarkers: Set<String> = ["Podfile"]
    private static let dartMarkers: Set<String> = ["pubspec.yaml"]
    private static let vendorMarkers: Set<String> = ["composer.json", "go.mod"]

    public static func find(nodes: [ProjectTreeNode]) -> [ProjectJunkItem] {
        let byPath = Dictionary(nodes.map { ($0.path, $0) }, uniquingKeysWith: { first, _ in first })
        var candidates: [ProjectJunkItem] = []

        for node in nodes {
            guard let kind = kind(for: node, byPath: byPath) else { continue }
            let projectPath = (node.path as NSString).deletingLastPathComponent
            let project = byPath[projectPath]
            candidates.append(
                ProjectJunkItem(
                    path: node.path,
                    projectPath: projectPath,
                    kind: kind,
                    bytes: node.bytes,
                    projectModified: project?.modified
                )
            )
        }

        let outermost = candidates.filter { item in
            !candidates.contains { other in
                other.path != item.path && item.path.hasPrefix(other.path + "/")
            }
        }

        return outermost.sorted { lhs, rhs in
            let left = lhs.projectModified ?? .distantFuture
            let right = rhs.projectModified ?? .distantFuture
            if left != right { return left < right }
            if lhs.bytes != rhs.bytes { return lhs.bytes > rhs.bytes }
            return lhs.path < rhs.path
        }
    }

    private static func kind(
        for node: ProjectTreeNode,
        byPath: [String: ProjectTreeNode]
    ) -> ProjectJunkKind? {
        let parentPath = (node.path as NSString).deletingLastPathComponent
        guard let parent = byPath[parentPath] else { return nil }
        let siblings = Set(parent.childNames)

        switch node.name {
        case "node_modules" where !siblings.isDisjoint(with: nodeMarkers):
            return .nodeModules
        case ".next" where !siblings.isDisjoint(with: nodeMarkers):
            return .nextBuild
        case ".nuxt" where !siblings.isDisjoint(with: nodeMarkers):
            return .nuxtBuild
        case ".turbo" where !siblings.isDisjoint(with: nodeMarkers):
            return .turboCache
        case ".parcel-cache" where !siblings.isDisjoint(with: nodeMarkers):
            return .parcelCache
        case "dist" where !siblings.isDisjoint(with: nodeMarkers):

            return isGitIgnored(node, byPath: byPath) ? .dist : nil
        case "target":
            if !siblings.isDisjoint(with: rustMarkers) { return .rustTarget }
            if !siblings.isDisjoint(with: mavenMarkers) { return .mavenBuild }
            return nil
        case ".build" where !siblings.isDisjoint(with: swiftMarkers):
            return .swiftBuild
        case "build" where !siblings.isDisjoint(with: gradleMarkers):
            return .gradleBuild
        case ".gradle" where !siblings.isDisjoint(with: gradleMarkers):
            return .gradleCache
        case ".venv", "venv":

            guard node.childNames.contains("pyvenv.cfg") else { return nil }
            return siblings.isDisjoint(with: pythonMarkers) ? nil : .pythonVenv
        case "__pycache__" where !siblings.isDisjoint(with: pythonMarkers):
            return .pythonCache
        case ".pytest_cache" where !siblings.isDisjoint(with: pythonMarkers):
            return .pytestCache
        case "Pods" where !siblings.isDisjoint(with: podsMarkers):

            return isGitIgnored(node, byPath: byPath) ? .cocoaPods : nil
        case ".dart_tool" where !siblings.isDisjoint(with: dartMarkers):
            return .dartTool
        case "vendor" where !siblings.isDisjoint(with: vendorMarkers):
            return isGitIgnored(node, byPath: byPath) ? .vendorDeps : nil
        default:
            return nil
        }
    }

    static func isGitIgnored(_ node: ProjectTreeNode, byPath: [String: ProjectTreeNode]) -> Bool {
        var dirPath = (node.path as NSString).deletingLastPathComponent
        var isProjectFolder = true
        while let dir = byPath[dirPath] {
            for line in dir.gitignoreLines
            where gitignoreLine(line, names: node.name, anchoredHere: isProjectFolder) {
                return true
            }

            if dir.childNames.contains(".git") { break }
            let parent = (dirPath as NSString).deletingLastPathComponent
            if parent == dirPath { break }
            dirPath = parent
            isProjectFolder = false
        }
        return false
    }

    static func gitignoreLine(_ rawLine: String, names name: String, anchoredHere: Bool) -> Bool {
        var line = rawLine.trimmingCharacters(in: .whitespaces)
        guard !line.isEmpty, !line.hasPrefix("#"), !line.hasPrefix("!") else { return false }
        for suffix in ["/**", "/*", "/"] where line.hasSuffix(suffix) {
            line.removeLast(suffix.count)
            break
        }
        if line.hasPrefix("**/") {
            line.removeFirst(3)
        } else if line.hasPrefix("/") {
            guard anchoredHere else { return false }
            line.removeFirst()
        }
        return line == name
    }
}
