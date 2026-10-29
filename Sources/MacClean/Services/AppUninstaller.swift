import Foundation
import MacCleanKit

enum AppUninstaller {

    static func plan(
        app: AppInfo,
        associatedFiles: [FileItem],
        selectedFiles: Set<URL>,
        safetyGuard: SafetyGuard = SafetyGuard()
    ) -> (items: [FileItem], selection: Set<URL>)? {
        guard !safetyGuard.isProtectedApp(app.bundleIdentifier) else { return nil }

        let bundleItem = FileItem(
            url: app.path,
            name: app.name,
            size: app.size,
            allocatedSize: app.size,
            isDirectory: true
        )
        let items = [bundleItem] + associatedFiles

        let selection = selectedFiles.union([app.path])
        return (items, selection)
    }
}
