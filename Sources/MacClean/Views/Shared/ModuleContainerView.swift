import SwiftUI
import AppKit
import MacCleanKit

struct ModuleContainerView: View {
    @AppStorage("removeBackgroundColors") private var removeBackgroundColors = false
    let title: String
    let subtitle: String
    let theme: ModuleTheme
    let emptyMessage: String
    let results: [ScanResult]
    @Binding var selectedItems: Set<URL>
    let isScanning: Bool
    let scanProgress: Double
    let scanPhase: String
    let scanComplete: Bool

    let completion: CleanSummary?

    let cleaning: CleaningEngine.Progress?

    let permissionDenied: Bool
    let onScan: () -> Void
    let onClean: () -> Void
    let onCancelClean: (() -> Void)?
    let onReset: () -> Void

    let onGrantAccess: (() -> Void)?

    let confirmEmptyTrash: Bool

    let resultsContent: (() -> AnyView)?

    let actionLabel: String?

    init(
        title: String,
        subtitle: String,
        theme: ModuleTheme,
        emptyMessage: String = String(localized: "No items found"),
        results: [ScanResult],
        selectedItems: Binding<Set<URL>>,
        isScanning: Bool,
        scanProgress: Double = 0.5,
        scanPhase: String = String(localized: "Scanning..."),
        scanComplete: Bool = false,
        completion: CleanSummary? = nil,
        cleaning: CleaningEngine.Progress? = nil,
        permissionDenied: Bool = false,
        onScan: @escaping () -> Void,
        onClean: @escaping () -> Void,
        onCancelClean: (() -> Void)? = nil,
        onReset: @escaping () -> Void,
        onGrantAccess: (() -> Void)? = nil,
        confirmEmptyTrash: Bool = false,
        resultsContent: (() -> AnyView)? = nil,
        actionLabel: String? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.theme = theme
        self.emptyMessage = emptyMessage
        self.results = results
        self._selectedItems = selectedItems
        self.isScanning = isScanning
        self.scanProgress = scanProgress
        self.scanPhase = scanPhase
        self.scanComplete = scanComplete
        self.completion = completion
        self.cleaning = cleaning
        self.permissionDenied = permissionDenied
        self.onScan = onScan
        self.onClean = onClean
        self.onCancelClean = onCancelClean
        self.onReset = onReset
        self.onGrantAccess = onGrantAccess
        self.confirmEmptyTrash = confirmEmptyTrash
        self.resultsContent = resultsContent
        self.actionLabel = actionLabel
    }

    @State private var showLargeSelectionConfirm = false
    @State private var showEmptyTrashConfirm = false
    @State private var showActivityLog = false
    @State private var review: ReviewSelection?

    private var totalSelected: UInt64 {
        if resultsContent == nil, let review {
            return review.selectedSize
        }
        return results.selectedSize(selectedItems)
    }

    private var selectedCount: Int {
        if resultsContent == nil, let review {
            return review.selectedCount
        }
        return selectedItems.count
    }

    private var formattedSelectedSize: String {
        ByteCountFormatter.string(fromByteCount: Int64(totalSelected), countStyle: .file)
    }

    private var resultsKey: String {
        fileListResultsSignature(sort: .sizeDescending, results: results)
    }

    private var inferredModuleID: String {
        guard let first = results.first?.category else { return "module" }
        switch first {
        case .mailAttachments: return "mail_attachments"
        case .trashBins: return "trash_bins"
        case .malware: return "malware"
        case .browserPrivacy: return "privacy"
        default: return "module"
        }
    }

    var body: some View {
        Group {
            if let completion {
                doneView(summary: completion)
            } else if let cleaning {
                cleaningView(progress: cleaning)
            } else if isScanning {
                scanningView
            } else if !results.isEmpty {
                resultsView
            } else if scanComplete {
                if permissionDenied {
                    permissionDeniedView
                } else {
                    emptyResultsView
                }
            } else {
                idleView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .respondsToModuleShortcuts(
            onScan: onScan,
            onClean: onClean,
            canScan: cleaning == nil && !isScanning && completion == nil,
            canClean: cleaning == nil && completion == nil && !results.isEmpty && selectedCount > 0
        )
    }

    @ViewBuilder
    private func cleanErrorDetail(for summary: CleanSummary) -> some View {
        if summary.errorCount == 1, let msg = summary.firstErrorMessage {
            Text(msg)
                .font(.system(size: 13))
                .foregroundStyle(.primary.opacity(0.75))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .textSelection(.enabled)
        } else if !summary.topErrorGroups.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(summary.topErrorGroups, id: \.message) { group in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("\(group.count.formatted())×")
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.primary.opacity(0.6))
                            .frame(minWidth: 50, alignment: .trailing)
                        Text(group.message)
                            .font(.system(size: 12))
                            .foregroundStyle(.primary.opacity(0.8))
                            .lineLimit(2)
                            .textSelection(.enabled)
                    }
                }
                if summary.errorCount > summary.topErrorGroups.reduce(0, { $0 + $1.count }) {
                    let shownTotal = summary.topErrorGroups.reduce(0) { $0 + $1.count }
                    Text("…and \((summary.errorCount - shownTotal).formatted()) more")
                        .font(.system(size: 11))
                        .foregroundStyle(.primary.opacity(0.5))
                        .padding(.top, 2)
                }
                Text("Full log: ~/Library/Logs/MacClean/operations.log")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.primary.opacity(0.45))
                    .padding(.top, 4)
                    .textSelection(.enabled)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(.primary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal, 24)
        }
    }

    private func cleaningView(progress: CleaningEngine.Progress) -> some View {
        VStack(spacing: 24) {
            Spacer()
            ScanProgressRing(
                progress: progress.fraction,
                phase: progress.totalItems > 0
                    ? "Cleaning… \(Int((progress.fraction * 100).rounded()))%"
                    : String(localized: "Starting cleanup..."),
                theme: theme
            )
            if progress.totalItems > 0 {
                Text("\(progress.processedItems.formatted()) of \(progress.totalItems.formatted()) items")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.primary.opacity(0.65))
            }
            if let onCancelClean {
                Button(String(localized: "Cancel")) { onCancelClean() }
                    .buttonStyle(.bordered)
                    .tint(.primary)
                    .controlSize(.large)
            }
            Spacer()
        }
    }

    private var idleView: some View {
        VStack(spacing: 28) {
            Spacer()
            VStack(spacing: 10) {
                Text(title)
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.system(size: 13.5))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 400)
            }
            ScanButton(title: String(localized: "Scan"), subtitle: title, theme: theme, action: onScan)
            Spacer()
        }
    }

    private var scanningView: some View {
        VStack(spacing: 0) {
            Spacer()
            ScanProgressRing(progress: scanProgress, phase: scanPhase, theme: theme)
            Spacer()
        }
    }

    private var emptyResultsView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 52))
                .foregroundStyle(.primary.opacity(0.9))
            Text(emptyMessage)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.primary)
            Text("Scan complete — nothing to clean up")
                .font(.system(size: 13))
                .foregroundStyle(.primary.opacity(0.55))
            Button(String(localized: "Done")) { onReset() }
                .buttonStyle(.bordered)
                .tint(.primary)
                .controlSize(.large)
            Spacer()
        }
    }

    private var permissionDeniedView: some View {
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: "lock.fill")
                .font(.system(size: 52))
                .foregroundStyle(.primary.opacity(0.9))
            Text("Full Disk Access needed")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.primary)
            Text("macOS is blocking access to this location. Grant \(MCConstants.appName) Full Disk Access, then scan again.")
                .font(.system(size: 13))
                .foregroundStyle(.primary.opacity(0.7))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
            HStack(spacing: 10) {
                if let onGrantAccess {
                    Button(String(localized: "Open Settings")) { onGrantAccess() }
                        .buttonStyle(.borderedProminent)
                        .tint(.primary)
                        .controlSize(.large)
                }
                Button(String(localized: "Rescan")) { onScan() }
                    .buttonStyle(.bordered)
                    .tint(.primary)
                    .controlSize(.large)
                Button(String(localized: "Done")) { onReset() }
                    .buttonStyle(.bordered)
                    .tint(.primary)
                    .controlSize(.large)
            }
            Spacer()
        }
    }

    @ViewBuilder
    private var resultsView: some View {
        if let resultsContent {
            VStack(spacing: 0) {
                HStack {
                    SizeDisplay(size: totalSelected, label: String(localized: "Selected"))
                        .foregroundStyle(.primary)
                    Spacer()
                    Button(actionLabel ?? String(localized: "Clean")) {
                        requestClean()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color(nsColor: .systemBlue))
                    .controlSize(.large)
                    .disabled(selectedCount == 0)
                    .opacity(selectedCount == 0 ? 0.5 : 1.0)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 14)

                resultsContent()
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1)
                    )
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
            }
            .modifier(cleanConfirmationAlerts)
        } else {
            Group {
                if let review {
                    ReviewBrowserView(
                        data: review.data,
                        selection: review,
                        doneTitle: actionLabel ?? String(localized: "Clean"),
                        doneDisabled: review.selectedCount == 0,
                        onDone: requestClean
                    )
                    .onChange(of: review.revision) { _, _ in
                        selectedItems = review.data.selectedURLs(flags: review.snapshot())
                    }
                } else {
                    VStack {
                        Spacer()
                        ProgressView().controlSize(.regular)
                        Spacer()
                    }
                }
            }
            .task(id: resultsKey) {
                await buildReviewSelection()
            }
            .modifier(cleanConfirmationAlerts)
        }
    }

    private func requestClean() {
        if resultsContent == nil, let review {
            selectedItems = review.data.selectedURLs(flags: review.snapshot())
        }
        if confirmEmptyTrash {
            showEmptyTrashConfirm = true
        } else if selectedCount > MCConstants.cleanConfirmationThreshold {
            showLargeSelectionConfirm = true
        } else {
            onClean()
        }
    }

    private func buildReviewSelection() async {
        let currentResults = results
        guard !currentResults.isEmpty else {
            review = nil
            return
        }
        let moduleID = inferredModuleID
        let moduleName = title
        let running = Set(NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier))
        let data = await Task.detached(priority: .userInitiated) {
            ReviewDataBuilder.build(
                modules: [ModuleScanResult(
                    moduleID: moduleID,
                    moduleName: moduleName,
                    categories: currentResults,
                    scanDuration: 0
                )],
                runningBundleIDs: running
            )
        }.value
        if Task.isCancelled { return }
        let newReview = ReviewSelection(data: data)
        if !selectedItems.isEmpty {
            newReview.applySelectedURLs(selectedItems)
        } else {
            selectedItems = data.selectedURLs(flags: newReview.snapshot())
        }
        review = newReview
    }

    private var cleanConfirmationAlerts: some ViewModifier {
        CleanConfirmationModifier(
            showLargeSelectionConfirm: $showLargeSelectionConfirm,
            showEmptyTrashConfirm: $showEmptyTrashConfirm,
            selectedCount: selectedCount,
            formattedSelectedSize: formattedSelectedSize,
            onClean: {
                if resultsContent == nil, let review {
                    selectedItems = review.data.selectedURLs(flags: review.snapshot())
                }
                onClean()
            }
        )
    }

    private func doneView(summary: CleanSummary) -> some View {
        FitOrScroll { doneContent(summary: summary) }
    }

    private func doneContent(summary: CleanSummary) -> some View {
        VStack(spacing: 20) {
            Spacer()

            if summary.selectedCount == 0 {
                Image(systemName: "checklist.unchecked")
                    .font(.system(size: 52))
                    .foregroundStyle(.primary.opacity(0.85))
                Text("Nothing was selected")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.primary)
                Text("Re-run the scan, check the items you want to remove, then click Clean.")
                    .font(.system(size: 13))
                    .foregroundStyle(.primary.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            } else if summary.removedCount == 0 {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(.orange.opacity(0.85))
                Text("\(summary.selectedCount) item\(summary.selectedCount == 1 ? "" : "s") couldn't be cleaned")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.primary)

                cleanErrorDetail(for: summary)
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(.primary)
                SizeDisplay(size: summary.freedBytes, label: String(localized: "cleaned up"))
                    .foregroundStyle(.primary)
                if summary.removedCount < summary.selectedCount {
                    Text("\(summary.removedCount) of \(summary.selectedCount) items removed" +
                         (summary.errorCount > 0 ? " — \(summary.errorCount) error\(summary.errorCount == 1 ? "" : "s")" : ""))
                        .font(.system(size: 12))
                        .foregroundStyle(.primary.opacity(0.65))
                }
                if SupportAskLedger.shared.shouldAsk(for: summary) {
                    SupportCard()
                        .padding(.horizontal, 40)
                }
            }

            HStack(spacing: 10) {
                if summary.errorCount > 0 {
                    Button {
                        showActivityLog = true
                    } label: {
                        Label(String(localized: "View Log"), systemImage: "doc.text.magnifyingglass")
                    }
                    .buttonStyle(.bordered)
                    .tint(.primary)
                    .controlSize(.large)
                    .help(String(localized: "Open the activity log to see every error and copy details for a bug report"))
                }
                Button(String(localized: "Done")) { onReset() }
                    .buttonStyle(.bordered)
                    .tint(.primary)
                    .controlSize(.large)
            }
            Spacer()
        }
        .sheet(isPresented: $showActivityLog) { LogViewerView() }
    }
}

private struct CleanConfirmationModifier: ViewModifier {
    @Binding var showLargeSelectionConfirm: Bool
    @Binding var showEmptyTrashConfirm: Bool
    let selectedCount: Int
    let formattedSelectedSize: String
    let onClean: () -> Void

    func body(content: Content) -> some View {
        content
            .alert(
                "Clean \(selectedCount.formatted()) items?",
                isPresented: $showLargeSelectionConfirm
            ) {
                Button(String(localized: "Cancel"), role: .cancel) { }
                Button(String(localized: "Continue"), role: .destructive) { onClean() }
            } message: {
                Text("That's about \(formattedSelectedSize) of data and may take several minutes. You can cancel mid-cleanup.")
            }
            .alert(
                String(localized: "Empty the Trash?"),
                isPresented: $showEmptyTrashConfirm
            ) {
                Button(String(localized: "Cancel"), role: .cancel) { }
                Button(String(localized: "Empty Trash"), role: .destructive) { onClean() }
            } message: {
                Text("This permanently deletes \(selectedCount.formatted()) item\(selectedCount == 1 ? "" : "s") (\(formattedSelectedSize)) and cannot be undone.")
            }
    }
}
