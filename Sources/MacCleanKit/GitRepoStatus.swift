import Foundation

public struct GitRepoStatus: Equatable, Sendable {
    public let branch: String

    public let dirty: Int

    public let ahead: Int

    public let hasUpstream: Bool

    public init(branch: String, dirty: Int, ahead: Int, hasUpstream: Bool) {
        self.branch = branch
        self.dirty = dirty
        self.ahead = ahead
        self.hasUpstream = hasUpstream
    }

    public var hasUnsavedWork: Bool {
        dirty > 0 || ahead > 0 || !hasUpstream
    }

    public static func parse(_ porcelain: String) -> GitRepoStatus {
        var branch = "HEAD"
        var dirty = 0
        var ahead = 0
        var hasUpstream = false

        for rawLine in porcelain.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline) {
            let line = String(rawLine)
            if line.hasPrefix("## ") {
                let header = String(line.dropFirst(3))
                if header.hasPrefix("HEAD") || header.hasPrefix("No commits yet on ") {
                    branch = header.replacingOccurrences(of: "No commits yet on ", with: "")
                    hasUpstream = false
                    continue
                }
                let bracketParts = header.split(separator: "[", maxSplits: 1)
                let branchPart = String(bracketParts[0]).trimmingCharacters(in: .whitespaces)
                if let dotsRange = branchPart.range(of: "...") {
                    branch = String(branchPart[..<dotsRange.lowerBound])
                    hasUpstream = true
                } else {
                    branch = branchPart
                    hasUpstream = false
                }
                if bracketParts.count > 1 {
                    let meta = bracketParts[1].replacingOccurrences(of: "]", with: "")
                    for token in meta.split(separator: ",") {
                        let trimmed = token.trimmingCharacters(in: .whitespaces)
                        if trimmed.hasPrefix("ahead ") {
                            let numStr = trimmed.dropFirst("ahead ".count)
                            ahead = Int(numStr) ?? 0
                        }
                    }
                }
            } else if !line.trimmingCharacters(in: .whitespaces).isEmpty {
                dirty += 1
            }
        }

        return GitRepoStatus(
            branch: branch,
            dirty: dirty,
            ahead: ahead,
            hasUpstream: hasUpstream
        )
    }
}
