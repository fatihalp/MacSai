import Foundation
import MacCleanKit

public protocol ScanModule: Sendable {
    var id: String { get }
    var name: String { get }
    var category: ModuleCategory { get }
    var includedInSmartScan: Bool { get }
    func scan() async -> [ScanResult]
    func scanOutcome() async -> ModuleScanOutcome
}

public extension ScanModule {
    var includedInSmartScan: Bool { true }

    func scanOutcome() async -> ModuleScanOutcome {
        ModuleScanOutcome(results: await scan())
    }
}

public enum ModuleCategory: String, CaseIterable, Sendable {
    case cleanup = "清理"
    case protection = "防护"
    case performance = "性能"
    case applications = "应用"
    case files = "文件"
}

public struct ModuleScanOutcome: Sendable {
    public let results: [ScanResult]
    public let permissionDenied: Bool

    public init(results: [ScanResult], permissionDenied: Bool = false) {
        self.results = results
        self.permissionDenied = permissionDenied
    }
}
