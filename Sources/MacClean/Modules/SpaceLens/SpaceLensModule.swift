import Foundation
import MacCleanKit

public struct SpaceLensModule: ScanModule {
    public let id = "space_lens"
    public var name: String { String(localized: "Space Lens") }
    public let category = ModuleCategory.files
    public let includedInSmartScan = false

    public init() {}

    public func scan() async -> [ScanResult] { [] }
}

public extension VolumeInfo {
    static func mountedVolumes() -> [VolumeInfo] {
        guard let urls = FileManager.default.mountedVolumeURLs(
            includingResourceValuesForKeys: [
                .volumeNameKey, .volumeTotalCapacityKey,
                .volumeAvailableCapacityForImportantUsageKey,
                .volumeLocalizedFormatDescriptionKey,
            ],
            options: [.skipHiddenVolumes]
        ) else { return [] }

        return urls.compactMap { url in
            guard let values = try? url.resourceValues(forKeys: [
                .volumeNameKey, .volumeTotalCapacityKey,
                .volumeAvailableCapacityForImportantUsageKey,
                .volumeLocalizedFormatDescriptionKey,
            ]) else { return nil }

            return VolumeInfo(
                name: values.volumeName ?? url.lastPathComponent,
                url: url,
                totalCapacity: UInt64(values.volumeTotalCapacity ?? 0),
                availableCapacity: UInt64(values.volumeAvailableCapacityForImportantUsage ?? 0),
                fileSystemType: values.volumeLocalizedFormatDescription
            )
        }
    }
}
