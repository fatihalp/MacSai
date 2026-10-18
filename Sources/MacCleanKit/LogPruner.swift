import Foundation

public enum LogPruner {

    public static func pruning(_ logText: String, olderThan cutoff: Date) -> String {
        guard !logText.isEmpty else { return "" }

        let parser = ISO8601DateFormatter()

        let endsWithNewline = logText.hasSuffix("\n")
        let lines = logText.split(separator: "\n", omittingEmptySubsequences: false)

        var kept: [Substring] = []
        kept.reserveCapacity(lines.count)
        for line in lines {
            if isOlderThan(line: String(line), cutoff: cutoff, parser: parser) {
                continue
            }
            kept.append(line)
        }

        if kept.count == lines.count {
            return logText
        }

        var result = kept.joined(separator: "\n")
        if endsWithNewline, !result.isEmpty, !result.hasSuffix("\n") {
            result += "\n"
        }
        return result
    }

    private static func isOlderThan(
        line: String, cutoff: Date, parser: ISO8601DateFormatter
    ) -> Bool {

        guard let spaceIndex = line.firstIndex(of: " ") else { return false }
        let timestampPart = String(line[line.startIndex..<spaceIndex])
        guard let date = parser.date(from: timestampPart) else { return false }
        return date < cutoff
    }
}
