import Foundation

public struct PackageManagerCachesCategory: JunkCategory {
    public init() {}
    public let scanCategory = ScanCategory.packageManagerCaches
    public var targets: [ScanTarget] {
        [
            MCConstants.npmCacache,
            MCConstants.yarnCache,
            MCConstants.pnpmStore,
            MCConstants.bunCache,
            MCConstants.cargoRegistryCache,
            MCConstants.cargoRegistrySrc,
            MCConstants.gradleCaches,
            MCConstants.gradleDaemon,
            MCConstants.gradleWrapperDists,
            MCConstants.homebrewCache,
            MCConstants.pipCache,
            MCConstants.uvCache,
            MCConstants.ruffCache,
            MCConstants.cocoapodsCache,
            MCConstants.swiftpmCache,
            MCConstants.playwrightCache,
            MCConstants.cypressCache,
        ].map { ScanTarget(path: $0, recursive: true) }
    }
}

public struct IDECachesCategory: JunkCategory {
    public init() {}
    public let scanCategory = ScanCategory.ideCaches
    public var targets: [ScanTarget] {
        (MCConstants.antigravityCaches
            + MCConstants.cursorCaches
            + MCConstants.vscodeCaches
            + MCConstants.windsurfCaches
            + [MCConstants.zedCache])
            .map { ScanTarget(path: $0, recursive: true) }
    }
}

public struct AIToolCachesCategory: JunkCategory {
    public init() {}
    public let scanCategory = ScanCategory.aiToolCaches
    public var targets: [ScanTarget] {
        [
            MCConstants.claudeCache,
            MCConstants.claudePasteCache,
            MCConstants.claudeShellSnapshots,
            MCConstants.codexTmp,
            MCConstants.codexCache,
        ].map { ScanTarget(path: $0, recursive: true) }
    }
}
