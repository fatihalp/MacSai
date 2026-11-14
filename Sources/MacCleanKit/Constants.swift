import Foundation

public enum MCConstants {
    public static let appName = "MacNull"
    public static let bundleIdentifier = "com.macclean.app"
    public static let helperBundleIdentifier = "com.macclean.helper"
    public static let menuBundleIdentifier = "com.macclean.menu"

    public static let teamIdentifier = "H3XLS95QV4"

    public static let maxFilesPerOperation = 10_000

    public static let cleanChunkSize = 5_000

    public static let maxTotalItemsPerCleanOperation = 500_000

    public static let cleanConfirmationThreshold = 50_000

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

    public static let systemLibrary: URL = URL(filePath: "/Library")
    public static let systemCaches: URL = systemLibrary.appending(path: "Caches")
    public static let osSystemCaches: URL = URL(filePath: "/System/Library/Caches")
    public static let systemLogs: URL = systemLibrary.appending(path: "Logs")
    public static let systemLaunchAgents: URL = systemLibrary.appending(path: "LaunchAgents")
    public static let systemLaunchDaemons: URL = systemLibrary.appending(path: "LaunchDaemons")
    public static let varLog: URL = URL(filePath: "/private/var/log")
    public static let varLogSymlink: URL = URL(filePath: "/var/log")
    public static let coreSpotlightPipelineStorage: URL = userLibrary.appending(path: "Metadata/CoreSpotlight/DocumentProcessing/PipelineStorage")
    public static let assistantLLMCache: URL = userLibrary.appending(path: "Assistant/LLMCache")
    public static let mobileAssetsV2: URL = URL(filePath: "/System/Library/AssetsV2")
    public static let siriUnderstandingAsset: URL = mobileAssetsV2.appending(path: "com_apple_MobileAsset_UAF_Siri_Understanding")
    public static let siriTTSAsset: URL = mobileAssetsV2.appending(path: "com_apple_MobileAsset_UAF_Siri_TextToSpeech")
    public static let speechRecognitionAsset: URL = mobileAssetsV2.appending(path: "com_apple_MobileAsset_UAF_Speech_AutomaticSpeechRecognition")

    public static var darwinUserCacheDir: URL? {
        var buf: [CChar] = [CChar](repeating: 0, count: 1024)
        guard confstr(_CS_DARWIN_USER_CACHE_DIR, &buf, 1024) > 0 else { return nil }
        var resolved: [CChar] = [CChar](repeating: 0, count: 1024)
        if realpath(buf, &resolved) != nil {
            let path: String = resolved.withUnsafeBufferPointer { (ptr: UnsafeBufferPointer<CChar>) -> String in
                ptr.baseAddress.map { String(cString: $0) } ?? ""
            }
            if !path.isEmpty { return URL(filePath: path) }
        }
        let fallback: String = buf.withUnsafeBufferPointer { (ptr: UnsafeBufferPointer<CChar>) -> String in
            ptr.baseAddress.map { String(cString: $0) } ?? ""
        }
        return fallback.isEmpty ? nil : URL(filePath: fallback)
    }

    public static var darwinUserTempDir: URL? {
        var buf: [CChar] = [CChar](repeating: 0, count: 1024)
        guard confstr(_CS_DARWIN_USER_TEMP_DIR, &buf, 1024) > 0 else { return nil }
        var resolved: [CChar] = [CChar](repeating: 0, count: 1024)
        if realpath(buf, &resolved) != nil {
            let path: String = resolved.withUnsafeBufferPointer { (ptr: UnsafeBufferPointer<CChar>) -> String in
                ptr.baseAddress.map { String(cString: $0) } ?? ""
            }
            if !path.isEmpty { return URL(filePath: path) }
        }
        let fallback: String = buf.withUnsafeBufferPointer { (ptr: UnsafeBufferPointer<CChar>) -> String in
            ptr.baseAddress.map { String(cString: $0) } ?? ""
        }
        return fallback.isEmpty ? nil : URL(filePath: fallback)
    }

    public static let userTrash = home.appending(path: ".Trash")
    public static let downloads = home.appending(path: "Downloads")
    public static let documentVersions = home.appending(path: ".DocumentRevisions-V100")
    public static let mobileBackups = userAppSupport.appending(path: "MobileSync/Backup")

    public static let xcodeDerivedData = userLibrary.appending(path: "Developer/Xcode/DerivedData")
    public static let xcodeArchives = userLibrary.appending(path: "Developer/Xcode/Archives")
    public static let xcodeDeviceSupport = userLibrary.appending(path: "Developer/Xcode/iOS DeviceSupport")
    public static let coreSimulator = userLibrary.appending(path: "Developer/CoreSimulator")
    public static let dockerDesktopDiskImages = [
        userContainers.appending(path: "com.docker.docker/Data/vms/0/data/Docker.raw"),
        userContainers.appending(path: "com.docker.docker/Data/vms/0/data/Docker.qcow2"),
    ]
    public static let xcodePreviews = userLibrary.appending(path: "Developer/Xcode/UserData/Previews")

    public static let safariCache = userLibrary.appending(path: "Caches/com.apple.Safari")
    public static let chromeCache = userCaches.appending(path: "Google/Chrome")
    public static let firefoxCache = userCaches.appending(path: "Firefox/Profiles")

    public static let mailData = userLibrary.appending(path: "Mail")
    public static let mailDownloads = userLibrary.appending(path: "Mail Downloads")
    public static let mailContainerDownloads = userContainers
        .appending(path: "com.apple.mail/Data/Library/Mail Downloads")

    public static let homebrewCache = userCaches.appending(path: "Homebrew")
    public static let pipCache = userCaches.appending(path: "pip")

    public static let npmCacache = home.appending(path: ".npm/_cacache")
    public static let yarnCache = userCaches.appending(path: "Yarn")
    public static let pnpmStore = userLibrary.appending(path: "pnpm/store")
    public static let bunCache = home.appending(path: ".bun/install/cache")
    public static let cargoRegistryCache = home.appending(path: ".cargo/registry/cache")
    public static let cargoRegistrySrc = home.appending(path: ".cargo/registry/src")
    public static let cargoGit = home.appending(path: ".cargo/git")
    public static let rustupDownloads = home.appending(path: ".rustup/downloads")
    public static let rustupTmp = home.appending(path: ".rustup/tmp")
    public static let rustupToolchains = home.appending(path: ".rustup/toolchains")
    public static let rustupUpdateHashes = home.appending(path: ".rustup/update-hashes")
    public static let pubCache = home.appending(path: ".pub-cache")
    public static let dartServer = home.appending(path: ".dartServer")
    public static let composerCache = userCaches.appending(path: "composer")
    public static let composerHomeCache = home.appending(path: ".composer/cache")
    public static let gradleCaches = home.appending(path: ".gradle/caches")
    public static let gradleDaemon = home.appending(path: ".gradle/daemon")
    public static let gradleWrapperDists = home.appending(path: ".gradle/wrapper/dists")
    public static let cocoapodsCache = userCaches.appending(path: "CocoaPods")
    public static let swiftpmCache = userCaches.appending(path: "org.swift.swiftpm")
    public static let uvCache = userCaches.appending(path: "uv")
    public static let uvXDGCache = home.appending(path: ".cache/uv")
    public static let pnpmCache = userCaches.appending(path: "pnpm")
    public static let pnpmXDGCache = home.appending(path: ".cache/pnpm")
    public static let ruffCache = userCaches.appending(path: "ruff")
    public static let playwrightCache = userCaches.appending(path: "ms-playwright")
    public static let cypressCache = userCaches.appending(path: "Cypress")
    public static let dockerInstaller = userAppSupport.appending(path: "com.docker.install")

    public static let npxCache = home.appending(path: ".npm/_npx")
    public static let npmLogs = home.appending(path: ".npm/_logs")
    public static let puppeteerCache = home.appending(path: ".cache/puppeteer")
    public static let vcpkgCache = home.appending(path: ".cache/vcpkg")
    public static let vcpkgDownloads = home.appending(path: "vcpkg/downloads")
    public static let turboHomeCache = home.appending(path: ".turbo/cache")
    public static let userDiagnosticReports = userLogs.appending(path: "DiagnosticReports")
    public static let systemDiagnosticReports = URL(filePath: "/Library/Logs/DiagnosticReports")

    public static var chromeAppCaches: [URL] {
        [
            userAppSupport.appending(path: "Google/Chrome/Default/Service Worker/CacheStorage"),
            userAppSupport.appending(path: "Google/Chrome/Default/Service Worker/ScriptCache"),
            userAppSupport.appending(path: "Google/Chrome/Default/Code Cache"),
            userAppSupport.appending(path: "Google/Chrome/Default/GPUCache"),
            userAppSupport.appending(path: "Google/Chrome/Default/DawnWebGPUCache"),
            userAppSupport.appending(path: "Google/Chrome/Default/DawnGraphiteCache"),
        ]
    }

    public static var braveAppCaches: [URL] {
        [
            userCaches.appending(path: "com.brave.Browser"),
            userCaches.appending(path: "BraveSoftware"),
            userAppSupport.appending(path: "BraveSoftware/Brave-Browser/Default/Service Worker/CacheStorage"),
            userAppSupport.appending(path: "BraveSoftware/Brave-Browser/Default/Code Cache"),
            userAppSupport.appending(path: "BraveSoftware/Brave-Browser/Default/GPUCache"),
        ]
    }

    public static var desktopAppCaches: [URL] {
        electronEditorCaches("Claude")
            + electronEditorCaches("Wispr Flow")
            + electronEditorCaches("Postman")
            + electronEditorCaches("Slack")
            + electronEditorCaches("discord")
            + [
                userCaches.appending(path: "com.anthropic.claudefordesktop.ShipIt"),
                userCaches.appending(path: "com.spotify.client/Data"),
                userCaches.appending(path: "com.spotify.client/Storage"),
                userCaches.appending(path: "com.spotify.client/Browser"),
                userCaches.appending(path: "JetBrains"),
                userCaches.appending(path: "us.zoom.xos"),
                userAppSupport.appending(path: "Zed/cache"),
                userAppSupport.appending(path: "Steam/appcache"),
            ]
    }

    public static let openClawHome = home.appending(path: ".openclaw")
    public static let openClawLogs = openClawHome.appending(path: "logs")
    public static let openClawWorkspace = openClawHome.appending(path: "workspace")
    public static let opencodeCache = home.appending(path: ".cache/opencode")
    public static let phpactorCache = home.appending(path: ".cache/phpactor")
    public static let copilotSdkCache = userCaches.appending(path: "github-copilot-sdk")
    public static let copilotCache = userCaches.appending(path: "copilot")

    public static func electronEditorCaches(_ appSupportName: String) -> [URL] {
        let base = userAppSupport.appending(path: appSupportName)
        return ["Cache", "Code Cache", "GPUCache", "CachedData", "CachedProfilesData", "GraphiteDawnCache", "Crashpad", "logs"]
            .map { base.appending(path: $0) }
    }
    public static var antigravityCaches: [URL] {
        electronEditorCaches("Antigravity")
            + electronEditorCaches("Antigravity IDE")
            + [
                home.appending(path: ".gemini/antigravity/conversations"),
                home.appending(path: ".gemini/antigravity/brain"),
                home.appending(path: ".gemini/antigravity/cache"),
                home.appending(path: ".gemini/antigravity/crashes"),
                home.appending(path: ".gemini/antigravity/scratch"),
                home.appending(path: ".gemini/antigravity/daemon"),
                home.appending(path: ".gemini/antigravity/conversation_summaries.db"),
                home.appending(path: ".gemini/antigravity/conversation_summaries.db-wal"),
                home.appending(path: ".gemini/antigravity/conversation_summaries.db-shm"),
                home.appending(path: ".gemini/antigravity/annotations"),
                home.appending(path: ".gemini/antigravity/agyhub_summaries_proto.pb"),
                home.appending(path: ".gemini/tmp"),
                home.appending(path: ".gemini/history"),
                userCaches.appending(path: "com.google.antigravity"),
                userCaches.appending(path: "com.google.antigravity.ShipIt"),
            ]
    }
    public static var codexCaches: [URL] {
        electronEditorCaches("Codex")
            + [
                home.appending(path: ".codex/sessions"),
                home.appending(path: ".codex/archived_sessions"),
                home.appending(path: ".codex/thread_history_1.sqlite"),
                home.appending(path: ".codex/thread_history_1.sqlite-wal"),
                home.appending(path: ".codex/thread_history_1.sqlite-shm"),
                home.appending(path: ".codex/computer-use"),
                home.appending(path: ".codex/logs_2.sqlite"),
                home.appending(path: ".codex/logs_2.sqlite-wal"),
                home.appending(path: ".codex/logs_2.sqlite-shm"),
                home.appending(path: ".codex/queue_1.sqlite"),
                home.appending(path: ".codex/queue_1.sqlite-wal"),
                home.appending(path: ".codex/queue_1.sqlite-shm"),
                home.appending(path: ".codex/worktrees"),
                home.appending(path: ".codex/visualizations"),
                home.appending(path: ".codex/shell_snapshots"),
                home.appending(path: ".codex/attachments"),
                home.appending(path: ".codex/ambient-suggestions"),
                home.appending(path: ".codex/browser"),
                home.appending(path: ".codex/tmp"),
                home.appending(path: ".codex/.tmp"),
                home.appending(path: ".codex/cache"),
                home.appending(path: ".codex/telemetry"),
                home.appending(path: ".codex/plugins/cache"),
                home.appending(path: ".codex/plugins/.remote-plugin-install-staging"),
                home.appending(path: ".codex/sqlite"),
                home.appending(path: ".cache/codex-runtimes"),
                home.appending(path: ".cache/puppeteer"),
                userAppSupport.appending(path: "Codex/component_crx_cache"),
                userAppSupport.appending(path: "Codex/artifact-sessions"),
                userCaches.appending(path: "Codex"),
                userCaches.appending(path: "com.openai.codex"),
                userCaches.appending(path: "com.openai.codex.ShipIt"),
            ]
    }
    public static var claudeCaches: [URL] {
        electronEditorCaches("Claude")
            + [
                home.appending(path: ".claude/projects"),
                home.appending(path: ".claude/cache"),
                home.appending(path: ".claude/paste-cache"),
                home.appending(path: ".claude/shell-snapshots"),
                home.appending(path: ".claude/telemetry"),
                home.appending(path: ".claude/uploads"),
                home.appending(path: ".claude/file-history"),
                home.appending(path: ".claude/backups"),
                home.appending(path: ".cache/claude"),
                userAppSupport.appending(path: "Claude/Shared Dictionary"),
                userAppSupport.appending(path: "Claude/claude-code-sessions"),
                userCaches.appending(path: "com.anthropic.claudedesktop"),
                userCaches.appending(path: "com.anthropic.claudedesktop.ShipIt"),
                userCaches.appending(path: "com.anthropic.claudefordesktop"),
                userCaches.appending(path: "com.anthropic.claudefordesktop.ShipIt"),
            ]
    }
    public static var whatsAppCaches: [URL] {
        [
            userContainers.appending(path: "net.whatsapp.WhatsApp/Data/tmp"),
            userContainers.appending(path: "net.whatsapp.WhatsApp/Data/Library/Caches"),
            userContainers.appending(path: "net.whatsapp.WhatsApp/Data/Library/Orphaned"),
            userContainers.appending(path: "net.whatsapp.WhatsApp/Data/Library/HTTPStorages"),
            userContainers.appending(path: "net.whatsapp.WhatsApp/Data/Library/Application Support/net.whatsapp.WhatsApp/analytics"),
            userContainers.appending(path: "net.whatsapp.WhatsApp.ServiceExtension/Data/Library/Caches"),
            userContainers.appending(path: "net.whatsapp.WhatsApp.ServiceExtension/Data/tmp"),
            userContainers.appending(path: "net.whatsapp.WhatsApp.WAAppKitBridgeService/Data/Library/Caches"),
            userContainers.appending(path: "net.whatsapp.WhatsApp.WAAppKitBridgeService/Data/tmp"),
            userAppSupport.appending(path: "WhatsApp/Cache"),
            userAppSupport.appending(path: "WhatsApp/Code Cache"),
            userAppSupport.appending(path: "WhatsApp/GPUCache"),
            userAppSupport.appending(path: "WhatsApp/logs"),
            userCaches.appending(path: "net.whatsapp.WhatsApp"),
            userCaches.appending(path: "WhatsApp"),
        ]
    }
    public static var cursorCaches: [URL] { electronEditorCaches("Cursor") }
    public static var vscodeCaches: [URL] { electronEditorCaches("Code") }
    public static var windsurfCaches: [URL] { electronEditorCaches("Windsurf") }
    public static let zedCache = userCaches.appending(path: "dev.zed.Zed")

    public static var userCachesExcludedPaths: [URL] {
        [
            homebrewCache,
            pipCache,
            cocoapodsCache,
            swiftpmCache,
            playwrightCache,
            cypressCache,
            uvCache,
            pnpmCache,
            ruffCache,
            zedCache,
            copilotSdkCache,
            copilotCache,
            userCaches.appending(path: "com.google.antigravity"),
            userCaches.appending(path: "com.google.antigravity.ShipIt"),
            userCaches.appending(path: "Codex"),
            userCaches.appending(path: "com.openai.codex"),
            userCaches.appending(path: "com.openai.codex.ShipIt"),
            userCaches.appending(path: "com.anthropic.claudedesktop"),
            userCaches.appending(path: "com.anthropic.claudedesktop.ShipIt"),
            userCaches.appending(path: "com.anthropic.claudefordesktop"),
            userCaches.appending(path: "com.anthropic.claudefordesktop.ShipIt"),
            userCaches.appending(path: "net.whatsapp.WhatsApp"),
            userCaches.appending(path: "WhatsApp"),
            userCaches.appending(path: "com.brave.Browser"),
            userCaches.appending(path: "BraveSoftware"),
            userCaches.appending(path: "JetBrains"),
            userCaches.appending(path: "us.zoom.xos"),
            userCaches.appending(path: "com.spotify.client"),
        ]
    }

    public static let operationLogDir = userLogs.appending(path: "MacClean")
    public static let operationLogFile = operationLogDir.appending(path: "operations.log")

    public static let cleanHistoryFile = operationLogDir.appending(path: "clean-history.json")

    public static let repoURL = URL(string: "https://github.com/iliyami/MacSai")!
    public static let issuesURL = URL(string: "https://github.com/iliyami/MacSai/issues/new/choose")!
    public static let releasesURL = URL(string: "https://github.com/iliyami/MacSai/releases")!

    public static let supportURL = URL(string: "https://buymeacoffee.com/iliyami")!

    public static let appVersion = "1.27.0"
}
