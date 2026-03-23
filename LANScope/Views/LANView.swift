import SwiftUI

struct LANView: View {
    @ObservedObject var viewModel: LANViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    summaryCard

                    if viewModel.shouldShowPermissionHint {
                        SectionCard(title: "Local Network Access", subtitle: "Needed to discover devices on your Wi-Fi") {
                            Text("Tap Scan to trigger the Local Network permission prompt. Without it, LANScope cannot discover devices on your LAN.")
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }

                    if !viewModel.filteredHosts.isEmpty {
                        SectionCard(title: "Share / Export", subtitle: "Export the current filtered host list") {
                            ShareLink(item: viewModel.exportText) {
                                Label("Share Scan Results", systemImage: "square.and.arrow.up")
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }

                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.filteredHosts) { host in
                            NavigationLink {
                                HostDetailView(host: host)
                            } label: {
                                hostRow(host)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding()
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color(.systemGroupedBackground))
            .searchable(text: $viewModel.searchText, prompt: "Search hosts")
            .navigationTitle("LAN")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if viewModel.isScanning {
                        Button("Stop") {
                            viewModel.cancelScan()
                        }
                    } else {
                        Button("Scan") {
                            viewModel.startScan()
                        }
                    }
                }
            }
        }
    }

    private var summaryCard: some View {
        SectionCard(title: "Local Network", subtitle: viewModel.progressText.isEmpty ? "Run the default LANScope scan" : viewModel.progressText) {
            HStack(spacing: 12) {
                StatChip(title: "Hosts", value: "\(viewModel.hosts.count)")
                StatChip(title: "Bonjour", value: "\(viewModel.bonjourCount)")
                StatChip(title: "Both", value: "\(viewModel.bothCount)")
                StatChip(title: "Cached", value: "\(viewModel.cachedCount)")
            }

            Text("LANScope keeps recently seen devices and merges repeated scans so devices don’t disappear instantly.")
                .font(.caption)
                .foregroundStyle(.secondary)

            if viewModel.isScanning {
                ProgressView(value: viewModel.progressValue)
                    .tint(.blue)
            }

            if let lastScanDate = viewModel.lastScanDate {
                Text("Last scan: \(lastScanDate.formatted(date: .omitted, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func hostRow(_ host: LANHost) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(host.displayName)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Spacer()
                sourceBadge(host.discoverySource)
                if host.isGateway { badge("G") }
                if host.hasBonjour { badge("B") }
                if host.isReachable { badge("UP", color: .green) }
            }

            Text(host.ipAddress)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if let vendor = host.vendor {
                Text(vendor)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !host.openPorts.isEmpty {
                Text("Ports: \(host.openPorts.map(String.init).joined(separator: ", "))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text("Seen: \(host.lastSeen.formatted(date: .omitted, time: .shortened))")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func sourceBadge(_ source: DiscoverySource) -> some View {
        let color: Color = switch source {
        case .both: .purple
        case .bonjour: .orange
        case .cached: .gray
        case .port: .blue
        }
        return badge(source.rawValue, color: color)
    }

    private func badge(_ text: String, color: Color = .blue) -> some View {
        Text(text)
            .font(.caption2.bold())
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.14), in: Capsule())
    }
}
