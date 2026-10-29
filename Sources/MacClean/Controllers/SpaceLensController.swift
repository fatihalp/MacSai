import Foundation
import Observation
import AppKit
import MacCleanKit

@MainActor @Observable
final class SpaceLensController {
    var rootNode: FileNode?
    var treemapRects: [TreemapRect] = []
    var isScanning = false
    @ObservationIgnored private var scanTask: Task<Void, Never>?
    var nav = SpaceLensNavigation(root: MCConstants.home)
    var itemsScanned = 0

    private let scanner = FileTreeScanner()

    var totalFormattedSize: String {
        rootNode?.formattedTotalSize ?? ""
    }

    func startScan() {
        scanTask?.cancel()
        isScanning = true
        itemsScanned = 0
        let root = nav.current
        scanTask = Task {

            let children = await scanner.topLevelSizes(root: root) { count in
                Task { @MainActor in self.itemsScanned = count }
            }
            guard !Task.isCancelled else { return }

            let total = children.reduce(UInt64(0)) { $0 + $1.totalSize }
            rootNode = FileNode(url: root, name: root.lastPathComponent, size: total, isDirectory: true)

            let treemapNodes = children
                .sorted { $0.totalSize > $1.totalSize }
                .prefix(50)
                .map { child in
                    TreemapNode(
                        name: child.name,
                        size: child.totalSize,
                        url: child.url,
                        isDirectory: child.isDirectory,
                        fileExtension: child.fileExtension
                    )
                }

            let bounds = CGRect(x: 0, y: 0, width: 700, height: 400)
            treemapRects = SquarifiedTreemap.layout(nodes: Array(treemapNodes), in: bounds)
            nav.commitPendingNavigation()
            isScanning = false
        }
    }
    func cancelScan() {
        scanTask?.cancel()
        scanTask = nil
        nav.cancelPendingNavigation()
        isScanning = false
    }
}
