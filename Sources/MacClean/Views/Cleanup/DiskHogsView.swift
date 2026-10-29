import SwiftUI
import MacCleanKit

struct DiskHogsView: View {
    @State private var controller = DiskHogsController()
    @State private var confirmingPrune = false
    @State private var confirmingDelete = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(DiskHogsText.title)
                        .font(.system(size: 22, weight: .bold))
                    Text(DiskHogsText.subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(.primary.opacity(0.6))
                }
                Spacer()
                Button {
                    controller.startWork { await controller.reload() }
                } label: {
                    Label(DiskHogsText.refresh, systemImage: "arrow.clockwise")
                }
                .disabled(controller.isLoading || controller.isWorking)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)

            Group {
                if controller.isLoading {
                    VStack {
                        Spacer()
                        ProgressView().controlSize(.large)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        dockerSection
                        simulatorSection

                        if controller.dockerState == .notInstalled && controller.devices.isEmpty && controller.runtimes.isEmpty {
                            Text(DiskHogsText.nothingFound)
                                .foregroundStyle(.secondary)
                        }

                        if !controller.statusLines.isEmpty {
                            VStack(alignment: .leading, spacing: 2) {
                                ForEach(Array(controller.statusLines.enumerated()), id: \.offset) { _, line in
                                    Text(line)
                                }
                            }
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                        }
                    }
                    .listStyle(.inset)
                }
            }
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1)
            )
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .task { await controller.reload() }
        .onDisappear {
            controller.cancelWork()
        }
        .respondsToModuleShortcuts(onScan: { controller.startWork { await controller.reload() } }, canScan: !controller.isLoading && !controller.isWorking)
        .confirmationDialog(DiskHogsText.pruneConfirmTitle, isPresented: $confirmingPrune, titleVisibility: .visible) {
            Button(DiskHogsText.pruneConfirmButton, role: .destructive) {
                let selection = controller.selectedDocker
                controller.startWork { await controller.pruneDocker(selection) }
            }
            Button(DiskHogsText.cancel, role: .cancel) {}
        } message: {
            Text(pruneConfirmMessage)
        }
        .confirmationDialog(DiskHogsText.deleteConfirmTitle, isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button(DiskHogsText.deleteConfirmButton, role: .destructive) {
                let devices = controller.selectedDevices
                let runtimes = controller.selectedRuntimes
                controller.startWork { await controller.deleteSims(devices: devices, runtimes: runtimes) }
            }
            Button(DiskHogsText.cancel, role: .cancel) {}
        } message: {
            Text(deleteConfirmMessage)
        }
    }

    @ViewBuilder private var dockerSection: some View {
        switch controller.dockerState {
        case .notInstalled:
            EmptyView()
        case .notResponding:
            Section {
                Text(DiskHogsText.dockerNotResponding)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            } header: {
                Text(verbatim: "Docker")
            }
        case .rows(let rows):
            Section {
                ForEach(rows) { row in
                    if row.category.isPrunable {
                        Toggle(isOn: Binding(
                            get: { controller.selectedDocker.contains(row.category) },
                            set: { on in
                                if on { controller.selectedDocker.insert(row.category) }
                                else { controller.selectedDocker.remove(row.category) }
                            }
                        )) {
                            dockerRowLabel(row)
                        }
                    } else {

                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                                .padding(.top, 2)
                            dockerRowLabel(row)
                        }
                    }
                }
                Button(DiskHogsText.pruneButton) { confirmingPrune = true }
                    .disabled(controller.selectedDocker.isEmpty || controller.isWorking)
            } header: {
                Text(verbatim: "Docker")
            }
        }
    }

    private func dockerRowLabel(_ row: DockerDiskRow) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(row.category.label + "  ·  " + DiskHogsText.size + " " + row.size)
                .font(.system(size: 13, weight: .medium))
            Text(row.category.pruneNote)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(3)
        }
    }

    @ViewBuilder private var simulatorSection: some View {
        if !controller.devices.isEmpty || !controller.runtimes.isEmpty {
            Section(DiskHogsText.xcodeSection) {
                ForEach(controller.devices) { device in
                    simToggle(id: device.udid, title: device.name,
                              detail: DiskHogsText.unavailableSimulator + "  ·  " + device.runtimeDisplayName)
                }
                ForEach(controller.runtimes) { runtime in
                    simToggle(id: runtime.identifier, title: runtime.name,
                              detail: runtimeDetail(runtime))
                }
                Button(DiskHogsText.deleteButton) { confirmingDelete = true }
                    .disabled(controller.selectedSim.isEmpty || controller.isWorking)
            }
        }
    }

    private func simToggle(id: String, title: String, detail: String) -> some View {
        Toggle(isOn: Binding(
            get: { controller.selectedSim.contains(id) },
            set: { on in
                if on { controller.selectedSim.insert(id) }
                else { controller.selectedSim.remove(id) }
            }
        )) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(detail)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func runtimeDetail(_ runtime: SimulatorRuntime) -> String {
        guard let bytes = runtime.sizeBytes, bytes > 0 else { return DiskHogsText.olderRuntime }
        return DiskHogsText.olderRuntime + "  ·  " + ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    private var pruneConfirmMessage: String {
        let lines = DockerPrune.commands(for: controller.selectedDocker).map { "• \($0.category.label): \($0.category.pruneNote)" }
        return (lines + ["", DiskHogsText.permanentNote]).joined(separator: "\n")
    }

    private var deleteConfirmMessage: String {
        var lines = controller.selectedDevices.map { "• \($0.name) (\(DiskHogsText.unavailableSimulator))" }
        lines += controller.selectedRuntimes.map { "• \($0.name) (\(runtimeDetail($0)))" }
        if !controller.selectedRuntimes.isEmpty { lines += ["", DiskHogsText.runtimeShutdownNote] }
        return (lines + ["", DiskHogsText.permanentNote]).joined(separator: "\n")
    }
}
