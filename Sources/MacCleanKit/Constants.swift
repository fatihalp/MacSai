import Foundation

public enum MCConstants {
    public static let appName = "Mac Sai"
    public static let bundleIdentifier = "com.macclean.app"
    public static let helperBundleIdentifier = "com.macclean.helper"
    public static let menuBundleIdentifier = "com.macclean.menu"

    public static let teamIdentifier = "H3XLS95QV4"

    public static func codeSigningRequirement(for identifier: String) -> String {
        "identifier \"\(identifier)\" and anchor apple generic and "
            + "certificate leaf[subject.OU] = \"\(teamIdentifier)\""
    }

    public static let maxFilesPerOperation = 10_000

    public static let cleanChunkSize = 5_000

    public static let maxTotalItemsPerCleanOperation = 500_000

    public static let cleanConfirmationThreshold = 50_000
    public static let scanThrottleInterval: TimeInterval = 0.05

    public static let protectedPaths: Set<String> = [
        "/System",
        "/usr",
        "/bin",
        "/sbin",
        "/Library/Apple",
        "/private/var/db",
    ]

    public static let protectedApps: Set<String> = [
        "com.apple.finder",
        "com.apple.Safari",
        "com.apple.mail",
        "com.apple.Terminal",
        "com.apple.systempreferences",
        "com.apple.ActivityMonitor",
        "com.apple.Console",
        "com.apple.DiskUtility",
        "com.apple.dt.Xcode",
        "com.apple.AppStore",
        "com.apple.iCal",
        "com.apple.AddressBook",
        "com.apple.Preview",
        "com.apple.TextEdit",
        "com.apple.calculator",
        "com.apple.Dictionary",
        "com.apple.Maps",
        "com.apple.Notes",
        "com.apple.reminders",
        "com.apple.Stickies",
        "com.apple.VoiceMemos",
        "com.apple.stocks",
        "com.apple.weather",
        "com.apple.Passwords",
        "com.apple.FaceTime",
        "com.apple.MobileSMS",
        "com.apple.Photos",
        "com.apple.Music",
    ]

    public static let home = FileManager.default.homeDirectoryForCurrentUser

    public static let userLibrary = home.appending(path: "Library")
    public static let userCaches = userLibrary.appending(path: "Caches")
    public static let userLogs = userLibrary.appending(path: "Logs")
    public static let userPreferences = userLibrary.appending(path: "Preferences")
    public static let userAppSupport = userLibrary.appending(path: "Application Support")
    public static let userContainers = userLibrary.appending(path: "Containers")
    public static let userGroupContainers = userLibrary.appending(path: "Group Containers")
    public static let userLaunchAgents = userLibrary.appending(path: "LaunchAgents")
    public static let userSavedAppState = userLibrary.appending(path: "Saved Application State")
    public static let userCookies = userLibrary.appending(path: "Cookies")
    public static let userHTTPStorages = userLibrary.appending(path: "HTTPStorages")
    public static let userAppScripts = userLibrary.appending(path: "Application Scripts")
    public static let userWebKit = userLibrary.appending(path: "WebKit")

    public static let systemLibrary = URL(filePath: "/Library")
    public static let systemCaches = systemLibrary.appending(path: "Caches")
    public static let systemLogs = systemLibrary.appending(path: "Logs")
    public static let systemLaunchAgents = systemLibrary.appending(path: "LaunchAgents")
    public static let systemLaunchDaemons = systemLibrary.appending(path: "LaunchDaemons")
    public static let varLog = URL(filePath: "/var/log")

    public static let userTrash = home.appending(path: ".Trash")
    public static let downloads = home.appending(path: "Downloads")
    public static let documentVersions = home.appending(path: ".DocumentRevisions-V100")
    public static let mobileBackups = userAppSupport.appending(path: "MobileSync/Backup")

    public static let xcodeDerivedData = userLibrary.appending(path: "Developer/Xcode/DerivedData")
    public static let xcodeArchives = userLibrary.appending(path: "Developer/Xcode/Archives")
    public static let xcodeDeviceSupport = userLibrary.appending(path: "Developer/Xcode/iOS DeviceSupport")
    public static let coreSimulator = userLibrary.appending(path: "Developer/CoreSimulator")
    public static let xcodePreviews = userLibrary.appending(path: "Developer/Xcode/UserData/Previews")

    public static let safariCache = userLibrary.appending(path: "Caches/com.apple.Safari")
    public static let chromeDefault = userAppSupport.appending(path: "Google/Chrome/Default")
    public static let chromeCache = userCaches.appending(path: "Google/Chrome")
    public static let firefoxProfiles = userAppSupport.appending(path: "Firefox/Profiles")
    public static let firefoxCache = userCaches.appending(path: "Firefox/Profiles")

    public static let mailData = userLibrary.appending(path: "Mail")
    public static let mailDownloads = userLibrary.appending(path: "Mail Downloads")
    public static let mailContainerDownloads = userContainers
        .appending(path: "com.apple.mail/Data/Library/Mail Downloads")

    public static let homebrewCache = userCaches.appending(path: "Homebrew")
    public static let npmCache = userCaches.appending(path: "npm")
    public static let pipCache = userCaches.appending(path: "pip")
    public static let cargoRegistry = home.appending(path: ".cargo/registry")

    public static let npmCacache = home.appending(path: ".npm/_cacache")
    public static let yarnCache = userCaches.appending(path: "Yarn")
    public static let pnpmStore = userLibrary.appending(path: "pnpm/store")
    public static let bunCache = home.appending(path: ".bun/install/cache")
    public static let cargoRegistryCache = home.appending(path: ".cargo/registry/cache")
    public static let cargoRegistrySrc = home.appending(path: ".cargo/registry/src")
    public static let gradleCaches = home.appending(path: ".gradle/caches")
    public static let gradleDaemon = home.appending(path: ".gradle/daemon")
    public static let gradleWrapperDists = home.appending(path: ".gradle/wrapper/dists")
    public static let cocoapodsCache = userCaches.appending(path: "CocoaPods")
    public static let swiftpmCache = userCaches.appending(path: "org.swift.swiftpm")
    public static let uvCache = userCaches.appending(path: "uv")
    public static let ruffCache = userCaches.appending(path: "ruff")
    public static let playwrightCache = userCaches.appending(path: "ms-playwright")
    public static let cypressCache = userCaches.appending(path: "Cypress")

    public static let claudeCache = home.appending(path: ".claude/cache")
    public static let claudePasteCache = home.appending(path: ".claude/paste-cache")
    public static let claudeShellSnapshots = home.appending(path: ".claude/shell-snapshots")
    public static let codexTmp = home.appending(path: ".codex/.tmp")
    public static let codexCache = home.appending(path: ".codex/cache")

    public static func electronEditorCaches(_ appSupportName: String) -> [URL] {
        let base = userAppSupport.appending(path: appSupportName)
        return ["Cache", "Code Cache", "GPUCache", "CachedData", "CachedProfilesData"]
            .map { base.appending(path: $0) }
    }
    public static var antigravityCaches: [URL] { electronEditorCaches("Antigravity") }
    public static var cursorCaches: [URL] { electronEditorCaches("Cursor") }
    public static var vscodeCaches: [URL] { electronEditorCaches("Code") }
    public static var windsurfCaches: [URL] { electronEditorCaches("Windsurf") }
    public static let zedCache = userCaches.appending(path: "dev.zed.Zed")

    public static let preservedLanguages: Set<String> = [
        "en.lproj", "English.lproj", "Base.lproj", "en_US.lproj", "en_GB.lproj",
        "zh.lproj", "zh-Hans.lproj", "zh-Hant.lproj", "zh_CN.lproj", "zh_TW.lproj",
        "Chinese.lproj", "Simplified Chinese.lproj", "Traditional Chinese.lproj",
        "ru.lproj", "ru-RU.lproj", "ru_RU.lproj", "Russian.lproj",
        "de.lproj", "de-DE.lproj", "de_DE.lproj", "de-AT.lproj", "de_AT.lproj",
        "de-CH.lproj", "de_CH.lproj", "German.lproj",
        "fr.lproj", "fr-FR.lproj", "fr_FR.lproj", "French.lproj",
        "it.lproj", "it-IT.lproj", "it_IT.lproj", "it-CH.lproj", "it_CH.lproj", "Italian.lproj",
    ]

    public static let operationLogDir = userLogs.appending(path: "MacClean")
    public static let operationLogFile = operationLogDir.appending(path: "operations.log")

    public static let cleanHistoryFile = operationLogDir.appending(path: "clean-history.json")

    public static let repoURL = URL(string: "https://github.com/iliyami/MacSai")!
    public static let issuesURL = URL(string: "https://github.com/iliyami/MacSai/issues/new/choose")!
    public static let releasesURL = URL(string: "https://github.com/iliyami/MacSai/releases")!

    public static let supportURL = URL(string: "https://buymeacoffee.com/iliyami")!
    public static let latestReleaseAPI = URL(string: "https://api.github.com/repos/iliyami/MacSai/releases/latest")!

    public static let homebrewCaskAPI = URL(string: "https://formulae.brew.sh/api/cask/mac-sai.json")!

    public static let appVersion = "1.26.0"
}
