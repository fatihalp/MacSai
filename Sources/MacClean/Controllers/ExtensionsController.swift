import Foundation
import Observation
import AppKit
import MacCleanKit

@MainActor @Observable
final class ExtensionsController {
    private(set) var items: [ManagedExtension] = []
    private(set) var isLoading = true
    private(set) var isRemoving = false
    var errorMessage: String?

    let client: ManagedExtensionsClient
    private let engine: CleaningEngine

    init(client: ManagedExtensionsClient = .live(), engine: CleaningEngine = CleaningEngine()) {
        self.client = client
        self.engine = engine
    }

    func reload() async {
        isLoading = true
        let loaded = await client.load()
        guard !Task.isCancelled else { return }
        items = loaded
        isLoading = false
    }

    func remove(_ item: ManagedExtension) async {
        guard !isRemoving else { return }
        isRemoving = true
        let urls = client.trashURLs(from: [item])
        guard !urls.isEmpty else {
            errorMessage = String(localized: "This item was refused for safety reasons.")
            isRemoving = false
            return
        }
        let fileItems = urls.map { url in
            FileItem(
                url: url,
                name: url.lastPathComponent,
                size: 0,
                allocatedSize: 0,
                isDirectory: true,
                isPackage: true
            )
        }
        let result = await CleanActions.executeUserClean(
            items: fileItems,
            selectedItems: Set(urls),
            engine: engine
        )
        if !result.errors.isEmpty {
            errorMessage = "Couldn't move \(item.name) to the Trash."
        }
        await reload()
        isRemoving = false
    }
}
