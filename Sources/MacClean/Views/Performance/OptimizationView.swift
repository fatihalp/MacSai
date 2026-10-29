import SwiftUI
import MacCleanKit

struct OptimizationView: View {
    @State private var controller = OptimizationController()
    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Optimization")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.primary)
                    Text("See CPU and memory hogs and force-quit them")
                        .font(.system(size: 12))
                        .foregroundStyle(.primary.opacity(0.6))
                }
                Spacer()

                Button {
                    controller.refresh()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .help("Rescan startup items")
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)

            Picker("Section", selection: $selectedTab) {
                Text("Resource Hogs").tag(0)
                Text("Login Items").tag(1)
                Text("Launch Agents").tag(2)
                Text("Launch Daemons").tag(3)
                Text("File Associations").tag(4)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, 24)
            .padding(.bottom, 10)

            Group {
                if selectedTab == 0 {
                    ResourceHogsView()
                } else if selectedTab == 4 {
                    FileHandlerView()
                } else if controller.isLoading {
                    VStack(spacing: 12) {
                        Spacer()
                        ProgressView()
                            .controlSize(.large)
                            .tint(.primary)
                        Text("Loading items...")
                            .font(.system(size: 13))
                            .foregroundStyle(.primary.opacity(0.6))
                        Spacer()
                    }
                } else {
                    Group {
                        switch selectedTab {
                        case 1:  itemList(items: controller.loginItems)
                        case 2:  itemList(items: controller.launchAgents)
                        case 3:  itemList(items: controller.launchDaemons)
                        default: itemList(items: controller.loginItems)
                        }
                    }
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
        .alert(controller.alertMessage, isPresented: $controller.showAlert) {
            Button("OK") { controller.showAlert = false }
        }
        .task { controller.refresh() }
    }

    @ViewBuilder
    private func itemList(items: [AutoStartItem]) -> some View {
        if items.isEmpty {
            VStack(spacing: 8) {
                Spacer()
                Image(systemName: "tray")
                    .font(.system(size: 32))
                    .foregroundStyle(.tertiary)
                Text("No items found")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .frame(maxWidth: .infinity)
        } else {
            List {
                ForEach(items, id: \.id) { item in
                    ItemRow(item: item, onToggle: { newVal in
                        controller.toggle(item, enabled: newVal)
                    }, onOpenConfig: {
                        controller.openConfig(item)
                    })
                }
            }
            .listStyle(.inset)
        }
    }
}

private struct ItemRow: View {
    let item: AutoStartItem
    let onToggle: (Bool) -> Void
    let onOpenConfig: () -> Void

    var body: some View {
        HStack(spacing: 8) {

            if let bid = item.bundleIdentifier,
               let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bid) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                    .resizable()
                    .frame(width: 28, height: 28)
            } else if let path = item.programPath,
                      FileManager.default.fileExists(atPath: path) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: path))
                    .resizable()
                    .frame(width: 28, height: 28)
            } else {
                Image(systemName: "app.dashed")
                    .font(.system(size: 20))
                    .foregroundStyle(.tertiary)
                    .frame(width: 28, height: 28)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)

                HStack(spacing: 6) {

                    Text(item.sourceType.localizedName)
                        .font(.system(size: 9, weight: .medium))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(sourceTypeColor.opacity(0.2))
                        .foregroundStyle(sourceTypeColor)
                        .clipShape(Capsule())

                    if item.isSystem {
                        Text("System")
                            .font(.system(size: 9, weight: .medium))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(.orange.opacity(0.2))
                            .foregroundStyle(.orange)
                            .clipShape(Capsule())
                    }
                }
            }

            Spacer(minLength: 0)

            if item.sourceType != .loginItem && item.isSystem {
                Image(systemName: "lock.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            } else {
                Toggle("", isOn: Binding(
                    get: { item.isEnabled },
                    set: { onToggle($0) }
                ))
                .toggleStyle(.switch)
                .controlSize(.small)
            }

            if item.hasConfigFile {
                Button(action: onOpenConfig) {
                    Image(systemName: "folder")
                        .font(.system(size: 11))
                }
                .buttonStyle(.bordered)
                .help("Show config in Finder")
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 2)
    }

    private var sourceTypeColor: Color {
        switch item.sourceType {
        case .loginItem:    return .blue
        case .launchAgent:  return .orange
        case .launchDaemon: return .purple
        }
    }
}
