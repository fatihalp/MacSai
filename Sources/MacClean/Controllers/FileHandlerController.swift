import Foundation
import AppKit
import Observation
import MacCleanKit

@MainActor @Observable
public final class FileHandlerController {
    public private(set) var handlers: [HandlerEntry] = []
    public private(set) var isLoading = false
    public var searchText = ""
    public var errorMessage: String?
    public var showError = false
    public private(set) var backups: [URL] = []
    public var showRestoreSheet = false
    public private(set) var isRestoring = false

    private let service: LaunchServicesService

    public init(service: LaunchServicesService = .shared) {
        self.service = service
    }

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

        let service = service
        Task {
            let loaded = await Task.detached { service.loadHandlers() }.value
            handlers = loaded
            isLoading = false
        }
    }

    public func deleteHandler(_ handler: HandlerEntry) {
        let service = service
        Task {
            do {
                try await Task.detached { try service.deleteHandler(handler) }.value
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
        let service = service
        Task {
            do {
                try await Task.detached { try service.restoreBackup(from: url) }.value
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
