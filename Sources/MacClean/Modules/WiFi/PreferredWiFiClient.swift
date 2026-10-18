import Foundation
import MacCleanKit

struct PreferredWiFiClient: Sendable {
    typealias CommandResult = (stdout: String, stderr: String, status: Int32)

    var run: @Sendable (String, [String]) async -> CommandResult
    var runAdminShell: @Sendable (String) async -> CommandResult

    static func live() -> PreferredWiFiClient {
        PreferredWiFiClient(
            run: { command, args in await Self.runProcess(command: command, arguments: args) },
            runAdminShell: { shell in
                let escaped = shell
                    .replacingOccurrences(of: "\\", with: "\\\\")
                    .replacingOccurrences(of: "\"", with: "\\\"")
                let script = "do shell script \"\(escaped)\" with administrator privileges"
                return await Self.runProcess(command: "/usr/bin/osascript", arguments: ["-e", script])
            }
        )
    }

    func listNetworks() async -> Result<[PreferredWiFiNetwork], PreferredWiFiClientError> {
        let hw = await run(PreferredWiFiCommands.networksetup, PreferredWiFiCommands.listHardwarePortsArguments)
        guard hw.status == 0 else {
            return .failure(.commandFailed(hw.stderr.isEmpty ? hw.stdout : hw.stderr))
        }
        let devices = PreferredWiFiParser.wifiDevices(from: hw.stdout)
        guard !devices.isEmpty else { return .failure(.noWiFiHardware) }

        var all: [PreferredWiFiNetwork] = []
        for device in devices {
            guard let args = PreferredWiFiCommands.listPreferredArguments(device: device) else { continue }
            let listed = await run(PreferredWiFiCommands.networksetup, args)
            if listed.status == 0 {
                all.append(contentsOf: PreferredWiFiParser.preferredNetworks(from: listed.stdout, device: device))
            }
        }
        return .success(all)
    }

    func forget(_ networks: [PreferredWiFiNetwork]) async -> Result<Void, PreferredWiFiClientError> {
        guard !networks.isEmpty else { return .success(()) }
        guard let shell = PreferredWiFiCommands.removeBatchShellCommand(networks: networks) else {
            return .failure(.invalidDevice)
        }
        let result = await runAdminShell(shell)
        if result.status == 0 { return .success(()) }
        let raw = result.stderr.isEmpty ? result.stdout : result.stderr
        if raw.contains("User canceled") || raw.contains("-128") {
            return .failure(.adminCancelled)
        }
        return .failure(.commandFailed(MaintenanceShell.humanReadableError(raw)))
    }

    private static func runProcess(command: String, arguments: [String]) async -> CommandResult {
        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.executableURL = URL(filePath: command)
        process.arguments = arguments
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        do {
            try process.run()
            process.waitUntilExit()
            let stdout = String(data: outputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            let stderr = String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            return (stdout, stderr, process.terminationStatus)
        } catch {
            return ("", error.localizedDescription, -1)
        }
    }
}

enum PreferredWiFiClientError: Error, Equatable {
    case noWiFiHardware
    case invalidDevice
    case adminCancelled
    case commandFailed(String)

    var localizedMessage: String {
        switch self {
        case .noWiFiHardware:
            String(localized: "No Wi-Fi hardware found.")
        case .invalidDevice:
            String(localized: "The Wi-Fi interface name was invalid, so the action was cancelled.")
        case .adminCancelled:
            String(localized: "Cancelled — administrator access was not granted.")
        case .commandFailed(let message):
            message.isEmpty
                ? String(localized: "Couldn't update saved Wi-Fi networks.")
                : message
        }
    }
}
