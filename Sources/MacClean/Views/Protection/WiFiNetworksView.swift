import SwiftUI
import MacCleanKit

struct WiFiNetworksView: View {
    @State private var controller = WiFiNetworksController()
    @State private var pendingForget: [PreferredWiFiNetwork]?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Saved Wi-Fi")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.primary)
                    Text("Remove saved networks you no longer use to shrink your tracking surface. Administrator access is required.")
                        .font(.system(size: 12))
                        .foregroundStyle(.primary.opacity(0.6))
                }
                Spacer()
                Button {
                    Task { await controller.reload() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(controller.isLoading || controller.isForgetting)
                .help("Reload saved networks")

                Button("Forget Selected") {
                    pendingForget = controller.selectedNetworks
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .disabled(controller.selected.isEmpty || controller.isLoading || controller.isForgetting)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)

            Group {
                if controller.isLoading {
                    VStack(spacing: 12) {
                        Spacer()
                        ProgressView()
                            .controlSize(.large)
                            .tint(.primary)
                        Text("Reading saved networks…")
                            .font(.system(size: 13))
                            .foregroundStyle(.primary.opacity(0.6))
                        Spacer()
                    }
                } else if let errorMessage = controller.errorMessage, controller.networks.isEmpty {
                    VStack(spacing: 8) {
                        Spacer()
                        Text(errorMessage)
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                        Spacer()
                    }
                } else if controller.networks.isEmpty {
                    VStack {
                        Spacer()
                        Text("No saved Wi-Fi networks")
                            .foregroundStyle(.primary.opacity(0.4))
                            .font(.system(size: 13))
                        Spacer()
                    }
                } else {
                    List(controller.networks) { net in
                        HStack(spacing: 10) {
                            Toggle("", isOn: Binding(
                                get: { controller.selected.contains(net.id) },
                                set: { on in
                                    if on { controller.selected.insert(net.id) }
                                    else { controller.selected.remove(net.id) }
                                }
                            ))
                            .toggleStyle(.checkbox)
                            .labelsHidden()

                            Image(systemName: "wifi")
                                .foregroundStyle(.secondary)
                                .font(.system(size: 12))

                            VStack(alignment: .leading, spacing: 1) {
                                Text(net.ssid)
                                    .font(.system(size: 13, weight: .medium))
                                Text(net.device)
                                    .font(.system(size: 11))
                                    .foregroundStyle(.tertiary)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 2)
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
        .respondsToModuleShortcuts(onScan: { Task { await controller.reload() } }, canScan: !controller.isLoading && !controller.isForgetting)
        .alert(
            String(localized: "Forget selected networks?"),
            isPresented: Binding(
                get: { pendingForget != nil },
                set: { if !$0 { pendingForget = nil } }
            ),
            presenting: pendingForget
        ) { nets in
            Button("Cancel", role: .cancel) { pendingForget = nil }
            Button("Forget", role: .destructive) {
                let captured = nets
                pendingForget = nil
                Task { await controller.forget(captured) }
            }
        } message: { nets in
            Text("\(nets.count) saved Wi-Fi \(nets.count == 1 ? "network" : "networks") will be removed from this Mac. macOS will ask for administrator access. Forgetting the network you are on may disconnect you.")
        }
        .alert("Saved Wi-Fi",
               isPresented: Binding(get: { controller.errorMessage != nil && !controller.networks.isEmpty },
                                    set: { if !$0 { controller.errorMessage = nil } })) {
            Button("OK", role: .cancel) { controller.errorMessage = nil }
        } message: {
            Text(controller.errorMessage ?? "")
        }
    }
}
