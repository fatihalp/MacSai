import SwiftUI
import MacCleanKit

struct MaintenanceView: View {
    @State private var controller = MaintenanceController()

    @State private var taskAwaitingConfirmation: MaintenanceTask?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Maintenance Tasks")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.primary)
                    Text("Your macOS does a pretty good job of self-care, but there's always room for more. Run recommended maintenance tasks to bring your Mac to its max.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                Spacer()

                Button("Run Safe Tasks") { controller.runSafeTasks() }
                    .buttonStyle(.borderedProminent)
                    .tint(Color(nsColor: .systemBlue))
                    .controlSize(.regular)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)

            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(MaintenanceTask.allCases) { task in
                        taskRow(task)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
        .alert(
            "Run \(taskAwaitingConfirmation?.title ?? "")?",
            isPresented: Binding(
                get: { taskAwaitingConfirmation != nil },
                set: { if !$0 { taskAwaitingConfirmation = nil } }
            ),
            presenting: taskAwaitingConfirmation
        ) { task in
            Button("Cancel", role: .cancel) {
                taskAwaitingConfirmation = nil
            }
            Button("Run Anyway", role: .destructive) {
                let captured = task
                taskAwaitingConfirmation = nil
                controller.runTask(captured)
            }
        } message: { task in
            Text(task.sideEffects)
        }
    }

    private func taskRow(_ task: MaintenanceTask) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(task.severity == .advanced ? Color.orange.opacity(0.15) : Color(nsColor: .systemOrange).opacity(0.12))
                    .frame(width: 34, height: 34)
                Image(systemName: task.icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(task.severity == .advanced ? Color.orange : Color(nsColor: .systemOrange))
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(task.title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.primary)
                    if task.severity == .advanced {
                        Text("ADVANCED")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.orange)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.orange.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                    }
                }
                if case .failed(let message) = controller.taskStates[task] {
                    Text(message)
                        .font(.system(size: 11))
                        .foregroundStyle(Color.orange.opacity(0.8))
                        .lineLimit(2)
                } else {
                    Text(task.description)
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            statusView(for: task)

            Button {
                didTapRun(task)
            } label: {
                Image(systemName: task.severity == .advanced
                      ? "exclamationmark.triangle.fill"
                      : "play.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(task.severity == .advanced
                                     ? Color.orange.opacity(0.85)
                                     : Color(nsColor: .systemBlue))
            }
            .buttonStyle(.plain)
            .disabled(controller.isRunning(task))
            .help(task.severity == .advanced
                  ? String(localized: "Has multi-hour side effects — opens a confirmation")
                  : String(localized: "Run this task"))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.35))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color(nsColor: .separatorColor).opacity(0.35), lineWidth: 0.5)
        )
    }

    @ViewBuilder
    private func statusView(for task: MaintenanceTask) -> some View {
        switch controller.taskStates[task] {
        case .running:
            ProgressView()
                .controlSize(.small)
                .tint(.primary)
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .failed(let message):
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .help(message)
        case .idle, .none:
            EmptyView()
        }
    }

    private func didTapRun(_ task: MaintenanceTask) {
        switch task.severity {
        case .safe:
            controller.runTask(task)
        case .advanced:
            taskAwaitingConfirmation = task
        }
    }
}
