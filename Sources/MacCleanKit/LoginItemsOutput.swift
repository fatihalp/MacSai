import Foundation

public struct ParsedLoginItem: Equatable, Sendable {
    public let name: String
    public let path: String?
    public let hidden: Bool

    public init(name: String, path: String?, hidden: Bool) {
        self.name = name
        self.path = path
        self.hidden = hidden
    }
}

public enum LoginItemsOutput {
    public static func parse(_ output: String) -> [ParsedLoginItem] {
        var items: [ParsedLoginItem] = []
        var name: String?
        var path: String?
        var hidden = false

        func flush() {
            if let name, !name.isEmpty {
                items.append(ParsedLoginItem(name: name, path: path, hidden: hidden))
            }
            name = nil
            path = nil
            hidden = false
        }

        for line in output.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            for pair in trimmed.components(separatedBy: ", ") {
                let kv = pair.split(separator: ":", maxSplits: 1).map(String.init)
                guard kv.count == 2 else { continue }
                let key = kv[0].trimmingCharacters(in: .whitespaces)
                let val = kv[1].trimmingCharacters(in: .whitespaces)
                switch key {
                case "name":
                    flush()
                    name = val
                case "path": path = val
                case "hidden": hidden = (val.lowercased() == "true")
                default: break
                }
            }
        }
        flush()
        return items
    }
}
