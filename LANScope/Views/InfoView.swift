import SwiftUI

struct InfoView: View {
    @ObservedObject var viewModel: InfoViewModel
    @StateObject private var locationPermission = LocationPermissionService.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    header

                    if viewModel.needsWiFiPermissionHint {
                        SectionCard(title: "Wi-Fi Info Access", subtitle: "iOS may require Location permission to reveal SSID and BSSID") {
                            Text(viewModel.locationDenied ? "Location access is currently denied. Open Settings and allow Location When In Use for LANScope." : "If the Wi-Fi name is missing, allow Location When In Use for LANScope. Apple ties Wi-Fi details to location access.")
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            HStack {
                                Button("Allow Wi-Fi Info") {
                                    locationPermission.requestWhenInUse()
                                }
                                .buttonStyle(.borderedProminent)

                                if viewModel.locationDenied {
                                    Button("Open Settings") {
                                        openSettings()
                                    }
                                    .buttonStyle(.bordered)
                                }
                            }
                        }
                    }

                    SectionCard(title: "Connection Snapshot", subtitle: "Fast overview") {
                        HStack(spacing: 12) {
                            StatChip(title: "SSID", value: viewModel.snapshot.wifi.ssid)
                            StatChip(title: "External IP", value: viewModel.snapshot.wifi.externalIP)
                        }
                        HStack(spacing: 12) {
                            StatChip(title: "Cellular", value: viewModel.snapshot.cellular.isConnected ? viewModel.snapshot.cellular.networkType : "Off")
                            StatChip(title: "Gateway", value: viewModel.snapshot.wifi.gateway)
                        }
                    }

                    SectionCard(title: "Wi-Fi & Network", subtitle: "Current device connection details") {
                        ForEach(viewModel.summaryItems) { item in
                            InfoRow(title: item.title, value: item.value)
                        }
                    }

                    SectionCard(title: "Cellular / SIM", subtitle: "Best-effort iPhone carrier and mobile data details") {
                        ForEach(viewModel.cellularItems) { item in
                            InfoRow(title: item.title, value: item.value)
                        }
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Info")
            .task { await viewModel.load() }
            .refreshable { await viewModel.load() }
            .onChange(of: locationPermission.status) { _, _ in
                Task { await viewModel.load() }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("LANScope")
                .font(.largeTitle.bold())
            Text("Quick view of your Wi-Fi, IP address, gateway, DNS, external IP, and mobile data state.")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func openSettings() {
        #if canImport(UIKit)
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
        #endif
    }
}
