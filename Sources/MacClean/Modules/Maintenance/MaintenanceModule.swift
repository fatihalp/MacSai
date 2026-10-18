import Foundation
import MacCleanKit

public struct MaintenanceModule: ScanModule {
    public let id = "maintenance"
    public var name: String { String(localized: "Maintenance") }
    public let category = ModuleCategory.performance

    public init() {}

    public func scan() async -> [ScanResult] { [] }
}

public actor MaintenanceExecutor {
    public struct TaskResult: Sendable {
        public let task: MaintenanceTask
        public let success: Bool
        public let output: String
        public let error: String?
    }

    private let privilegedRunner: any PrivilegedShellRunning
    private let commandExists: @Sendable (String) -> Bool

    public init() {
        self.init(
            privilegedRunner: AppleScriptPrivilegedRunner(),
            commandExists: { FileManager.default.isExecutableFile(atPath: $0) }
        )
    }

    init(
        privilegedRunner: any PrivilegedShellRunning,
        commandExists: @escaping @Sendable (String) -> Bool
    ) {
        self.privilegedRunner = privilegedRunner
        self.commandExists = commandExists
    }

    public func execute(_ task: MaintenanceTask) async -> TaskResult {
        if case .speedUpMail = task { return await reindexMail() }
        if case .pruneDocker = task { return await pruneDocker() }

        guard let (command, args) = task.systemCommand else {
            return TaskResult(task: task, success: false, output: "",
                              error: String(localized: "Task has no system command"))
        }

        guard task.systemCommandIsAvailable(existing: commandExists) else {
            return TaskResult(
                task: task, success: false, output: "",
                error: "\(command) isn't available on this version of macOS, so this task can't run.")
        }

        if task.requiresAdmin {
            return await runAdminProcess(task: task, command: command, args: args)
        }
        return await runProcess(task: task, command: command, args: args)
    }

    private func runAdminProcess(task: MaintenanceTask, command: String, args: [String]) async -> TaskResult {
        let shell = MaintenanceShell.commandLine(command, args)
        let result = await privilegedRunner.run(commandLine: shell)

        if result.success {
            return TaskResult(task: task, success: true, output: result.output, error: nil)
        }

        let err = result.error ?? ""
        if MaintenanceShell.isAuthorizationCancelled(err, errorNumber: result.errorNumber) {
            return TaskResult(task: task, success: false, output: "",
                              error: String(localized: "Cancelled — administrator access was not granted."))
        }

        return TaskResult(task: task, success: false, output: "",
                          error: MaintenanceShell.humanReadableError(err))
    }

    private func runProcess(task: MaintenanceTask, command: String, args: [String]) async -> TaskResult {
        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()

        process.executableURL = URL(filePath: command)
        process.arguments = args
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        do {
            try process.run()
            process.waitUntilExit()

            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: outputData, encoding: .utf8) ?? ""
            let error = String(data: errorData, encoding: .utf8)

            return TaskResult(
                task: task,
                success: process.terminationStatus == 0,
                output: output,
                error: error?.isEmpty == true ? nil : error
            )
        } catch {
            return TaskResult(
                task: task,
                success: false,
                output: "",
                error: error.localizedDescription
            )
        }
    }

    private func reindexMail() async -> TaskResult {
        let mailEnvelopeIndex = MCConstants.mailData
            .appending(path: "V10/MailData/Envelope Index")

        let fm = FileManager.default
        if fm.fileExists(atPath: mailEnvelopeIndex.path(percentEncoded: false)) {
            do {
                try fm.removeItem(at: mailEnvelopeIndex)
                return TaskResult(
                    task: .speedUpMail,
                    success: true,
                    output: String(localized: "Mail envelope index removed. Mail will rebuild it on next launch."),
                    error: nil
                )
            } catch {
                return TaskResult(
                    task: .speedUpMail,
                    success: false,
                    output: "",
                    error: error.localizedDescription
                )
            }
        }

        return TaskResult(
            task: .speedUpMail,
            success: true,
            output: String(localized: "Mail envelope index not found — Mail may use a different version directory."),
            error: nil
        )
    }

    private func pruneDocker() async -> TaskResult {
        guard let docker = MaintenanceTask.resolveDockerPath(existing: {
            FileManager.default.isExecutableFile(atPath: $0)
        }) else {
            return TaskResult(
                task: .pruneDocker, success: false, output: "",
                error: String(localized: "Docker CLI not found. Make sure Docker Desktop is installed."))
        }
        return await runProcess(task: .pruneDocker, command: docker, args: ["system", "prune", "-f"])
    }
}
