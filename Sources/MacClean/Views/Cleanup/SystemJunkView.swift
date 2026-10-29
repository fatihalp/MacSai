import SwiftUI
import MacCleanKit

struct SystemJunkView: View {
    @Environment(AppState.self) private var appState
    @AppStorage("removeBackgroundColors") private var removeBackgroundColors = false
    private var controller: SystemJunkController { appState.systemJunkController }
    @State private var showLargeSelectionConfirm = false
    @State private var showActivityLog = false

    var body: some View {
        Group {
            switch controller.state {
            case .idle:
                idleView
            case .scanning(let progress):
                scanningView(progress: progress)
            case .results:
                resultsView
            case .empty:
                emptyView
            case .cleaning(let progress):
                cleaningView(progress: progress)
            case .done(let summary):
                doneView(summary: summary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .respondsToModuleShortcuts(
            onScan: { controller.startScan() },
            onClean: requestClean,
            canScan: {
                switch controller.state {
                case .idle, .empty, .done, .results: true
                case .scanning, .cleaning: false
                }
            }(),
            canClean: {
                if case .results = controller.state { return controller.selectedCount > 0 }
                return false
            }()
        )
    }

    private var idleView: some View {
        VStack(spacing: 24) {
            Spacer()

            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(ModuleTheme.cleanup.accentColor)
                .frame(width: 60, height: 60)
                .overlay(
                    Image(systemName: "trash.fill")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(.white)
                )

            VStack(spacing: 8) {
                Text("System Junk")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.primary)

                Text("Find and remove system caches, logs,\nlanguage files, and other junk")
                    .font(.system(size: 13.5))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            ScanButton(
                title: "Scan",
                subtitle: "System Junk",
                theme: .cleanup
            ) {
                controller.startScan()
            }

            Spacer()
        }
    }

    private func scanningView(progress: Double) -> some View {
        VStack(spacing: 0) {
            Spacer()

            ScanProgressRing(
                progress: progress,
                phase: controller.scanPhase,
                detail: "\(controller.filesFound) files found",
                theme: .cleanup
            )

            Spacer()
        }
    }

    @ViewBuilder
    private var resultsView: some View {
        if let review = controller.review {
            ReviewBrowserView(
                data: review.data,
                selection: review,
                doneTitle: String(localized: "Clean"),
                doneDisabled: controller.selectedCount == 0,
                onDone: requestClean
            )
            .alert(
                "Clean \(controller.selectedCount.formatted()) items?",
                isPresented: $showLargeSelectionConfirm
            ) {
                Button("Cancel", role: .cancel) { }
                Button("Continue", role: .destructive) {
                    controller.startCleaning(engine: appState.cleaningEngine)
                }
            } message: {
                Text("That's about \(ByteCountFormatter.string(fromByteCount: Int64(controller.currentSelectedSize), countStyle: .file)) of data and may take several minutes. You can cancel mid-cleanup.")
            }
        }
    }

    private var emptyView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 52))
                .foregroundStyle(.primary.opacity(0.9))
            Text("No junk found")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.primary)
            Text("Your Mac is clean!")
                .font(.system(size: 13))
                .foregroundStyle(.primary.opacity(0.55))
            Button("Done") { controller.reset() }
                .buttonStyle(.bordered)
                .tint(.primary)
                .controlSize(.large)
            Spacer()
        }
    }

    private func cleaningView(progress: CleaningEngine.Progress?) -> some View {
        VStack(spacing: 24) {
            Spacer()

            ScanProgressRing(
                progress: progress?.fraction ?? 0.0,
                phase: cleaningPhaseText(progress),
                theme: .cleanup
            )

            if let progress {
                Text("\(progress.processedItems.formatted()) of \(progress.totalItems.formatted()) items")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.primary.opacity(0.65))
            }

            Button("Cancel") { controller.cancelCleaning() }
                .buttonStyle(.bordered)
                .tint(.primary)
                .controlSize(.large)

            Spacer()
        }
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
                let shownTotal = summary.topErrorGroups.reduce(0) { $0 + $1.count }
                if summary.errorCount > shownTotal {
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

    private func cleaningPhaseText(_ progress: CleaningEngine.Progress?) -> String {
        guard let progress, progress.totalItems > 0 else {
            return String(localized: "Starting cleanup...")
        }
        let pct = Int((progress.fraction * 100).rounded())
        return "Cleaning… \(pct)%"
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
                        Label("View Log", systemImage: "doc.text.magnifyingglass")
                    }
                    .buttonStyle(.bordered)
                    .tint(.primary)
                    .controlSize(.large)
                    .help("Open the activity log to see every error and copy details for a bug report")
                }
                Button("Done") { controller.reset() }
                    .buttonStyle(.bordered)
                    .tint(.primary)
                    .controlSize(.large)
            }
            Spacer()
        }
        .sheet(isPresented: $showActivityLog) { LogViewerView() }
    }
    private func requestClean() {
        guard controller.selectedCount > 0 else { return }
        if controller.selectedCount > MCConstants.cleanConfirmationThreshold {
            showLargeSelectionConfirm = true
        } else {
            controller.startCleaning(engine: appState.cleaningEngine)
        }
    }

}
