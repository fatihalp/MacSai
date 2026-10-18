import Foundation
import AppKit
import MacCleanKit

public struct UpdaterModule: ScanModule {
    public let id = "updater"
    public var name: String { String(localized: "Updater") }
    public let category = ModuleCategory.applications

    public init() {}

    public func scan() async -> [ScanResult] {
        []
    }
}

public actor AppUpdateChecker {
    public struct AppUpdate: Identifiable, Sendable {
        public let id: UUID = UUID()
        public let app: AppInfo
        public let currentVersion: String
        public let availableVersion: String?
        public let downloadURL: URL?
        public let updateSize: UInt64?
        public let hasUpdate: Bool
    }

    public init() {}

    public func checkForUpdates(apps: [AppInfo]) async -> [AppUpdate] {
        await withTaskGroup(of: AppUpdate?.self) { group in
            for app in apps where !app.isAppleApp {
                group.addTask {
                    await self.checkApp(app)
                }
            }

            var updates: [AppUpdate] = []
            for await update in group {
                if let update, update.hasUpdate {
                    updates.append(update)
                }
            }
            return updates.sorted { $0.app.name < $1.app.name }
        }
    }

    private func checkApp(_ app: AppInfo) async -> AppUpdate? {

        let infoPlistURL = app.path.appending(path: "Contents/Info.plist")
        guard let data = try? Data(contentsOf: infoPlistURL),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        else { return nil }

        guard let feedURLString = plist["SUFeedURL"] as? String,
              let feedURL = URL(string: feedURLString),
              UpdaterActions.isAcceptableFeedURL(feedURL)
        else { return nil }

        guard let (data, _) = try? await URLSession.shared.data(from: feedURL) else { return nil }

        let parser = AppcastParser()
        let (latestMarketingVersion, downloadURL) = parser.parseLatestItem(from: data)

        let currentVersion = app.version ?? "0"

        let hasUpdate = UpdaterActions.hasUpdate(
            current: currentVersion,
            available: latestMarketingVersion
        )

        return AppUpdate(
            app: app,
            currentVersion: currentVersion,
            availableVersion: latestMarketingVersion,
            downloadURL: downloadURL,
            updateSize: nil,
            hasUpdate: hasUpdate
        )
    }
}

public enum UpdaterRoute: Equatable {
    case appStore
    case download(URL)
    case launchApp(URL)
}

public enum UpdaterActions {

    public static func hasUpdate(current: String, available: String?) -> Bool {
        guard let available else { return false }
        return UpdateChecker.isNewer(available, than: current)
    }

    public static func isAcceptableFeedURL(_ url: URL) -> Bool {
        url.scheme?.lowercased() == "https"
    }

    public static func isSafeDownloadURL(_ url: URL) -> Bool {
        url.scheme?.lowercased() == "https"
    }

    public static func route(isMacAppStore: Bool, downloadURL: URL?, appPath: URL) -> UpdaterRoute {
        if isMacAppStore { return .appStore }
        if let downloadURL { return .download(downloadURL) }
        return .launchApp(appPath)
    }

    public static func isMacAppStoreApp(at appPath: URL) -> Bool {
        FileManager.default.fileExists(
            atPath: appPath.appending(path: "Contents/_MASReceipt/receipt").path(percentEncoded: false))
    }

    @MainActor
    public static func perform(_ update: AppUpdateChecker.AppUpdate) {
        switch route(isMacAppStore: isMacAppStoreApp(at: update.app.path),
                     downloadURL: update.downloadURL, appPath: update.app.path) {
        case .appStore:
            if let url = URL(string: "macappstore://showUpdatesPage") { NSWorkspace.shared.open(url) }
        case .download(let url):

            guard isSafeDownloadURL(url) else { return }
            NSWorkspace.shared.open(url)
        case .launchApp(let appURL):
            NSWorkspace.shared.openApplication(at: appURL, configuration: .init())
        }
    }
}
