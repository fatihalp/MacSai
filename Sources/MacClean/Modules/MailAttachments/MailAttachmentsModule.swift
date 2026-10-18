import Foundation
import MacCleanKit

public struct MailAttachmentsModule: ScanModule {
    public let id = "mail_attachments"
    public var name: String { String(localized: "Mail Attachments") }
    public let category = ModuleCategory.cleanup

    private let scanner = TargetedScanner()

    public init() {}

    public func scan() async -> [ScanResult] {
        let targets = [

            ScanTarget(
                path: MCConstants.mailDownloads,
                recursive: true
            ),

            ScanTarget(
                path: MCConstants.mailContainerDownloads,
                recursive: true
            ),

            ScanTarget(
                path: MCConstants.mailData,
                recursive: true,
                maxDepth: 6,
                fileExtensions: [
                    "jpg", "jpeg", "png", "gif", "bmp", "tiff", "heic", "webp",
                    "pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx",
                    "zip", "gz", "tar", "rar", "7z",
                    "csv", "txt", "rtf",
                ]
            ),

            ScanTarget(
                path: MCConstants.userContainers
                    .appending(path: "com.microsoft.Outlook/Data/Library/Caches"),
                recursive: true
            ),

            ScanTarget(
                path: MCConstants.userContainers
                    .appending(path: "com.readdle.smartemail/Data/Library/Caches"),
                recursive: true
            ),
        ]

        let items = await scanner.scan(targets: targets)
        guard !items.isEmpty else { return [] }

        return [ScanResult(category: .mailAttachments, items: items)]
            .filteringUncleanable()
    }
}
