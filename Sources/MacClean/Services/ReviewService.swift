import AppKit
import Foundation
import MacCleanKit

@MainActor
enum ReviewService {
    static func build(
        modules: [ModuleScanResult],
        includeEmptySystemJunkCategories: Bool = false
    ) async -> ReviewData {
        let running = Set(NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier))
        return await Task.detached(priority: .userInitiated) {
            ReviewDataBuilder.build(
                modules: modules,
                runningBundleIDs: running,
                includeEmptySystemJunkCategories: includeEmptySystemJunkCategories
            )
        }.value
    }
}
