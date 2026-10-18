import Foundation

public enum MaintenanceShell {
    public static func quote(_ argument: String) -> String {
        "'" + argument.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    public static func commandLine(_ executable: String, _ arguments: [String]) -> String {
        ([executable] + arguments).map(quote).joined(separator: " ")
    }

    public static func appleScriptSource(commandLine: String) -> String {
        let escaped = commandLine
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "do shell script \"\(escaped)\" with administrator privileges"
    }

    public static func isAuthorizationCancelled(_ message: String, errorNumber: Int? = nil) -> Bool {
        if errorNumber == -128 { return true }
        return message.contains("User canceled") || message.contains("-128")
    }

    public static func humanReadableError(_ raw: String) -> String {
        var message = raw.trimmingCharacters(in: .whitespacesAndNewlines)

        if let prefix = message.range(
            of: #"^(\d+:\d+:\s*)?execution error:\s*"#,
            options: .regularExpression
        ) {
            message.removeSubrange(prefix)
        }

        if let suffix = message.range(
            of: #"\s*\(-?\d+\)\s*$"#,
            options: .regularExpression
        ) {
            message.removeSubrange(suffix)
        }
        return message.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
