import Foundation
import MacCleanKit

enum AppReset {

    static func plan(
        app: AppInfo,
        associatedFiles: [FileItem],
        selectedFiles: Set<URL>
    ) -> (items: [FileItem], selection: Set<URL>)? {
        let items = AppResetPolicy.resetableItems(
            from: associatedFiles,
            selected: selectedFiles,
            appBundle: app.path
        )
        guard !items.isEmpty else { return nil }
        return (items, Set(items.map(\.url)))
    }
}
