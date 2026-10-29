import Foundation
import MacCleanKit

enum ScanFeature: CaseIterable {
    case mailAttachments, trashBins, malware, privacy, largeOldFiles

    var module: any ScanModule {
        switch self {
        case .mailAttachments: MailAttachmentsModule()
        case .trashBins: TrashBinsModule()
        case .malware: MalwareModule()
        case .privacy: PrivacyModule()
        case .largeOldFiles: LargeOldFilesModule()
        }
    }

    var item: SidebarItem {
        switch self {
        case .mailAttachments: .mailAttachments
        case .trashBins: .trashBins
        case .malware: .malwareRemoval
        case .privacy: .privacy
        case .largeOldFiles: .largeOldFiles
        }
    }

    var selectAll: Bool { self == .malware || self == .privacy }
}
