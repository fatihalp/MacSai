import Foundation

public protocol JunkCategory: Sendable {
    var scanCategory: ScanCategory { get }
    var targets: [ScanTarget] { get }
}
