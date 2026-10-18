import Foundation
import AppKit
import MacCleanKit

public enum LaunchServicesError: LocalizedError, Sendable {
    case backupFailed(Error)
    case restoreFailed(Error)
    case deleteFailed(String)

    public var errorDescription: String? {
        switch self {
        case .backupFailed(let error):
            return "Backup failed: \(error.localizedDescription)"
        case .restoreFailed(let error):
            return "Restore failed: \(error.localizedDescription)"
        case .deleteFailed(let message):
            return "Delete failed: \(message)"
        }
    }
}

public final class LaunchServicesService: @unchecked Sendable {
    public static let shared = LaunchServicesService()

    private let plistPath: String
    private let backupDir: URL

    private init() {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        plistPath = "\(home)/Library/Preferences/com.apple.LaunchServices/com.apple.launchservices.secure.plist"
        backupDir = URL(fileURLWithPath: home)
            .appending(path: "Library/Application Support/MacClean/LaunchServicesBackups")
        try? FileManager.default.createDirectory(at: backupDir, withIntermediateDirectories: true)
    }

    internal init(plistPath: String) {
        self.plistPath = plistPath
        backupDir = URL(fileURLWithPath: plistPath).deletingLastPathComponent()
            .appending(path: ".launchservices-backups")
        try? FileManager.default.createDirectory(at: backupDir, withIntermediateDirectories: true)
    }

    public func loadHandlers() -> [HandlerEntry] {
        guard FileManager.default.fileExists(atPath: plistPath),
              let plistData = NSDictionary(contentsOfFile: plistPath),
              let handlers = plistData["LSHandlers"] as? [[String: Any]] else {
            return []
        }
        return handlers.compactMap { dict -> HandlerEntry? in
            var entry = HandlerEntry(id: UUID())
            entry.contentType = dict["LSHandlerContentType"] as? String
            entry.contentTag = dict["LSHandlerContentTag"] as? String
            entry.contentTagClass = dict["LSHandlerContentTagClass"] as? String
            entry.roleAll = dict["LSHandlerRoleAll"] as? String
            entry.urlScheme = dict["LSHandlerURLScheme"] as? String
            if let ts = dict["LSHandlerModificationDate"] as? Double {
                entry.modificationDate = Date(timeIntervalSince1970: ts)
            }
            if entry.roleAll == nil && entry.urlScheme == nil { return nil }
            return entry
        }
    }

    public func deleteHandler(_ entry: HandlerEntry) throws {

        try backup()

        guard let plistData = NSMutableDictionary(contentsOfFile: plistPath) else {
            throw LaunchServicesError.deleteFailed(
                String(localized: "Cannot read plist")
            )
        }

        if let handlers = plistData["LSHandlers"] as? NSMutableArray {
            let indices = (0 ..< handlers.count)
                .filter { i in
                    guard let dict = handlers[i] as? [String: Any] else { return false }
                    return entryMatches(entry, dict)
                }
                .reversed()
            for idx in indices {
                handlers.removeObject(at: idx)
            }
        }

        guard plistData.write(toFile: plistPath, atomically: true) else {
            throw LaunchServicesError.deleteFailed(
                String(localized: "Cannot write plist")
            )
        }
    }

    private static let maxBackups = 20

    public func backup() throws {
        let src = URL(fileURLWithPath: plistPath)
        guard FileManager.default.fileExists(atPath: plistPath) else { return }
        let fm = ISO8601DateFormatter()
        fm.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let ts = fm.string(from: Date())

            .replacingOccurrences(of: ":", with: "_")
        var dst = backupDir.appending(path: "launchservices-\(ts).plist")

        if FileManager.default.fileExists(atPath: dst.path) {
            dst = backupDir.appending(path: "launchservices-\(ts)-\(UUID().uuidString.prefix(8)).plist")
        }
        do {
            try FileManager.default.copyItem(at: src, to: dst)
        } catch {
            throw LaunchServicesError.backupFailed(error)
        }

        trimBackups()
    }

    private func trimBackups() {
        let all = listBackups()
        guard all.count > Self.maxBackups else { return }
        for stale in all[Self.maxBackups...] {
            try? FileManager.default.removeItem(at: stale)
        }
    }

    public func listBackups() -> [URL] {
        guard let contents = try? FileManager.default
            .contentsOfDirectory(at: backupDir,
                                includingPropertiesForKeys: nil)
        else { return [] }
        return contents
            .filter { $0.pathExtension == "plist" }
            .sorted { $0.lastPathComponent > $1.lastPathComponent }
    }

    public func restoreBackup(from url: URL) throws {
        let dst = URL(fileURLWithPath: plistPath)
        let tmpDir = dst.deletingLastPathComponent()
        let tmpURL = tmpDir.appending(path: ".launchservices-restore-tmp.plist")

        try? FileManager.default.removeItem(at: tmpURL)
        do {
            try FileManager.default.copyItem(at: url, to: tmpURL)
            _ = try FileManager.default.replaceItemAt(dst, withItemAt: tmpURL)
        } catch {
            try? FileManager.default.removeItem(at: tmpURL)
            throw LaunchServicesError.restoreFailed(error)
        }
    }

    private func entryMatches(_ entry: HandlerEntry, _ dict: [String: Any]) -> Bool {

        if let scheme = entry.urlScheme {
            return dict["LSHandlerURLScheme"] as? String == scheme
        }

        if let ct = entry.contentType {
            return dict["LSHandlerContentType"] as? String == ct
                && dict["LSHandlerRoleAll"] as? String == entry.roleAll
        }

        if let tag = entry.contentTag {
            return dict["LSHandlerContentTag"] as? String == tag
                && dict["LSHandlerContentTagClass"] as? String == entry.contentTagClass
                && dict["LSHandlerRoleAll"] as? String == entry.roleAll
        }
        return false
    }

    public func getAppInfo(for bundleId: String?) -> (name: String, icon: NSImage)? {
        guard let bid = bundleId, !bid.isEmpty,
              let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bid) else {
            return nil
        }
        let name = FileManager.default.displayName(atPath: url.path)
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        icon.size = NSSize(width: 32, height: 32)
        return (name, icon)
    }

    public func getURLSchemeAppInfo(for scheme: String?) -> (name: String, icon: NSImage)? {
        guard let s = scheme, !s.isEmpty,
              let url = URL(string: "\(s)://test"),
              let appURL = NSWorkspace.shared.urlForApplication(toOpen: url) else {
            return nil
        }
        let name = FileManager.default.displayName(atPath: appURL.path)
        let icon = NSWorkspace.shared.icon(forFile: appURL.path)
        icon.size = NSSize(width: 32, height: 32)
        return (name, icon)
    }
}
