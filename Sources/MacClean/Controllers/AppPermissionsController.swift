import Foundation
import Observation
import AppKit
import MacCleanKit

@MainActor @Observable
final class AppPermissionsController {
    private(set) var snapshot = AppPermissionsSnapshot(grants: [], listing: .loaded)
    private(set) var isLoading = true

    let client: AppPermissionsClient

    init(client: AppPermissionsClient = .live()) {
        self.client = client
    }

    var apps: [AppPermissionApp] {
        AppPermissionOverview.apps(from: snapshot.grants)
    }

    func reload() async {
        isLoading = true
        let loaded = await client.load()
        guard !Task.isCancelled else { return }
        snapshot = loaded
        isLoading = false
    }
}
