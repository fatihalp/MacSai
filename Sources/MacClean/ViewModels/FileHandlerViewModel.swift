import Foundation
import AppKit
import SwiftUI
import MacCleanKit

@MainActor
public final class FileHandlerViewModel: ObservableObject {
    @Published public var handlers: [HandlerEntry] = []
    @Published public var isLoading = false
    @Published public var searchText = ""
    @Published public var errorMessage: String?
    @Published public var showError = false
    @Published public var backups: [URL] = []
    @Published public var showRestoreSheet = false
    @Published public var isRestoring = false

    private let service = LaunchServicesService.shared

    public var filteredHandlers: [HandlerEntry] {
        if searchText.isEmpty { return handlers }
        let q = searchText.lowercased()
        return handlers.filter { h in
            if h.fileTypeDescription.lowercased().contains(q) { return true }
            if let ct = h.contentType, ct.lowercased().contains(q) { return true }
            if let app = getAppInfo(for: h), app.name.lowercased().contains(q) { return true }
            if let bid = h.appBundleIdentifier, bid.lowercased().contains(q) { return true }
            return false
        }
    }

    public func loadHandlers() {
        isLoading = true

        Task {
            let loaded = await Task.detached { LaunchServicesService.shared.loadHandlers() }.value
            handlers = loaded
            isLoading = false
        }
    }

    public func deleteHandler(_ handler: HandlerEntry) {
        Task {
            do {
                try await Task.detached { try LaunchServicesService.shared.deleteHandler(handler) }.value
                loadHandlers()
            } catch {
                errorMessage = "Delete failed: \(error.localizedDescription)"
                showError = true
            }
        }
    }

    public func loadBackups() {
        backups = service.listBackups()
    }

    public func restoreBackup(from url: URL) {
        isRestoring = true
        Task {
            do {
                try await Task.detached { try LaunchServicesService.shared.restoreBackup(from: url) }.value
                isRestoring = false
                showRestoreSheet = false
                loadHandlers()
            } catch {
                isRestoring = false
                errorMessage = "Restore failed: \(error.localizedDescription)"
                showError = true
            }
        }
    }

    public func getAppInfo(for handler: HandlerEntry) -> (name: String, icon: NSImage)? {
        if let bid = handler.appBundleIdentifier {
            return service.getAppInfo(for: bid)
        }
        if handler.urlScheme != nil {
            return service.getURLSchemeAppInfo(for: handler.urlScheme)
        }
        return nil
    }
}
