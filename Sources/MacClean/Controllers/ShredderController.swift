import Foundation
import Observation
import AppKit
import MacCleanKit

@MainActor @Observable
final class ShredderController {
    var filesToShred: [URL] = []
    var eraseMode: SecureEraser.EraseMode = .standard
    private(set) var isProcessing = false
    var result: SecureEraser.EraseResult?

    private let eraser = SecureEraser()

    func selectFiles() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = true
        panel.canChooseFiles = true

        if panel.runModal() == .OK {
            filesToShred = panel.urls
        }
    }

    func shred() {
        guard !isProcessing, !filesToShred.isEmpty else { return }
        let files = filesToShred
        let mode = eraseMode
        isProcessing = true
        Task {
            result = await eraser.erase(urls: files, mode: mode)
            isProcessing = false
        }
    }
}
