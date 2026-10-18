import Foundation
import OSLog

public actor ThinBinaryOperation {

    public struct Result: Sendable {
        public let originalSize: UInt64
        public let thinnedSize: UInt64
        public var bytesSaved: UInt64 {
            originalSize > thinnedSize ? originalSize - thinnedSize : 0
        }
    }

    public enum OpError: Error, LocalizedError, Sendable {
        case notFat
        case raceDetected(String)
        case lipoFailed(stderr: String)
        case backupFailed(String)

        public var errorDescription: String? {
            switch self {
            case .notFat:
                String(localized: "input binary is not a fat (universal) Mach-O")
            case .raceDetected(let message):
                "binary changed under us while thinning: \(message)"
            case .lipoFailed(let stderr):
                "lipo failed: \(stderr)"
            case .backupFailed(let message):
                "atomic backup/promote failed: \(message)"
            }
        }
    }

    private let logger = Logger(subsystem: MCConstants.bundleIdentifier,
                                category: "ThinBinaryOperation")

    public init() {}

    public func thin(binary: URL, to targetArch: BinaryArch) async throws -> Result {
        let fm = FileManager.default
        let backupDir = fm.temporaryDirectory
            .appending(path: "macclean-thinning-\(UUID().uuidString)")
        try fm.createDirectory(at: backupDir, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: backupDir) }
        let backupURL = backupDir.appending(path: "\(binary.lastPathComponent).original")
        return try await thin(binary: binary, to: targetArch, backupTo: backupURL)
    }

    public func thin(binary: URL, to targetArch: BinaryArch, backupTo backupURL: URL) async throws -> Result {
        let fm = FileManager.default
        let path = binary.path(percentEncoded: false)

        let archs = try Self.runLipoInfo(at: path)
        guard archs.count > 1 else {
            throw OpError.notFat
        }
        guard archs.contains(targetArch.lipoName) else {
            throw OpError.lipoFailed(stderr: "target arch \(targetArch.lipoName) not present in \(archs)")
        }

        let originalAttrs = try fm.attributesOfItem(atPath: path)
        let originalSize = (originalAttrs[.size] as? NSNumber)?.uint64Value ?? 0
        let originalMode = (originalAttrs[.posixPermissions] as? NSNumber)?.int16Value ?? 0o755
        let originalInode = (originalAttrs[.systemFileNumber] as? NSNumber)?.uint64Value ?? 0

        let workDir = fm.temporaryDirectory
            .appending(path: "macclean-thinning-\(UUID().uuidString)")
        try fm.createDirectory(at: workDir, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: workDir) }

        let thinningURL = workDir.appending(path: "\(binary.lastPathComponent).thinned")

        let preLipoAttrs = try fm.attributesOfItem(atPath: path)
        let preLipoSize = (preLipoAttrs[.size] as? NSNumber)?.uint64Value ?? 0
        let preLipoInode = (preLipoAttrs[.systemFileNumber] as? NSNumber)?.uint64Value ?? 0
        if preLipoInode != originalInode || preLipoSize != originalSize {
            throw OpError.raceDetected(
                "inode \(originalInode)→\(preLipoInode) or size \(originalSize)→\(preLipoSize) changed between start and lipo step"
            )
        }

        try Self.runLipoThin(
            input: path,
            output: thinningURL.path(percentEncoded: false),
            arch: targetArch.lipoName
        )
        try fm.setAttributes(
            [.posixPermissions: NSNumber(value: originalMode)],
            ofItemAtPath: thinningURL.path(percentEncoded: false)
        )

        do {
            try fm.moveItem(at: binary, to: backupURL)
        } catch {
            throw OpError.backupFailed("could not back up original: \(error.localizedDescription)")
        }
        do {
            try fm.moveItem(at: thinningURL, to: binary)
        } catch {
            try? fm.moveItem(at: backupURL, to: binary)
            throw OpError.backupFailed("could not promote thinned file: \(error.localizedDescription)")
        }

        let thinnedAttrs = try fm.attributesOfItem(atPath: path)
        let thinnedSize = (thinnedAttrs[.size] as? NSNumber)?.uint64Value ?? 0
        logger.info("Thinned \(path, privacy: .public): \(originalSize) → \(thinnedSize)")
        return Result(originalSize: originalSize, thinnedSize: thinnedSize)
    }

    private static func runLipoInfo(at path: String) throws -> [String] {
        let (status, stdout, _) = try runProcess(
            "/usr/bin/lipo", ["-info", path]
        )
        guard status == 0 else { throw OpError.lipoFailed(stderr: stdout) }
        if let range = stdout.range(of: "are: ") {
            return stdout[range.upperBound...]
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .split(separator: " ")
                .map(String.init)
        }
        if let range = stdout.range(of: "is architecture: ") {
            return [stdout[range.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)]
        }
        return []
    }

    private static func runLipoThin(input: String, output: String, arch: String) throws {
        let (status, _, stderr) = try runProcess(
            "/usr/bin/lipo", ["-thin", arch, input, "-output", output]
        )
        guard status == 0 else { throw OpError.lipoFailed(stderr: stderr) }
    }

    private static func runProcess(
        _ executable: String, _ args: [String]
    ) throws -> (Int32, String, String) {
        let process = Process()
        let outPipe = Pipe()
        let errPipe = Pipe()
        process.executableURL = URL(filePath: executable)
        process.arguments = args
        process.standardOutput = outPipe
        process.standardError = errPipe
        try process.run()
        process.waitUntilExit()
        let stdout = String(data: outPipe.fileHandleForReading.readDataToEndOfFile(),
                            encoding: .utf8) ?? ""
        let stderr = String(data: errPipe.fileHandleForReading.readDataToEndOfFile(),
                            encoding: .utf8) ?? ""
        return (process.terminationStatus, stdout, stderr)
    }
}
