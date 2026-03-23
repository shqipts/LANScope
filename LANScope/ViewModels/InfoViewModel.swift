import Foundation
import Combine
import CoreLocation

@MainActor
final class InfoViewModel: ObservableObject {
    @Published var snapshot = NetworkSnapshot()
    @Published var isLoading = false

    private let service = NetworkInfoService()

    func load() async {
        isLoading = true
        snapshot = await service.fetchSnapshot()
        isLoading = false
    }

    var summaryItems: [NetworkSummary] {
        [
            .init(title: "Local IP", value: snapshot.wifi.localIP),
            .init(title: "Subnet Mask", value: snapshot.wifi.subnetMask),
            .init(title: "Gateway", value: snapshot.wifi.gateway),
            .init(title: "External IP", value: snapshot.wifi.externalIP),
            .init(title: "DNS", value: snapshot.wifi.dnsServers.joined(separator: ", ")),
            .init(title: "SSID", value: snapshot.wifi.ssid),
            .init(title: "BSSID", value: snapshot.wifi.bssid)
        ]
    }

    var cellularItems: [NetworkSummary] {
        [
            .init(title: "Connected", value: snapshot.cellular.isConnected ? "Yes" : "No"),
            .init(title: "Network Type", value: snapshot.cellular.networkType),
            .init(title: "IP Address", value: snapshot.cellular.ipAddress),
            .init(title: "Note", value: snapshot.cellular.note)
        ]
    }

    var needsWiFiPermissionHint: Bool {
        snapshot.wifi.ssid == "Unavailable" || snapshot.wifi.bssid == "Unavailable"
    }

    var locationDenied: Bool {
        let status = CLLocationManager().authorizationStatus
        return status == .denied || status == .restricted
    }
}
