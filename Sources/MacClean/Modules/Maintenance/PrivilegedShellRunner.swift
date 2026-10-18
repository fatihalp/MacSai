import AppKit
import Foundation
import MacCleanKit

struct PrivilegedShellResult: Sendable, Equatable {
    let success: Bool
    let output: String
    let error: String?
    let errorNumber: Int?

    static func ok(_ output: String) -> PrivilegedShellResult {
        PrivilegedShellResult(success: true, output: output, error: nil, errorNumber: nil)
    }

    static func failed(_ error: String, errorNumber: Int? = nil) -> PrivilegedShellResult {
        PrivilegedShellResult(success: false, output: "", error: error, errorNumber: errorNumber)
    }
}

protocol PrivilegedShellRunning: Sendable {
    func run(commandLine: String) async -> PrivilegedShellResult
}

struct AppleScriptPrivilegedRunner: PrivilegedShellRunning {
    private static let queue = DispatchQueue(label: "sai.maintenance.privileged-applescript")

    func run(commandLine: String) async -> PrivilegedShellResult {
        let source = MaintenanceShell.appleScriptSource(commandLine: commandLine)
        return await withCheckedContinuation { continuation in
            Self.queue.async {
                continuation.resume(returning: Self.execute(source))
            }
        }
    }

    private static func execute(_ source: String) -> PrivilegedShellResult {
        guard let script = NSAppleScript(source: source) else {
            return .failed("Failed to create AppleScript")
        }
        var error: NSDictionary?
        let descriptor = script.executeAndReturnError(&error)
        if let error {
            let message = (error[NSAppleScript.errorMessage] as? String)
                ?? "AppleScript failed"
            let number = (error[NSAppleScript.errorNumber] as? NSNumber)?.intValue
                ?? error[NSAppleScript.errorNumber] as? Int
            return .failed(message, errorNumber: number)
        }
        return .ok(descriptor.stringValue ?? "")
    }
}
