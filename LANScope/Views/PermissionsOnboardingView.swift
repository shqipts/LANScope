import SwiftUI

struct PermissionsOnboardingView: View {
    let onContinue: () -> Void

    @StateObject private var locationPermission = LocationPermissionService.shared
    @State private var isTriggeringLocalNetwork = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Welcome to LANScope")
                            .font(.largeTitle.bold())
                        Text("Before the app can scan your LAN and read Wi-Fi details, iPhone needs a couple of permissions.")
                            .foregroundStyle(.secondary)
                    }

                    SectionCard(title: "Location", subtitle: "Needed for Wi-Fi name / SSID on iOS") {
                        Text("Apple ties Wi-Fi name access to Location permission. Without it, SSID/BSSID may stay unavailable.")
                            .foregroundStyle(.secondary)
                        Button("Grant Location") {
                            locationPermission.requestWhenInUse()
                        }
                        .buttonStyle(.borderedProminent)
                    }

                    SectionCard(title: "Local Network", subtitle: "Needed for LAN scanning and Bonjour discovery") {
                        Text("LANScope needs Local Network access to find routers, phones, printers, TVs, and other LAN devices.")
                            .foregroundStyle(.secondary)
                        Button(isTriggeringLocalNetwork ? "Triggering…" : "Grant Local Network") {
                            triggerLocalNetworkPrompt()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isTriggeringLocalNetwork)
                    }

                    SectionCard(title: "What the app does not need") {
                        Text("No contacts, no photos, no microphone, no camera, no Bluetooth.")
                            .foregroundStyle(.secondary)
                    }

                    Button("Continue to LANScope") {
                        onContinue()
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
        }
    }

    private func triggerLocalNetworkPrompt() {
        isTriggeringLocalNetwork = true
        Task {
            _ = await BonjourDiscoveryService().discover(timeout: 1.5)
            isTriggeringLocalNetwork = false
        }
    }
}
