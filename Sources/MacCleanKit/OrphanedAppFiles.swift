import Foundation

public enum OrphanedAppFiles {

    static let helperSuffixes = [
        ".helper", ".agent", ".daemon", ".launcher", ".updater", ".framework",
        ".xpc", ".findersync", ".quicklook", ".shareextension", ".widget",
        ".loginitem", ".service",
    ]

    static let neverFlagPrefixes = [
        "com.apple.",
        "org.chromium.",
        "com.google.keystone",
        "org.qt-project.",
        "io.qt.",
        "com.github.electron",
        "com.electron.",
    ]

    public static func isOrphan(bundleID: String, installedBundleIDs: Set<String>) -> Bool {
        let id = bundleID.lowercased()

        guard isBundleIDLike(id) else { return false }

        if neverFlagPrefixes.contains(where: { id == $0 || id.hasPrefix($0) }) {
            return false
        }

        let installed = Set(installedBundleIDs.map { $0.lowercased() })
        let base = strippingHelperSuffixes(id)

        for installedID in installed {
            if sharesLineage(installedID, id) || sharesLineage(installedID, base) {
                return false
            }
        }
        return true
    }

    static func sharesLineage(_ a: String, _ b: String) -> Bool {
        a == b || a.hasPrefix(b + ".") || b.hasPrefix(a + ".")
    }

    static func isBundleIDLike(_ s: String) -> Bool {
        let parts = s.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count >= 3, parts.allSatisfy({ !$0.isEmpty }) else { return false }
        return s.allSatisfy { $0.isLetter || $0.isNumber || $0 == "." || $0 == "-" || $0 == "_" }
    }

    static func strippingHelperSuffixes(_ id: String) -> String {
        var result = id
        var changed = true
        while changed {
            changed = false
            for suffix in helperSuffixes where result.hasSuffix(suffix) && result.count > suffix.count {
                result = String(result.dropLast(suffix.count))
                changed = true
            }
        }
        return result
    }
}
