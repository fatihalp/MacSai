import Foundation

public enum SensitiveRemnantMatcher {
    private static let sensitiveDirectoryComponents: Set<String> = [
        ".ssh",
        ".gnupg",
        ".aws",
        ".kube",
        "keychains",
    ]

    private static let sensitiveFileNames: Set<String> = [
        "id_rsa",
        "id_ed25519",
        "id_ecdsa",
        "known_hosts",
        "authorized_keys",
        "credentials",
        ".netrc",
        ".npmrc",
        ".pypirc",
        "cookies.sqlite",
        "login data",
        "key4.db",
        "logins.json",
        "wallet.dat",
    ]

    private static let sensitiveSubstrings: [String] = [
        "/library/keychains/",
        "/.ssh/",
        "/.gnupg/",
        "/.aws/credentials",
        "/.kube/config",
        ".keychain",
        ".keychain-db",
    ]

    public static func isSensitive(path: String) -> Bool {
        let lower = path.lowercased()
        for sub in sensitiveSubstrings where lower.contains(sub) {
            return true
        }
        let url = URL(filePath: path)
        let fileName = url.lastPathComponent.lowercased()
        if sensitiveFileNames.contains(fileName) {
            return true
        }
        for component in url.pathComponents {
            if sensitiveDirectoryComponents.contains(component.lowercased()) {
                return true
            }
        }
        return false
    }
}
