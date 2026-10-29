import SwiftUI
import AppKit
import MacCleanKit

struct SmartScanView: View {
    private var controller: SmartScanController { appState.smartScanController }
    @Environment(AppState.self) private var appState
    @State private var showCleanConfirm = false

    var body: some View {
        Group {
            switch controller.scanState {
            case .idle:
                idleView
            case .scanning(let phase, let progress, let filesFound, let sizeFound):
                scanningView(phase: phase, progress: progress, filesFound: filesFound, sizeFound: sizeFound)
            case .results(_, _, _, let totalSize, _):
                resultsView(totalSize: totalSize)
            case .empty:
                emptyView
            case .cleaning(let progress):
                cleaningView(progress: progress)
            case .done(let freedSize, let breakdown):
                doneView(freedSize: freedSize, breakdown: breakdown)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .respondsToModuleShortcuts(
            onScan: controller.startScan,
            onClean: { showCleanConfirm = true },
            canScan: {
                switch controller.scanState {
                case .idle, .empty, .done, .results: true
                case .scanning, .cleaning: false
                }
            }(),
            canClean: {
                if case .results = controller.scanState { return (controller.review?.selectedCount ?? 0) > 0 }
                return false
            }()
        )
    }

    private var idleView: some View {
        HomeDashboardView(onStartScan: controller.startScan)
    }

    private func scanningView(phase: String, progress: Double, filesFound: Int, sizeFound: UInt64) -> some View {
        VStack(spacing: 0) {

            HStack(spacing: 24) {
                statBadge(label: String(localized: "Progress"), value: "\(Int(progress * 100))%")
                statBadge(label: String(localized: "Files Found"), value: filesFound.formatted())
                statBadge(label: String(localized: "Size"), value: FileSizeFormatter.format(sizeFound))
            }
            .padding(.horizontal, 30)
            .padding(.top, 16)
            .padding(.bottom, 12)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(.primary.opacity(0.12))
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(.primary)
                        .frame(width: geo.size.width * progress, height: 6)
                        .animation(.easeInOut(duration: 0.3), value: progress)
                }
            }
            .frame(height: 6)
            .padding(.horizontal, 30)
            .padding(.bottom, 16)

            ScrollView {
                VStack(spacing: 2) {
                    ForEach(Array(SmartScanModules.order.enumerated()), id: \.offset) { index, module in
                        moduleRow(module: module, currentPhase: phase)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 20)
            }
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1)
            )
            .padding(.horizontal, 20)

            Button("Cancel") { controller.cancelScan() }
                .buttonStyle(.bordered)
                .tint(.primary)
                .controlSize(.large)
                .padding(.bottom, 20)
        }
    }

    private func moduleRow(module: (id: String, name: String, icon: String, group: String), currentPhase: String) -> some View {
        let isActive = currentPhase == module.name
        let completed = controller.completedModules.contains { $0.name == module.name }
        let completedInfo = controller.completedModules.first { $0.name == module.name }

        return HStack(spacing: 10) {

            ZStack {
                if isActive {
                    ProgressView()
                        .controlSize(.small)
                        .tint(.primary)
                } else if completed {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.green)
                } else {
                    Image(systemName: "circle")
                        .font(.system(size: 16))
                        .foregroundStyle(.primary.opacity(0.2))
                }
            }
            .frame(width: 20)

            Image(systemName: module.icon)
                .font(.system(size: 14))
                .foregroundStyle(isActive ? Color.primary : Color.primary.opacity(completed ? 0.6 : 0.25))
                .frame(width: 20)

            Text(module.name)
                .font(.system(size: 13, weight: isActive ? .semibold : .regular))
                .foregroundStyle(isActive ? Color.primary : Color.primary.opacity(completed ? 0.7 : 0.3))

            Spacer()

            if let info = completedInfo, info.fileCount > 0 {
                Text("\(info.fileCount) items")
                    .font(.system(size: 11))
                    .foregroundStyle(.primary.opacity(0.5))
                Text(FileSizeFormatter.format(info.size))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.primary.opacity(0.6))
            } else if completedInfo != nil {
                Text("Clean")
                    .font(.system(size: 11))
                    .foregroundStyle(.green.opacity(0.7))
            }

            Text(module.group)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.primary.opacity(0.4))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.primary.opacity(0.08))
                .clipShape(Capsule())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isActive ? Color.primary.opacity(0.1) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func statBadge(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .contentTransition(.numericText())
                .animation(.easeInOut(duration: 0.2), value: value)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.primary.opacity(0.5))
                .textCase(.uppercase)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func resultsView(totalSize: UInt64) -> some View {
        let selectedCount = controller.review?.selectedCount ?? 0
        Group {
            if controller.showingReview, let review = controller.review {
                ReviewBrowserView(
                    data: review.data,
                    selection: review,
                    initialSectionID: controller.reviewSectionID,
                    onDone: { controller.showingReview = false },
                    onClean: { showCleanConfirm = true }
                )
            } else {
                resultsSummary(totalSize: totalSize)
            }
        }
        .alert("Clean \(selectedCount) item\(selectedCount == 1 ? "" : "s")?", isPresented: $showCleanConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Clean", role: .destructive) {
                controller.showingReview = false
                controller.runCleanup()
            }
        } message: {
            Text("Selected items will be moved to the Trash so you can recover them if needed.")
        }
    }

    private func resultsSummary(totalSize: UInt64) -> some View {
        let selectedCount = controller.review?.selectedCount ?? 0
        let selectedSize = controller.review?.selectedSize ?? 0
        return VStack(spacing: 20) {
            SizeDisplay(size: totalSize, label: String(localized: "of junk found"))
                .foregroundStyle(.primary)
                .padding(.top, 24)

            HStack(spacing: 24) {
                if case .results(let cleanup, _, _, _, _) = controller.scanState {
                    resultPill(icon: "trash.circle.fill", label: String(localized: "Cleanup"), value: FileSizeFormatter.format(cleanup))
                }
                if case .results(_, let threats, _, _, _) = controller.scanState {
                    resultPill(icon: "shield.lefthalf.filled", label: String(localized: "Protection"), value: "\(threats) threats")
                }
                if case .results(_, _, let perf, _, _) = controller.scanState {
                    resultPill(icon: "gauge.with.dots.needle.67percent", label: String(localized: "Speed"), value: "\(perf) items")
                }
            }

            if let review = controller.review {
                HStack(spacing: 8) {
                    Button("Select All") {
                        review.applyToAll(.all)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Button("Smart") {
                        review.applyToAll(.smart)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Button("Deselect All") {
                        review.applyToAll(.none)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                ScrollView {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 200, maximum: 250), spacing: 14)],
                        spacing: 14
                    ) {
                        ForEach(review.data.sections) { section in
                            sectionCard(section, selection: review)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 4)
                }
                .frame(maxWidth: 820, maxHeight: .infinity)
            } else {
                Spacer()
            }

            HStack(spacing: 14) {
                Text("\(selectedCount.formatted()) items selected · \(FileSizeFormatter.format(selectedSize))")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    controller.reviewSectionID = nil
                    controller.showingReview = true
                } label: {
                    Label("Review Details", systemImage: "list.bullet.rectangle")
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .disabled(controller.review == nil)

                Button { showCleanConfirm = true } label: {
                    Text("Clean · \(FileSizeFormatter.format(selectedSize))")
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(nsColor: .systemBlue))
                .controlSize(.large)
                .disabled(selectedCount == 0)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .padding(.horizontal, 20)
    }

    private func sectionCard(_ section: ReviewSection, selection: ReviewSelection) -> some View {
        let selected = selection.selectedSize(ofSection: section)
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                ReviewCheckbox(state: selection.state(ofSection: section)) {
                    selection.toggleSection(section)
                }
                Image(systemName: ReviewSectionInfo.icon(for: section.id))
                    .font(.system(size: 18))
                    .foregroundStyle(Color(nsColor: .systemBlue))
                Spacer()
                Button {
                    controller.reviewSectionID = section.id
                    controller.showingReview = true
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            Button {
                controller.reviewSectionID = section.id
                controller.showingReview = true
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(section.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(FileSizeFormatter.format(section.size))
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                    Text("\(FileSizeFormatter.format(selected)) selected")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(white: 0.975), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1)
        )
        .help("Review Details")
    }

    private var emptyView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 52))
                .foregroundStyle(.primary.opacity(0.9))
            Text("Your Mac is clean!")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.primary)
            Text("No junk, threats, or performance issues found")
                .font(.system(size: 14))
                .foregroundStyle(.primary.opacity(0.6))
            Button("Done") { controller.resetScan() }
                .buttonStyle(.bordered)
                .tint(.primary)
                .controlSize(.large)
            Spacer()
        }
    }

    private func cleaningView(progress: Double) -> some View {
        VStack(spacing: 20) {
            Spacer()
            ScanProgressRing(progress: progress, phase: String(localized: "Cleaning your Mac..."), theme: .smartScan)

            Button("Cancel") { controller.cancelCleaning() }
                .buttonStyle(.bordered)
                .tint(.primary)
                .controlSize(.large)
            Spacer()
        }
    }

    private func doneView(freedSize: UInt64, breakdown: [SmartScanCleanup.RecentlyCleanedRow]) -> some View {
        FitOrScroll { doneContent(freedSize: freedSize, breakdown: breakdown) }
    }

    private func doneContent(freedSize: UInt64, breakdown: [SmartScanCleanup.RecentlyCleanedRow]) -> some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 52))
                .foregroundStyle(.primary)
            Text("Moved to the Trash")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.primary)
            SizeDisplay(size: freedSize, label: String(localized: "ready to reclaim"))
                .foregroundStyle(.primary)

            if !breakdown.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Recently cleaned")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.primary.opacity(0.55))
                        .textCase(.uppercase)
                    ForEach(breakdown, id: \.moduleID) { row in
                        HStack(spacing: 10) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(.green)
                            Text(row.moduleName)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                            Spacer(minLength: 8)
                            Text(recentlyCleanedDetail(row))
                                .font(.system(size: 13, design: .monospaced))
                                .foregroundStyle(.primary.opacity(0.7))
                                .multilineTextAlignment(.trailing)
                        }
                    }
                }
                .padding(16)
                .frame(maxWidth: 420)
                .background(.primary.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            Text("Your selected items are in the Trash — recover anything you need. To erase them for good, open Trash Bins and empty it.")
                .font(.system(size: 13))
                .foregroundStyle(.primary.opacity(0.65))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
            if controller.askForSupport { SupportCard() }
            Button("Done") { controller.resetScan() }
                .buttonStyle(.bordered)
                .tint(.primary)
                .controlSize(.large)
            Spacer()
        }
        .padding(.horizontal, 40)
    }

    private func recentlyCleanedDetail(_ row: SmartScanCleanup.RecentlyCleanedRow) -> String {
        let size = FileSizeFormatter.format(row.size)
        if row.itemCount <= 1 {
            return size
        }
        return "\(size) (\(row.itemCount) items)"
    }

    private func resultPill(icon: String, label: String, value: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 22))
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .opacity(0.7)
            Text(value)
                .font(.system(size: 13, weight: .semibold))
        }
        .foregroundStyle(.primary)
        .frame(width: 110, height: 90)
        .background(.primary.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
