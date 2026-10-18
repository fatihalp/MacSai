import Foundation
import OSLog

public actor ThinAppBundleOperation {

    public struct Result: Sendable {
        public let binariesProcessed: Int
        public let binariesThinned: Int
        public let bytesSaved: UInt64
        public let perBinaryErrors: [String: String]
        public let bundleVerifyFailed: Bool
    }

    public enum OpError: Error, LocalizedError, Sendable {
        case noFatBinariesFound
        case bundleInUse(pids: [String])
        case bundleVerifyFailed(stderr: String)

        public var errorDescription: String? {
            switch self {
            case .noFatBinariesFound:
                String(localized: "no fat (universal) Mach-O binaries found in bundle")
            case .bundleInUse(let pids):
                "bundle is in use by process(es) \(pids.joined(separator: ", ")) — quit the app and try again"
            case .bundleVerifyFailed(let s):
                "thinning would have invalidated the app's code signature, so it was rolled back: \(s)"
            }
        }
    }

    private let logger = Logger(subsystem: MCConstants.bundleIdentifier,
                                category: "ThinAppBundleOperation")

    public init() {}

    public func thin(bundle: URL, to targetArch: BinaryArch) async throws -> Result {

        let busyPIDs = try Self.pidsHoldingFilesIn(bundle: bundle)
        if !busyPIDs.isEmpty {
            throw OpError.bundleInUse(pids: busyPIDs)
        }

        let binaries = MachOWalker.fatBinaries(in: bundle)
        guard !binaries.isEmpty else { throw OpError.noFatBinariesFound }

        let bundleWasSigned = Self.codesignVerifiesDeep(bundle)

        let fm = FileManager.default
        let backupDir = fm.temporaryDirectory
            .appending(path: "macclean-bundlethin-\(UUID().uuidString)")
        try fm.createDirectory(at: backupDir, withIntermediateDirectories: true)

        defer { try? fm.removeItem(at: backupDir) }

        let op = ThinBinaryOperation()
        var thinned = 0
        var saved: UInt64 = 0
        var perBin: [String: String] = [:]
        var rollback: [(binary: URL, backup: URL)] = []

        for (index, binary) in binaries.enumerated() {
            let backupURL = backupDir.appending(path: "\(index).original")
            do {
                let r = try await op.thin(binary: binary, to: targetArch, backupTo: backupURL)
                thinned += 1
                saved += r.bytesSaved
                rollback.append((binary: binary, backup: backupURL))
            } catch {
                let path = binary.path(percentEncoded: false)
                perBin[path] = error.localizedDescription
                logger.error("ThinBinaryOperation failed on \(path, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
        }

        if thinned > 0, bundleWasSigned, !Self.codesignVerifiesDeep(bundle) {
            for entry in rollback {
                try? fm.removeItem(at: entry.binary)
                try? fm.moveItem(at: entry.backup, to: entry.binary)
            }
            try? fm.removeItem(at: backupDir)
            throw OpError.bundleVerifyFailed(
                stderr: String(localized: "bundle no longer passes codesign --verify after thinning")
            )
        }

        try? fm.removeItem(at: backupDir)

        return Result(
            binariesProcessed: binaries.count,
            binariesThinned: thinned,
            bytesSaved: saved,
            perBinaryErrors: perBin,
            bundleVerifyFailed: false
        )
    }

    static func pidsHoldingFilesIn(bundle: URL) throws -> [String] {
        let (_, stdout, _) = try runProcess("/usr/sbin/lsof", [
            "-F", "p",
            "+D", bundle.path(percentEncoded: false),
        ])
        var pids = Set<String>()
        for line in stdout.split(separator: "\n") where line.first == "p" {
            pids.insert(String(line.dropFirst()))
        }
        return Array(pids)
    }

    private static func codesignVerifiesDeep(_ bundle: URL) -> Bool {
        guard let (status, _, _) = try? runProcess("/usr/bin/codesign", [
            "--verify", "--deep", bundle.path(percentEncoded: false),
        ]) else { return false }
        return status == 0
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
        let stdout = String(
            data: outPipe.fileHandleForReading.readDataToEndOfFile(),
            encoding: .utf8
        ) ?? ""
        let stderr = String(
            data: errPipe.fileHandleForReading.readDataToEndOfFile(),
            encoding: .utf8
        ) ?? ""
        return (process.terminationStatus, stdout, stderr)
    }
}
