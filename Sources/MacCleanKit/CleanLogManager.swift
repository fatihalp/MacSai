import Foundation

public enum CleanLogManager {

    public static let retention: TimeInterval = 30 * 24 * 3600

    public static func readLogFile() -> String {
        let path = MCConstants.operationLogFile.path(percentEncoded: false)
        guard FileManager.default.fileExists(atPath: path),
              let data = try? Data(contentsOf: MCConstants.operationLogFile),
              let text = String(data: data, encoding: .utf8)
        else { return "" }
        return text
    }

    public static func pruneOldEntries(now: Date = Date()) {
        let url = MCConstants.operationLogFile
        let path = url.path(percentEncoded: false)
        guard FileManager.default.fileExists(atPath: path) else { return }

        guard let data = try? Data(contentsOf: url),
              let text = String(data: data, encoding: .utf8) else { return }

        let cutoff = now.addingTimeInterval(-retention)
        let pruned = LogPruner.pruning(text, olderThan: cutoff)
        if pruned == text { return }

        let tempURL = url.deletingLastPathComponent()
            .appending(path: ".operations.log.pruning-\(UUID().uuidString)")
        do {
            try pruned.write(to: tempURL, atomically: false, encoding: .utf8)
            _ = try FileManager.default.replaceItemAt(url, withItemAt: tempURL)
        } catch {

            try? FileManager.default.removeItem(at: tempURL)
        }
    }
}
