import SwiftUI
import MacCleanKit

struct WiFiNetworksView: View {
    @AppStorage("removeBackgroundColors") private var removeBackgroundColors = false
    @State private var networks: [PreferredWiFiNetwork] = []
    @State private var selected: Set<PreferredWiFiNetwork.ID> = []
    @State private var isLoading = true
    @State private var isForgetting = false
    @State private var errorMessage: String?
    @State private var pendingForget: [PreferredWiFiNetwork]?
    private let client = PreferredWiFiClient.live()

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
                    Task { await reload() }
                } label: {
                    Label(String(localized: "Refresh"), systemImage: "arrow.clockwise")
                }
                .disabled(isLoading || isForgetting)
                .help(String(localized: "Reload saved networks"))

                Button(String(localized: "Forget Selected")) {
                    pendingForget = selectedNetworks
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .disabled(selected.isEmpty || isLoading || isForgetting)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)

            Group {
                if isLoading {
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
                } else if let errorMessage, networks.isEmpty {
                    VStack(spacing: 8) {
                        Spacer()
                        Text(errorMessage)
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                        Spacer()
                    }
                } else if networks.isEmpty {
                    VStack {
                        Spacer()
                        Text("No saved Wi-Fi networks")
                            .foregroundStyle(.primary.opacity(0.4))
                            .font(.system(size: 13))
                        Spacer()
                    }
                } else {
                    List(networks) { net in
                        HStack(spacing: 10) {
                            Toggle("", isOn: Binding(
                                get: { selected.contains(net.id) },
                                set: { on in
                                    if on { selected.insert(net.id) }
                                    else { selected.remove(net.id) }
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
        .task { await reload() }
        .respondsToModuleShortcuts(onScan: { Task { await reload() } }, canScan: !isLoading && !isForgetting)
        .alert(
            String(localized: "Forget selected networks?"),
            isPresented: Binding(
                get: { pendingForget != nil },
                set: { if !$0 { pendingForget = nil } }
            ),
            presenting: pendingForget
        ) { nets in
            Button(String(localized: "Cancel"), role: .cancel) { pendingForget = nil }
            Button(String(localized: "Forget"), role: .destructive) {
                let captured = nets
                pendingForget = nil
                Task { await forget(captured) }
            }
        } message: { nets in
            Text("\(nets.count) saved Wi-Fi \(nets.count == 1 ? "network" : "networks") will be removed from this Mac. macOS will ask for administrator access. Forgetting the network you are on may disconnect you.")
        }
        .alert(String(localized: "Saved Wi-Fi"),
               isPresented: Binding(get: { errorMessage != nil && !networks.isEmpty },
                                    set: { if !$0 { errorMessage = nil } })) {
            Button(String(localized: "OK"), role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var selectedNetworks: [PreferredWiFiNetwork] {
        networks.filter { selected.contains($0.id) }
    }

    private func reload() async {
        isLoading = true
        errorMessage = nil
        let result = await client.listNetworks()
        switch result {
        case .success(let list):
            networks = list
            selected = selected.intersection(Set(list.map(\.id)))
        case .failure(let error):
            networks = []
            selected = []
            errorMessage = error.localizedMessage
        }
        isLoading = false
    }

    private func forget(_ nets: [PreferredWiFiNetwork]) async {
        guard !isForgetting else { return }
        isForgetting = true
        let result = await client.forget(nets)
        switch result {
        case .success:
            selected.subtract(nets.map(\.id))
            await reload()
        case .failure(let error):
            if error != .adminCancelled {
                errorMessage = error.localizedMessage
            }
            await reload()
        }
        isForgetting = false
    }
}
