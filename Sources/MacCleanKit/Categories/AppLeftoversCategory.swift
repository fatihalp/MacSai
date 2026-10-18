import Foundation

public struct AppLeftoversCategory: JunkCategory {
    public init() {}
    public let scanCategory = ScanCategory.appLeftovers
    public var targets: [ScanTarget] { [] }
}
