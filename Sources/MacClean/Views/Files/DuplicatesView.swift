import SwiftUI
import MacCleanKit

struct DuplicatesView: View {
    @Bindable var controller: DuplicatesController

    @State private var expandedGroups: Set<UUID> = []

    @State private var actionMode: DuplicatesActionMode = .remove
    @State private var consolidateConfirm = false

    @State private var consolidateEstimate: UInt64 = 0

    var body: some View {
        Group {
            if controller.isScanning {
                scanningView
            } else if controller.scanComplete && controller.results.isEmpty {
                ModuleContainerView(
                    title: String(localized: "Duplicates"),
                    subtitle: "",
                    theme: .files,
                    emptyMessage: String(localized: "No duplicates found"),
                    results: controller.results,
                    selectedItems: $controller.selectedItems,
                    isScanning: false,
                    scanComplete: true,
                    completion: nil,
                    cleaning: controller.cleaning,
                    onScan: controller.scan, onClean: controller.clean,
                    onCancelClean: { controller.cancelCleaning() },
                    onReset: reset
                )
            } else if !controller.results.isEmpty {
                ModuleContainerView(
                    title: String(localized: "Duplicates"),
                    subtitle: "",
                    theme: .files,
                    results: controller.results,
                    selectedItems: $controller.selectedItems,
                    isScanning: false,
                    completion: controller.completion,
                    cleaning: controller.cleaning,
                    onScan: controller.scan,
                    onClean: {
                        if actionMode == .consolidate {

                            consolidateEstimate = DuplicatesConsolidation.estimatedReclaim(
                                from: controller.displayGroups, selection: controller.selectedItems)
                            consolidateConfirm = true
                        } else {
                            controller.clean()
                        }
                    },
                    onCancelClean: { controller.cancelCleaning() },
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
                                    groups: controller.displayGroups,
                                    selectedItems: $controller.selectedItems,
                                    expanded: $expandedGroups
                                )
                            }
                        )
                    },
                    actionLabel: actionMode == .consolidate
                        ? String(localized: "Consolidate")
                        : nil
                )
            } else if controller.completion != nil {
                ModuleContainerView(
                    title: String(localized: "Duplicates"),
                    subtitle: "",
                    theme: .files,
                    results: [],
                    selectedItems: $controller.selectedItems,
                    isScanning: false,
                    completion: controller.completion,
                    cleaning: controller.cleaning,
                    onScan: controller.scan, onClean: controller.clean,
                    onCancelClean: { controller.cancelCleaning() },
                    onReset: reset
                )
            } else {
                idleView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)

        .respondsToModuleShortcuts(
            onScan: controller.scan,
            canScan: !controller.isScanning && controller.cleaning == nil && controller.completion == nil && controller.results.isEmpty && !controller.scanComplete,
            canClean: false
        )
        .confirmationDialog(
            String(localized: "Consolidate selected copies?"),
            isPresented: $consolidateConfirm, titleVisibility: .visible
        ) {
            Button("Consolidate") { controller.consolidate() }
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

            ScanButton(title: "Scan", subtitle: "Duplicates", theme: .files, action: controller.scan)

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
                Text(controller.scanPhase)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.primary)
                    .contentTransition(.interpolate)
                    .animation(.easeInOut(duration: 0.2), value: controller.scanPhase)

                Text("Elapsed: \(formatElapsed(controller.elapsedSeconds))")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.primary.opacity(0.6))
            }

            Text("Duplicate detection hashes every candidate file with SHA-256.\nLarge home folders can take 5–15 minutes.")
                .font(.system(size: 12))
                .foregroundStyle(.primary.opacity(0.55))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button("Cancel") { controller.cancelScan() }
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

    private func reset() {
        expandedGroups = []
        consolidateEstimate = 0
        actionMode = .remove
        controller.reset()
    }
}
