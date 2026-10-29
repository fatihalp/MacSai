import Foundation
import Observation
import AppKit
import MacCleanKit

@MainActor @Observable
final class SettingsController {
    private(set) var updateState: UpdateUIState = .idle
    private(set) var keptLanguages: Set<String> = []
    private(set) var selectable: [(name: String, lprojs: [String])] = []
    var languageSearch: String = ""
    private(set) var excludedFolders: [String] = FolderExclusionPreferences.paths
    private(set) var exclusionError: String?

    enum UpdateUIState: Equatable {
        case idle
        case checking
        case upToDate
        case available(version: String, url: URL)
        case failed(message: String)
    }

    var filteredLanguages: [(name: String, lprojs: [String])] {
        guard !languageSearch.isEmpty else { return selectable }
        return selectable.filter { $0.name.localizedCaseInsensitiveContains(languageSearch) }
    }

    func startUpdateCheck() {
        guard updateState != .checking else { return }
        updateState = .checking
        Task {
            let result = await UpdateChecker.check()
            switch result {
            case .upToDate:
                updateState = .upToDate
            case .updateAvailable(let version, let url):
                updateState = .available(version: version, url: url)
            case .failed(let message):
                updateState = .failed(message: message)
            }
        }
    }

    func addExcludedFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = String(localized: "Exclude")
        panel.message = String(localized: "Choose a folder to exclude from cleanup.")
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let path = url.path(percentEncoded: false)
        if FolderExclusionPreferences.add(path) {
            excludedFolders = FolderExclusionPreferences.paths
            exclusionError = nil
        } else {
            exclusionError = rejectionMessage(for: path)
        }
    }

    func rejectionMessage(for path: String) -> String {
        switch PathExclusion.candidateDecision(
            for: path,
            home: NSHomeDirectory(),
            maxCount: FolderExclusionPreferences.defaultMaxCount,
            existing: FolderExclusionPreferences.paths
        ) {
        case .allow:
            return String(localized: "Couldn't add that folder.")
        case .reject(.notAbsolute):
            return String(localized: "Choose an absolute path.")
        case .reject(.entireHome):
            return String(localized: "You can't exclude your entire home folder.")
        case .reject(.entireVolumesRoot):
            return String(localized: "You can't exclude all of /Volumes.")
        case .reject(.outsideAllowedRoots):
            return String(localized: "Only folders under your home directory or /Volumes can be excluded.")
        case .reject(.atCapacity):
            return "You can exclude at most \(FolderExclusionPreferences.defaultMaxCount) folders."
        case .reject(.alreadyCovered):
            return String(localized: "That path is already covered by an existing exclusion.")
        }
    }
    func loadPreferences() async {
        keptLanguages = LanguagePreferences.userKept
        selectable = LanguagePreferences.selectableLanguages()
        excludedFolders = FolderExclusionPreferences.paths
        let found = await Task.detached(priority: .userInitiated) {
            LanguageScanner().discoverLproj(in: LanguageScanner.defaultRoots)
        }.value
        guard !Task.isCancelled else { return }
        LanguagePreferences.discoveredLproj = found
        selectable = LanguagePreferences.selectableLanguages()
    }

    func setLanguage(_ lprojs: [String], kept: Bool) {
        if kept { keptLanguages.formUnion(lprojs) }
        else { keptLanguages.subtract(lprojs) }
        LanguagePreferences.userKept = keptLanguages
    }

    func removeExcludedFolder(_ path: String) {
        FolderExclusionPreferences.remove(path)
        excludedFolders = FolderExclusionPreferences.paths
        exclusionError = nil
    }
    func setInterfaceLanguage(_ identifier: String) {
        Localization.currentID = identifier
        selectable = LanguagePreferences.selectableLanguages()
    }

}
