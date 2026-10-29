import Foundation
import Observation
import MacCleanKit

@MainActor @Observable
final class ReviewController {
    private(set) var selection: ReviewSelection?

    func prepare(results: [ScanResult], moduleName: String, selectedItems: Set<URL>) async {
        selection = nil
        guard let category = results.first?.category else { return }
        let moduleID: String = switch category {
        case .mailAttachments: "mail_attachments"
        case .trashBins: "trash_bins"
        case .malware: "malware"
        case .browserPrivacy: "privacy"
        default: "module"
        }
        let data = await ReviewService.build(modules: [ModuleScanResult(
            moduleID: moduleID, moduleName: moduleName, categories: results, scanDuration: 0
        )])
        guard !Task.isCancelled else { return }
        let review = ReviewSelection(data: data)
        review.applySelectedURLs(selectedItems)
        selection = review
    }
}
