import SwiftUI
import MacCleanKit

struct CleanHistoryView: View {
    @State private var controller = CleanHistoryController()
    @State private var pendingRestore: CleanHistorySession?
    @State private var confirmClear = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Clean History")
                        .font(.system(size: 22, weight: .bold))
                    Text("Put a whole clean back in one click. Items already emptied from the Trash, or with a new file at their original place, are skipped.")
                    .font(.system(size: 12))
                    .foregroundStyle(.primary.opacity(0.6))
                }
                Spacer()
                Button {
                    confirmClear = true
                } label: {
                    Label("Clear History", systemImage: "trash.slash")
                }
                .disabled(controller.sessions.isEmpty || controller.isRestoring)
                Button {
                    Task { await controller.reload() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)

            Group {
                if controller.sessions.isEmpty {
                    VStack {
                        Spacer()
                        Text("No cleans to restore yet")
                            .foregroundStyle(.primary.opacity(0.4))
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(controller.sessions) { session in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(session.date.formatted(date: .abbreviated, time: .shortened))
                                    .font(.system(size: 13, weight: .medium))
                                Text("\(Self.itemCount(session.items.count)) · \(FileSizeFormatter.format(session.totalBytes))")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                                if session.isPartial {
                                    Label("Partly restorable",
                                          systemImage: "exclamationmark.triangle")
                                        .font(.system(size: 11))
                                        .foregroundStyle(.orange)
                                }
                            }
                            Spacer()
                            Button("Restore") {
                                pendingRestore = session
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(controller.isRestoring)
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
        .alert(
            String(localized: "Restore this clean?"),
            isPresented: Binding(
                get: { pendingRestore != nil },
                set: { if !$0 { pendingRestore = nil } }
            ),
            presenting: pendingRestore
        ) { session in
            Button("Cancel", role: .cancel) { pendingRestore = nil }
            Button("Restore") {
                let target = session
                pendingRestore = nil
                Task { await controller.restore(target) }
            }
        } message: { session in
            Text(Self.restoreMessage(for: session))
        }
        .alert(
            String(localized: "Restore finished"),
            isPresented: Binding(
                get: { controller.lastSummary != nil },
                set: { if !$0 { controller.lastSummary = nil } }
            )
        ) {
            Button("OK", role: .cancel) { controller.lastSummary = nil }
        } message: {
            if let lastSummary = controller.lastSummary {
                Text(Self.summaryMessage(lastSummary))
            }
        }
        .alert(
            String(localized: "Clear clean history?"),
            isPresented: $confirmClear
        ) {
            Button("Cancel", role: .cancel) {}
            Button("Clear", role: .destructive) {
                controller.clear()
            }
        } message: {
            Text("This only forgets the restore list. Nothing in the Trash is touched, but these cleans can no longer be restored in one click.")
        }
    }

    static func itemCount(_ n: Int) -> String {
        String(format: n == 1 ? "%ld item" : "%ld items", n)
    }

    static func restoreMessage(for session: CleanHistorySession) -> String {
        var lines = [
            itemCount(session.items.count),
            String(localized: "Each item goes back to its original place. A file already at that place is never overwritten."),
        ]
        if let omitted = session.omittedCount, omitted > 0 {
            lines.append(String(format: String(localized: "This clean was too large to track in full: only the first %ld items can be restored. The other %ld are still in the Trash, and you can put them back from Finder."), session.items.count, omitted))
        }
        return lines.joined(separator: "\n\n")
    }

    static func summaryMessage(_ summary: CleanHistoryRestoreSummary) -> String {
        var lines = [String(format: String(localized: "Restored: %ld"), summary.restored)]
        if summary.emptied > 0 {
            lines.append(String(format: String(localized: "Already emptied from the Trash: %ld"), summary.emptied))
        }
        if summary.reappeared > 0 {
            lines.append(String(format: String(localized: "Skipped, original place taken: %ld"), summary.reappeared))
        }
        if summary.failed > 0 {
            lines.append(String(format: String(localized: "Couldn't restore: %ld"), summary.failed))
        }
        return lines.joined(separator: "\n")
    }
}
