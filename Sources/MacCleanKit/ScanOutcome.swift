import Foundation

public struct ScanOutcome: Sendable {
    public let items: [FileItem]

    public let permissionDeniedPaths: [URL]

    public init(items: [FileItem], permissionDeniedPaths: [URL] = []) {
        self.items = items
        self.permissionDeniedPaths = permissionDeniedPaths
    }

    public var permissionDenied: Bool { !permissionDeniedPaths.isEmpty }
}
