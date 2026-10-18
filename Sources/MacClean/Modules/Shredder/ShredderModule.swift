import Foundation
import MacCleanKit

public struct ShredderModule: ScanModule {
    public let id = "shredder"
    public var name: String { String(localized: "Shredder") }
    public let category = ModuleCategory.files
    public let includedInSmartScan = false

    public init() {}

    public func scan() async -> [ScanResult] {
        []
    }
}

public actor SecureEraser {
    public enum EraseMode: Sendable {
        case standard
        case permanent
        case secure
    }

    private enum EraseError: LocalizedError {
        case secureEraseDirectory(String)

        var errorDescription: String? {
            switch self {
            case .secureEraseDirectory(let path):
                "Secure erase cannot be used on directories: \(path)"
            }
        }
    }

    public struct EraseResult: Sendable {
        public let erasedCount: Int
        public let totalSize: UInt64
        public let errors: [(String, String)]
    }

    private let safetyGuard = SafetyGuard()

    public init() {}

    public func erase(urls: [URL], mode: EraseMode) async -> EraseResult {

        do {
            try safetyGuard.validateDeletion(paths: urls)
        } catch let error as SafetyGuard.SafetyError {
            if case .tooManyFiles = error {
                return EraseResult(
                    erasedCount: 0,
                    totalSize: 0,
                    errors: [("validation", error.localizedDescription)]
                )
            }
        } catch {

        }

        var erasedCount = 0
        var totalSize: UInt64 = 0
        var errors: [(String, String)] = []

        for url in urls {
            if Task.isCancelled { break }

            do {
                try safetyGuard.validatePath(url)
            } catch {
                errors.append((url.path(percentEncoded: false), error.localizedDescription))
                continue
            }

            let size = fileSize(url)

            do {
                switch mode {
                case .standard:
                    try FileManager.default.trashItem(at: url, resultingItemURL: nil)

                case .permanent:
                    try FileManager.default.removeItem(at: url)

                case .secure:
                    try secureOverwrite(url)
                    try FileManager.default.removeItem(at: url)
                }

                erasedCount += 1
                totalSize += size
            } catch {
                errors.append((url.path(percentEncoded: false), error.localizedDescription))
            }
        }

        return EraseResult(erasedCount: erasedCount, totalSize: totalSize, errors: errors)
    }

    private func secureOverwrite(_ url: URL) throws {

        let values = try url.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey, .isSymbolicLinkKey])

        guard values.isDirectory != true else {
            throw EraseError.secureEraseDirectory(url.path(percentEncoded: false))
        }

        guard values.isSymbolicLink != true else {
            throw SafetyGuard.SafetyError.symlinkTarget(url.path(percentEncoded: false))
        }
        let size = values.fileSize ?? 0
        guard size > 0 else { return }

        let handle = try FileHandle(forWritingTo: url)
        defer { try? handle.close() }

        let bufferSize = min(size, 65536)
        let zeros = Data(count: bufferSize)
        var remaining = size

        handle.seek(toFileOffset: 0)
        while remaining > 0 {
            let writeSize = min(remaining, bufferSize)
            handle.write(zeros.prefix(writeSize))
            remaining -= writeSize
        }

        handle.truncateFile(atOffset: 0)
    }

    private func fileSize(_ url: URL) -> UInt64 {
        let values = try? url.resourceValues(forKeys: [.totalFileAllocatedSizeKey, .fileSizeKey])
        return UInt64(values?.totalFileAllocatedSize ?? values?.fileSize ?? 0)
    }
}
