import SwiftUI
import MacCleanKit

struct DuplicatesView: View {
    @Environment(AppState.self) private var appState
    @State private var results: [ScanResult] = []

    @State private var displayGroups: [DuplicateDisplayGroup] = []

    @State private var expandedGroups: Set<UUID> = []
    @State private var selectedItems: Set<URL> = []
    @State private var isScanning = false
    @State private var scanProgress: Double = 0
    @State private var scanPhase = ""
    @State private var scanComplete = false
    @State private var completion: CleanSummary?
    @State private var cleaning: CleaningEngine.Progress?
    @State private var cleanTask: Task<Void, Never>?

    @State private var scanTask: Task<Void, Never>?
    @State private var scanTimerTask: Task<Void, Never>?
    @State private var elapsedSeconds: Int = 0

    @State private var actionMode: DuplicatesActionMode = .remove
    @State private var consolidateConfirm = false
    @State private var consolidateTask: Task<Void, Never>?

    @State private var consolidateEstimate: UInt64 = 0

    var body: some View {
        Group {
            if isScanning {
                scanningView
            } else if scanComplete && results.isEmpty {
                ModuleContainerView(
                    title: String(localized: "Duplicates"),
                    subtitle: "",
                    theme: .files,
                    emptyMessage: String(localized: "No duplicates found"),
                    results: results,
                    selectedItems: $selectedItems,
                    isScanning: false,
                    scanComplete: true,
                    completion: nil,
                    cleaning: cleaning,
                    onScan: scan, onClean: clean,
                    onCancelClean: { cleanTask?.cancel() },
                    onReset: reset
                )
            } else if !results.isEmpty {
                ModuleContainerView(
                    title: String(localized: "Duplicates"),
                    subtitle: "",
                    theme: .files,
                    results: results,
                    selectedItems: $selectedItems,
                    isScanning: false,
                    completion: completion,
                    cleaning: cleaning,
                    onScan: scan,
                    onClean: {
                        if actionMode == .consolidate {

                            consolidateEstimate = DuplicatesConsolidation.estimatedReclaim(
                                from: displayGroups, selection: selectedItems)
                            consolidateConfirm = true
                        } else {
                            clean()
                        }
                    },
                    onCancelClean: { cleanTask?.cancel() },
                    onReset: reset,
                    resultsContent: {
                        AnyView(
                            VStack(spacing: 12) {
                                Picker("", selection: $actionMode) {
                                    Text("Remove duplicates")
                                        .tag(DuplicatesActionMode.remove)
                                    Text("Consolidate")
                                        .tag(DuplicatesActionMode.consolidate)
                                }
                                .pickerStyle(.segmented)
                                .labelsHidden()
                                .padding(.horizontal, 20)

                                Text(actionMode == .consolidate
                                    ? String(localized: "Selected copies stay in place as clones. Only the wasted duplicate space is freed, nothing is deleted.")
                                    : String(localized: "Selected copies are moved to the Trash, one original is kept per group."))
                                    .font(.system(size: 12))
                                    .foregroundStyle(.primary.opacity(0.6))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 20)

                                DuplicateGroupsList(
                                    groups: displayGroups,
                                    selectedItems: $selectedItems,
                                    expanded: $expandedGroups
                                )
                            }
                        )
                    },
                    actionLabel: actionMode == .consolidate
                        ? String(localized: "Consolidate")
                        : nil
                )
            } else if completion != nil {
                ModuleContainerView(
                    title: String(localized: "Duplicates"),
                    subtitle: "",
                    theme: .files,
                    results: [],
                    selectedItems: $selectedItems,
                    isScanning: false,
                    completion: completion,
                    cleaning: cleaning,
                    onScan: scan, onClean: clean,
                    onCancelClean: { cleanTask?.cancel() },
                    onReset: reset
                )
            } else {
                idleView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)

        .respondsToModuleShortcuts(
            onScan: scan,
            canScan: !isScanning && cleaning == nil && completion == nil && results.isEmpty && !scanComplete,
            canClean: false
        )
        .confirmationDialog(
            String(localized: "Consolidate selected copies?"),
            isPresented: $consolidateConfirm, titleVisibility: .visible
        ) {
            Button("Consolidate") { consolidate() }
            Button("Cancel", role: .cancel) {}
        } message: {

            Text("Keeps every copy, frees about \(FileSizeFormatter.format(consolidateEstimate))")
        }
    }

    private var idleView: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 10) {
                Text("Duplicates")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(.primary)
                Text("Find duplicate files using progressive\nSHA-256 hash detection")
                    .font(.system(size: 14))
                    .foregroundStyle(.primary.opacity(0.65))
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 10) {
                Image(systemName: "clock.fill")
                    .foregroundStyle(.yellow)
                    .font(.system(size: 13))
                Text("This scan may take several minutes on large home folders")
                    .font(.system(size: 12))
                    .foregroundStyle(.primary.opacity(0.8))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.primary.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 10))

            ScanButton(title: String(localized: "Scan"), subtitle: String(localized: "Duplicates"), theme: .files, action: scan)

            Spacer()
        }
    }

    private var scanningView: some View {
        VStack(spacing: 24) {
            Spacer()

            ProgressView()
                .controlSize(.large)
                .tint(.primary)
                .scaleEffect(1.4)

            VStack(spacing: 6) {
                Text(scanPhase)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.primary)
                    .contentTransition(.interpolate)
                    .animation(.easeInOut(duration: 0.2), value: scanPhase)

                Text("Elapsed: \(formatElapsed(elapsedSeconds))")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.primary.opacity(0.6))
            }

            Text("Duplicate detection hashes every candidate file with SHA-256.\nLarge home folders can take 5–15 minutes.")
                .font(.system(size: 12))
                .foregroundStyle(.primary.opacity(0.55))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button("Cancel") { cancelScan() }
                .buttonStyle(.bordered)
                .tint(.primary)
                .controlSize(.large)

            Spacer()
        }
    }

    private func formatElapsed(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }

    private func scan() {
        isScanning = true
        scanComplete = false
        scanProgress = 0
        elapsedSeconds = 0
        scanPhase = String(localized: "Scanning home folder...")

        scanTask?.cancel()
        scanTimerTask?.cancel()

        scanTimerTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                if Task.isCancelled { return }
                elapsedSeconds += 1
            }
        }

        scanTask = Task {
            scanPhase = String(localized: "Scanning home folder...")
            try? await Task.sleep(for: .milliseconds(400))
            if Task.isCancelled { return }

            scanPhase = String(localized: "Grouping files by size...")
            try? await Task.sleep(for: .milliseconds(400))
            if Task.isCancelled { return }

            scanPhase = String(localized: "Hashing candidate files in parallel...")

            let module = DuplicatesModule()
            let groups = await module.scanDisplayGroups()
            if Task.isCancelled { return }

            scanPhase = String(localized: "Finalizing...")
            try? await Task.sleep(for: .milliseconds(300))
            if Task.isCancelled { return }

            scanTimerTask?.cancel()
            displayGroups = groups
            expandedGroups = []

            let removable = groups.flatMap(\.duplicates)
            results = removable.isEmpty
                ? []
                : [ScanResult(category: .duplicates, items: removable, autoSelect: false)]

            selectedItems = Set(removable.map(\.url))
            isScanning = false
            scanComplete = true
            scanTask = nil
            scanTimerTask = nil
        }
    }

    private func cancelScan() {
        scanTask?.cancel()
        scanTimerTask?.cancel()
        scanTask = nil
        scanTimerTask = nil
        isScanning = false
        scanComplete = false
        scanProgress = 0
        elapsedSeconds = 0
        scanPhase = ""
    }

    private func clean() {
        let preCleanSelectedCount = selectedItems.count
        cleaning = CleaningEngine.Progress(
            totalItems: preCleanSelectedCount,
            processedItems: 0, removedSoFar: 0, freedBytesSoFar: 0
        )
        cleanTask = Task {
            let result = await CleanActions.executeUserClean(
                results: results,
                selectedItems: selectedItems,
                engine: appState.cleaningEngine,
                onProgress: { progress in
                    Task { @MainActor in cleaning = progress }
                }
            )
            cleaning = nil
            completion = CleanSummary(
                selectedCount: preCleanSelectedCount,
                removedCount: result.removedCount,
                freedBytes: result.freedBytes,
                errorMessages: result.errors.map(\.error)
            )
        }
    }

    private func consolidate() {
        let groups = DuplicatesConsolidation.groups(from: displayGroups, selection: selectedItems)
        let planned = groups.reduce(0) { $0 + $1.copies.count }
        cleaning = CleaningEngine.Progress(
            totalItems: planned,
            processedItems: 0, removedSoFar: 0, freedBytesSoFar: 0
        )
        consolidateTask?.cancel()
        consolidateTask = Task {
            let summary = await Task.detached { FileConsolidator.consolidate(groups: groups) }.value
            cleaning = nil
            completion = CleanSummary(
                selectedCount: summary.consolidatedCount + summary.skipped.count + summary.failed.count,
                removedCount: summary.consolidatedCount,
                freedBytes: summary.reclaimedBytes,
                errorMessages: summary.failed.map(\.message)
                    + summary.skipped.map { "\($0.url.lastPathComponent): \(skipLabel($0.reason))" }
            )
        }
    }

    private func skipLabel(_ reason: SkipReason) -> String {
        switch reason {
        case .contentChanged: String(localized: "content changed")
        case .notSameVolume: String(localized: "different volume")
        case .cloningUnsupported: String(localized: "not an APFS volume")
        case .notRegularFile: String(localized: "not a regular file")
        case .notWritable: String(localized: "not writable")
        case .protectedPath: String(localized: "protected path")
        }
    }

    private func reset() {
        scanTask?.cancel()
        scanTimerTask?.cancel()
        scanTask = nil
        scanTimerTask = nil
        consolidateTask?.cancel()
        consolidateTask = nil
        consolidateEstimate = 0
        actionMode = .remove
        results = []; displayGroups = []; expandedGroups = []; selectedItems = []
        completion = nil; cleaning = nil; cleanTask = nil
        scanComplete = false; elapsedSeconds = 0; isScanning = false
    }
}
