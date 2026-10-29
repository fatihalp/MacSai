import SwiftUI
import MacCleanKit

struct ScanModuleView: View {
    @Environment(AppState.self) private var appState
    let feature: ScanFeature

    private var theme: ModuleTheme {
        switch feature {
        case .mailAttachments, .trashBins: .cleanup
        case .malware, .privacy: .protection
        case .largeOldFiles: .files
        }
    }

    private var subtitle: String {
        switch feature {
        case .mailAttachments: String(localized: "Find cached email attachments from Mail, Outlook, and Spark")
        case .trashBins: String(localized: "Empty all trash locations including external drives")
        case .malware: String(localized: "Scan for viruses, adware, and other threats")
        case .privacy: String(localized: "Clean browser data, history, cookies, and system traces")
        case .largeOldFiles: String(localized: "Find files larger than 50 MB that haven't been accessed recently")
        }
    }

    private var emptyMessage: String {
        switch feature {
        case .mailAttachments: String(localized: "No attachments found")
        case .trashBins: String(localized: "Trash is empty")
        case .malware: String(localized: "No threats detected")
        case .privacy: String(localized: "No privacy traces found")
        case .largeOldFiles: String(localized: "No large or old files found")
        }
    }

    var body: some View {
        @Bindable var controller = appState.scanController(for: feature)
        ModuleContainerView(
            title: String(localized: feature.item.title),
            subtitle: subtitle,
            theme: theme,
            emptyMessage: emptyMessage,
            results: controller.results,
            selectedItems: $controller.selectedItems,
            isScanning: controller.isScanning,
            scanPhase: String(localized: "Scanning..."),
            scanComplete: controller.scanComplete,
            completion: controller.completion,
            cleaning: controller.cleaning,
            permissionDenied: controller.permissionDenied,
            onScan: controller.scan,
            onClean: { controller.clean(engine: appState.cleaningEngine) },
            onCancelClean: controller.cancelCleaning,
            onReset: controller.reset,
            onGrantAccess: { PermissionManager.shared.openFullDiskAccessSettings() },
            confirmEmptyTrash: feature == .trashBins
        )
    }
}
