import Foundation

public struct UniversalBinariesCategory: JunkCategory {
    public init() {}

    public let scanCategory = ScanCategory.universalBinaries

    public var targets: [ScanTarget] { [] }

    public static func parseLipoOutput(_ output: String) -> [String]? {
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        if let range = trimmed.range(of: "are:") {
            let archPart = trimmed[range.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
            let parts = archPart.split(separator: " ").map(String.init).filter { !$0.isEmpty }
            return parts.isEmpty ? nil : parts
        }
        if let range = trimmed.range(of: "is architecture:") {
            let arch = trimmed[range.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
            return arch.isEmpty ? nil : [arch]
        }
        return nil
    }

    public static func hasRedundantSlice(architectures: [String], hostArch: String) -> Bool {
        guard architectures.count > 1 else { return false }
        let redundant = hostArch == "arm64" ? "x86_64" : "arm64"
        return architectures.contains(redundant)
    }
}
