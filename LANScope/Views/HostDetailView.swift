import SwiftUI

struct HostDetailView: View {
    let host: LANHost

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                SectionCard(title: host.displayName, subtitle: host.vendor ?? "Unknown vendor") {
                    InfoRow(title: "IP Address", value: host.ipAddress)
                    InfoRow(title: "Reachable", value: host.isReachable ? "Yes" : "No")
                    InfoRow(title: "Gateway", value: host.isGateway ? "Yes" : "No")
                    InfoRow(title: "Bonjour", value: host.hasBonjour ? "Yes" : "No")
                    InfoRow(title: "Source", value: host.discoverySource.rawValue)
                }

                SectionCard(title: "Actions") {
                    ShareLink(item: hostSummaryText) {
                        Label("Share Host Summary", systemImage: "square.and.arrow.up")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Button {
                        copy(hostSummaryText)
                    } label: {
                        Label("Copy Host Summary", systemImage: "doc.on.doc")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                SectionCard(title: "Open Ports") {
                    if host.openPorts.isEmpty {
                        Text("No open ports discovered during the quick scan.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(host.openPorts, id: \.self) { port in
                            InfoRow(title: "Port \(port)", value: "Open")
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle(host.ipAddress)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var hostSummaryText: String {
        let ports = host.openPorts.isEmpty ? "None" : host.openPorts.map(String.init).joined(separator: ", ")
        return "Host: \(host.displayName)\nIP: \(host.ipAddress)\nSource: \(host.discoverySource.rawValue)\nOpen Ports: \(ports)"
    }

    private func copy(_ text: String) {
        #if canImport(UIKit)
        UIPasteboard.general.string = text
        #endif
    }
}
