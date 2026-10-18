import Foundation
import MacCleanKit

public enum UniversalBinariesScanner {

    public static func scan(
        in searchRoot: URL = URL(filePath: "/Applications"),
        host: BundleHostInfo = .current,
        policy: UniversalBinariesPolicy = UniversalBinariesPolicy()
    ) -> [FileItem] {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(
            at: searchRoot, includingPropertiesForKeys: nil
        ) else { return [] }

        let apps = entries.filter { $0.pathExtension == "app" }
        guard !apps.isEmpty else { return [] }

        let box = ResultBox(count: apps.count)
        DispatchQueue.concurrentPerform(iterations: apps.count) { i in
            let item = thinnableItem(appURL: apps[i], host: host, policy: policy)
            box.set(item, at: i)
        }
        return box.items.compactMap { $0 }
    }

    public static func scanAllApplicationsDirectories(
        systemApplications: URL = URL(filePath: "/Applications"),
        home: URL = MCConstants.home,
        host: BundleHostInfo = .current,
        policy: UniversalBinariesPolicy = UniversalBinariesPolicy()
    ) -> [FileItem] {
        let roots = [
            systemApplications,
            home.appending(path: "Applications"),
        ]
        var seen = Set<String>()
        var results: [FileItem] = []
        for root in roots {
            for item in scan(in: root, host: host, policy: policy) {
                let path = item.url.path(percentEncoded: false)
                guard seen.insert(path).inserted else { continue }
                results.append(item)
            }
        }
        return results
    }

    static func thinnableItem(
        appURL: URL,
        host: BundleHostInfo,
        policy: UniversalBinariesPolicy
    ) -> FileItem? {
        let infoURL = appURL.appending(path: "Contents/Info.plist")
        guard let data = try? Data(contentsOf: infoURL),
              let plist = try? PropertyListSerialization.propertyList(
                  from: data, format: nil
              ) as? [String: Any],
              let bundleID = plist["CFBundleIdentifier"] as? String,
              let executable = plist["CFBundleExecutable"] as? String
        else { return nil }

        let executableURL = appURL.appending(path: "Contents/MacOS/\(executable)")
        guard FileManager.default.fileExists(
            atPath: executableURL.path(percentEncoded: false)
        ) else { return nil }

        let isAppStore = FileManager.default.fileExists(
            atPath: appURL.appending(path: "Contents/_MASReceipt/receipt").path(percentEncoded: false)
        )

        let lipoArchs = runLipoInfo(at: executableURL)
        let archSet: Set<BinaryArch> = Set(lipoArchs.compactMap(BinaryArch.init(lipoName:)))
        guard !archSet.isEmpty else { return nil }

        let info = AppBundleInfo(
            bundlePath: appURL.path(percentEncoded: false),
            bundleID: bundleID,
            isAppStore: isAppStore,
            architectures: archSet
        )

        let decision = policy.decideThinning(for: info, host: host)

        let fatBinaries: [URL]
        let dropping: Set<BinaryArch>

        let originalArchCount: Int

        switch decision {
        case .thin(_, let d):
            fatBinaries = MachOWalker.fatBinaries(in: appURL)
            dropping = d
            originalArchCount = archSet.count

        case .skip(.alreadyThin):

            let embeddedFat = MachOWalker.fatBinaries(in: appURL)
                .filter { $0.standardizedFileURL != executableURL.standardizedFileURL }
            var embeddedArchs: Set<BinaryArch> = []
            for binary in embeddedFat {
                embeddedArchs.formUnion(runLipoInfo(at: binary).compactMap(BinaryArch.init(lipoName:)))
            }
            let extraArchs = embeddedArchs.subtracting([host.hostArch])
            guard !extraArchs.isEmpty else { return nil }
            fatBinaries = embeddedFat
            dropping = extraArchs

            originalArchCount = embeddedArchs.count

        default:
            return nil
        }

        let totalFatBytes = fatBinaries.reduce(UInt64(0)) { sum, url in
            let attrs = try? FileManager.default
                .attributesOfItem(atPath: url.path(percentEncoded: false))
            return sum + ((attrs?[.size] as? NSNumber)?.uint64Value ?? 0)
        }
        let savings = UniversalBinariesPolicy.estimatedSavings(
            originalSize: totalFatBytes,
            originalArchCount: originalArchCount,
            droppingCount: dropping.count
        )

        return FileItem(
            url: appURL,
            name: "\(appURL.deletingPathExtension().lastPathComponent) (drop \(dropping.map { $0.lipoName }.sorted().joined(separator: ", ")))",
            size: savings,
            allocatedSize: savings,
            isDirectory: true
        )
    }

    private static func runLipoInfo(at url: URL) -> [String] {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(filePath: "/usr/bin/lipo")
        process.arguments = ["-info", url.path(percentEncoded: false)]
        process.standardOutput = pipe
        process.standardError = Pipe()
        guard (try? process.run()) != nil else { return [] }
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return [] }
        let output = String(
            data: pipe.fileHandleForReading.readDataToEndOfFile(),
            encoding: .utf8
        ) ?? ""
        if let r = output.range(of: "are: ") {
            return output[r.upperBound...]
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .split(separator: " ").map(String.init)
        }
        if let r = output.range(of: "is architecture: ") {
            return [output[r.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)]
        }
        return []
    }
}

private final class ResultBox: @unchecked Sendable {
    private let lock = NSLock()
    var items: [FileItem?]

    init(count: Int) {
        items = [FileItem?](repeating: nil, count: count)
    }

    func set(_ item: FileItem?, at index: Int) {
        lock.lock()
        items[index] = item
        lock.unlock()
    }
}
