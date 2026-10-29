import Foundation
import Observation
import AppKit
import MacCleanKit

@MainActor @Observable
final class WiFiNetworksController {
    var networks: [PreferredWiFiNetwork] = []
    var selected: Set<PreferredWiFiNetwork.ID> = []
    var isLoading = true
    var isForgetting = false
    var errorMessage: String?

    let client: PreferredWiFiClient

    init(client: PreferredWiFiClient = .live()) {
        self.client = client
    }

    var selectedNetworks: [PreferredWiFiNetwork] {
        networks.filter { selected.contains($0.id) }
    }

    func reload() async {
        isLoading = true
        errorMessage = nil
        let result = await client.listNetworks()
        guard !Task.isCancelled else {
            isLoading = false
            return
        }
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

    func forget(_ nets: [PreferredWiFiNetwork]) async {
        guard !isForgetting else { return }
        isForgetting = true
        defer { isForgetting = false }
        let result = await client.forget(nets)
        switch result {
        case .success:
            selected.subtract(nets.map(\.id))
            await reload()
        case .failure(let error):
            await reload()
            if error != .adminCancelled {
                errorMessage = error.localizedMessage
            }
        }
    }
}
