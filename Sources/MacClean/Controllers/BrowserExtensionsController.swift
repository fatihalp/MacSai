import Foundation
import Observation
import AppKit
import MacCleanKit

@MainActor @Observable
final class BrowserExtensionsController {
    private(set) var scan = BrowserExtensionScan(records: [], safariListed: true)
    private(set) var isLoading = true
    private(set) var isWorking = false
    var message: String?

    let client: BrowserExtensionsClient

    init(client: BrowserExtensionsClient = BrowserExtensionsClient()) {
        self.client = client
    }

    func reload() async {
        isLoading = true
        let loaded = await client.list()
        guard !Task.isCancelled else { return }
        scan = loaded
        isLoading = false
    }

    func remove(_ record: BrowserExtensionRecord) async {
        guard !isWorking else { return }
        isWorking = true
        let outcome = await client.applyRemoval(record)
        message = BrowserExtensionsStrings.message(for: outcome)
        if outcome == .trashed { scan = await client.list() }
        isWorking = false
    }
}
