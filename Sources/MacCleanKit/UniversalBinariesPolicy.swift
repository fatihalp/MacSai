import Foundation

public enum BinaryArch: String, CaseIterable, Sendable, Hashable {
    case x86_64
    case arm64
    case arm64e
    case i386

    public init?(lipoName: String) {
        self.init(rawValue: lipoName)
    }

    public var lipoName: String { rawValue }
}

public struct BundleHostInfo: Sendable, Equatable {
    public let hostArch: BinaryArch

    public init(hostArch: BinaryArch) {
        self.hostArch = hostArch
    }

    public static var current: BundleHostInfo {
        #if arch(arm64)
        BundleHostInfo(hostArch: .arm64)
        #else
        BundleHostInfo(hostArch: .x86_64)
        #endif
    }
}

public struct AppBundleInfo: Sendable, Equatable {
    public let bundlePath: String
    public let bundleID: String
    public let isAppStore: Bool
    public let architectures: Set<BinaryArch>

    public init(
        bundlePath: String,
        bundleID: String,
        isAppStore: Bool,
        architectures: Set<BinaryArch>
    ) {
        self.bundlePath = bundlePath
        self.bundleID = bundleID
        self.isAppStore = isAppStore
        self.architectures = architectures
    }
}

public enum ThinDecision: Equatable, Sendable {
    case thin(targetArch: BinaryArch, dropping: Set<BinaryArch>)
    case skip(reason: SkipReason)

    public enum SkipReason: String, Sendable {
        case alreadyThin
        case hostArchNotPresent
        case appStoreApp
        case appleSystemApp
        case sipProtected
        case pointerAuthSlicePresent
    }
}

public struct UniversalBinariesPolicy: Sendable {
    public init() {}

    public func decideThinning(
        for bundle: AppBundleInfo,
        host: BundleHostInfo
    ) -> ThinDecision {
        if bundle.bundlePath.hasPrefix("/System/") {
            return .skip(reason: .sipProtected)
        }
        if bundle.bundleID.hasPrefix("com.apple.") ||
           bundle.bundlePath.hasPrefix("/Applications/Utilities/") {
            return .skip(reason: .appleSystemApp)
        }
        if bundle.isAppStore {
            return .skip(reason: .appStoreApp)
        }
        if bundle.architectures.contains(.arm64e) {
            return .skip(reason: .pointerAuthSlicePresent)
        }
        if bundle.architectures.count <= 1 {
            return bundle.architectures.contains(host.hostArch)
                ? .skip(reason: .alreadyThin)
                : .skip(reason: .hostArchNotPresent)
        }
        guard bundle.architectures.contains(host.hostArch) else {
            return .skip(reason: .hostArchNotPresent)
        }
        let dropping = bundle.architectures.subtracting([host.hostArch])
        return .thin(targetArch: host.hostArch, dropping: dropping)
    }

    public static func estimatedSavings(
        originalSize: UInt64,
        originalArchCount: Int,
        droppingCount: Int
    ) -> UInt64 {
        guard originalArchCount > 0, droppingCount > 0 else { return 0 }
        return originalSize * UInt64(droppingCount) / UInt64(originalArchCount)
    }
}
