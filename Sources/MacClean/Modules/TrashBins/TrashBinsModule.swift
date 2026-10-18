import Foundation
import MacCleanKit

public struct TrashBinsModule: ScanModule {
    public let id = "trash_bins"
    public var name: String { String(localized: "Trash Bins") }
    public let category = ModuleCategory.cleanup

    private let scanner = TargetedScanner()

    public init() {}

    public func scan() async -> [ScanResult] {
        await scanReportingPermissions().results
    }

    public func scanReportingPermissions() async -> (results: [ScanResult], permissionDenied: Bool) {
        let outcome = await scanner.scanReportingPermissions(targets: Self.targets())
        guard !outcome.items.isEmpty else {
            return ([], outcome.permissionDenied)
        }
        let results = [ScanResult(category: .trashBins, items: outcome.items)]
            .filteringUncleanable()
        return (results, outcome.permissionDenied)
    }

    private static func targets() -> [ScanTarget] {
        var targets: [ScanTarget] = [

            ScanTarget(path: MCConstants.userTrash, recursive: true),
        ]

        if let volumes = FileManager.default.mountedVolumeURLs(
            includingResourceValuesForKeys: [.volumeIsRemovableKey],
            options: [.skipHiddenVolumes]
        ) {
            for volume in volumes {
                let trashURL = volume.appending(path: ".Trashes")
                if FileManager.default.fileExists(atPath: trashURL.path(percentEncoded: false)) {
                    targets.append(ScanTarget(path: trashURL, recursive: true))
                }
            }
        }
        return targets
    }
}
