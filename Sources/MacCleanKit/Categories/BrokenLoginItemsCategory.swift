import Foundation

public struct BrokenLoginItemsCategory: JunkCategory {
    public init() {}

    public let scanCategory = ScanCategory.brokenLoginItems

    public var targets: [ScanTarget] {
        [
            ScanTarget(
                path: MCConstants.userLaunchAgents,
                recursive: false,
                fileExtensions: ["plist"]
            ),
        ]
    }

    public func filterBroken(
        _ items: [FileItem],
        loadData: (URL) -> Data?,
        fileExists: (String) -> Bool,
        appExistsForBundleID: (String) -> Bool
    ) -> [FileItem] {
        items.filter { item in
            guard item.fileExtension == "plist" else { return false }
            guard let data = loadData(item.url) else { return true }

            let plist: [String: Any]
            do {
                guard let dict = try PropertyListSerialization
                    .propertyList(from: data, format: nil) as? [String: Any] else {
                    return true
                }
                plist = dict
            } catch {
                return true
            }

            let programPath: String?
            if let prog = plist["Program"] as? String {

                guard prog.hasPrefix("/") else { return true }
                programPath = prog
            } else if let args = plist["ProgramArguments"] as? [String], let first = args.first {
                guard let resolved = Self.resolveLaunchdCommand(first, fileExists: fileExists) else {
                    return true
                }
                programPath = resolved
            } else {
                programPath = nil
            }

            if let path = programPath {
                if !fileExists(path) { return true }
                if path.contains(".app/") {
                    let appPath = path.components(separatedBy: ".app/").first.map { $0 + ".app" }
                    if let appPath, !fileExists(appPath) { return true }
                }
            }

            if let label = plist["Label"] as? String, label.contains(".") {
                if !appExistsForBundleID(label) {
                    if let path = programPath, !fileExists(path) {
                        return true
                    }
                }
            }

            return false
        }
    }

    static let launchdSearchPath = ["/usr/bin", "/bin", "/usr/sbin", "/sbin"]

    static func resolveLaunchdCommand(_ command: String, fileExists: (String) -> Bool) -> String? {
        guard !command.hasPrefix("/"), !command.contains("/") else { return command }
        return launchdSearchPath
            .map { "\($0)/\(command)" }
            .first(where: fileExists)
    }
}
