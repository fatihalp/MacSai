import Foundation
import CoreGraphics

public enum FileTypeCategory: String, Sendable, CaseIterable {
    case folders
    case documents
    case images
    case video
    case audio
    case archives
    case code
    case diskImages
    case applications
    case system
    case other

    public var label: String {
        switch self {
        case .folders: String(localized: "Folders")
        case .documents: String(localized: "Documents")
        case .images: String(localized: "Images")
        case .video: String(localized: "Video")
        case .audio: String(localized: "Audio")
        case .archives: String(localized: "Archives")
        case .code: String(localized: "Code")
        case .diskImages: String(localized: "Disk Images")
        case .applications: String(localized: "Applications")
        case .system: String(localized: "System")
        case .other: String(localized: "Other")
        }
    }

    public static func category(forFileExtension ext: String, isDirectory: Bool) -> FileTypeCategory {
        if isDirectory { return .folders }
        let lower = ext.lowercased()
        switch lower {
        case "mp4", "mov", "avi", "mkv", "wmv", "flv", "webm": return .video
        case "mp3", "wav", "flac", "aac", "m4a", "ogg", "wma": return .audio
        case "jpg", "jpeg", "png", "gif", "bmp", "tiff", "heic", "webp": return .images
        case "pdf", "doc", "docx", "pages", "rtf", "txt", "odt": return .documents
        case "xls", "xlsx", "numbers", "csv", "ods": return .documents
        case "ppt", "pptx", "key": return .documents
        case "zip", "gz", "tar", "rar", "7z", "bz2", "xz": return .archives
        case "dmg", "iso", "img", "sparseimage": return .diskImages
        case "app": return .applications
        case "pkg", "mpkg": return .applications
        case "swift", "h", "m", "mm", "c", "cpp", "py", "js", "ts",
             "java", "rs", "go", "rb", "php", "css", "html", "sh",
             "json", "xml", "yaml", "toml", "plist", "entitlements": return .code
        case "kext", "dylib", "framework", "bundle": return .system
        case "log", "cache", "db", "sqlite": return .system
        default: return .other
        }
    }
}

public struct TreemapNode: Sendable {
    public let name: String
    public let size: UInt64
    public let url: URL
    public let isDirectory: Bool
    public let fileExtension: String
    public let fileTypeCategory: FileTypeCategory
    public let children: [TreemapNode]

    public init(
        name: String,
        size: UInt64,
        url: URL,
        isDirectory: Bool,
        fileExtension: String = "",
        children: [TreemapNode] = []
    ) {
        self.name = name
        self.size = size
        self.url = url
        self.isDirectory = isDirectory
        self.fileExtension = fileExtension
        self.fileTypeCategory = FileTypeCategory.category(forFileExtension: fileExtension, isDirectory: isDirectory)
        self.children = children
    }

    public var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
    }
}

public struct TreemapRect: Identifiable, Sendable {
    public let id: UUID
    public let node: TreemapNode
    public let rect: CGRect

    public init(node: TreemapNode, rect: CGRect) {
        self.id = UUID()
        self.node = node
        self.rect = rect
    }
}

public enum SquarifiedTreemap {

    public static func layout(nodes: [TreemapNode], in rect: CGRect) -> [TreemapRect] {
        guard !nodes.isEmpty, rect.width > 0, rect.height > 0 else { return [] }

        let totalSize = nodes.reduce(0.0) { $0 + Double($1.size) }
        guard totalSize > 0 else { return [] }

        let sorted = nodes.sorted { $0.size > $1.size }
        let areas = sorted.map { Double($0.size) / totalSize * Double(rect.width * rect.height) }

        var results: [TreemapRect] = []
        var remaining = Array(zip(sorted, areas))
        var currentRect = rect

        while !remaining.isEmpty {
            let (row, rest, newRect) = squarify(remaining: remaining, in: currentRect)
            results.append(contentsOf: row)
            remaining = rest
            currentRect = newRect
        }

        return results
    }

    private static func squarify(
        remaining: [(TreemapNode, Double)],
        in rect: CGRect
    ) -> ([TreemapRect], [(TreemapNode, Double)], CGRect) {
        guard !remaining.isEmpty else { return ([], [], rect) }

        let isWide = rect.width >= rect.height
        let sideLength = isWide ? rect.height : rect.width

        var row: [(TreemapNode, Double)] = []
        var rowArea: Double = 0
        var bestAspect = Double.infinity
        var rest = remaining

        for (i, (node, area)) in remaining.enumerated() {
            let newRow = row + [(node, area)]
            let newRowArea = rowArea + area
            let aspect = worstAspectRatio(
                areas: newRow.map(\.1),
                totalArea: newRowArea,
                sideLength: Double(sideLength)
            )

            if aspect <= bestAspect {
                row = newRow
                rowArea = newRowArea
                bestAspect = aspect
                rest = Array(remaining.dropFirst(i + 1))
            } else {
                rest = Array(remaining.dropFirst(i))
                break
            }
        }

        let rowLength = rowArea / Double(sideLength)
        var results: [TreemapRect] = []
        var offset: CGFloat = 0

        for (node, area) in row {
            let itemLength = area / rowLength
            let itemRect: CGRect
            if isWide {
                itemRect = CGRect(
                    x: rect.minX,
                    y: rect.minY + offset,
                    width: CGFloat(rowLength),
                    height: CGFloat(itemLength)
                )
            } else {
                itemRect = CGRect(
                    x: rect.minX + offset,
                    y: rect.minY,
                    width: CGFloat(itemLength),
                    height: CGFloat(rowLength)
                )
            }
            results.append(TreemapRect(node: node, rect: itemRect))
            offset += CGFloat(itemLength)
        }

        let newRect: CGRect
        if isWide {
            newRect = CGRect(
                x: rect.minX + CGFloat(rowLength),
                y: rect.minY,
                width: rect.width - CGFloat(rowLength),
                height: rect.height
            )
        } else {
            newRect = CGRect(
                x: rect.minX,
                y: rect.minY + CGFloat(rowLength),
                width: rect.width,
                height: rect.height - CGFloat(rowLength)
            )
        }

        return (results, rest, newRect)
    }

    public static func worstAspectRatio(
        areas: [Double],
        totalArea: Double,
        sideLength: Double
    ) -> Double {
        guard !areas.isEmpty, sideLength > 0, totalArea > 0 else { return .infinity }
        let s2 = sideLength * sideLength
        var worst: Double = 0
        for area in areas {
            let ratio1 = (s2 * area) / (totalArea * totalArea)
            let ratio2 = (totalArea * totalArea) / (s2 * area)
            worst = max(worst, max(ratio1, ratio2))
        }
        return worst
    }
}
