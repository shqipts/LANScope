import Foundation
import Combine

@MainActor
final class LANViewModel: ObservableObject {
    @Published var hosts: [LANHost] = []
    @Published var isScanning = false
    @Published var searchText = ""
    @Published var progressText = ""
    @Published var lastScanDate: Date?
    @Published var hasAttemptedScan = false
    @Published var progressValue: Double = 0

    private let scanner = LANScannerService()
    private let infoService = NetworkInfoService()
    private let cache = LANHostCacheService.shared
    private var scanTask: Task<Void, Never>?

    init() {
        hosts = cache.loadHosts()
    }

    func startScan() {
        cancelScan()
        scanTask = Task { await scan() }
    }

    func cancelScan() {
        scanTask?.cancel()
        scanTask = nil
        if isScanning {
            isScanning = false
            progressText = "Scan cancelled"
        }
    }

    func scan() async {
        isScanning = true
        hasAttemptedScan = true
        progressValue = 0.05
        progressText = "Preparing LAN scan…"
        defer {
            isScanning = false
            scanTask = nil
        }

        let details = await infoService.fetchWiFiDetails()
        if Task.isCancelled { return }

        progressValue = 0.15
        progressText = "Scanning subnet, ports, and Bonjour services around \(details.localIP)…"
        let fresh = await scanner.scanSubnet(baseIP: details.localIP)
        if Task.isCancelled { return }

        hosts = merge(fresh: fresh, cached: cache.loadHosts())
        cache.saveHosts(hosts)
        progressValue = 1.0
        lastScanDate = Date()
        progressText = hosts.isEmpty ? "No hosts found. Make sure Local Network access is allowed." : "Found \(hosts.count) host(s)"
    }

    private func merge(fresh: [LANHost], cached: [LANHost]) -> [LANHost] {
        var merged = Dictionary(uniqueKeysWithValues: cached.map { ($0.ipAddress, $0) })
        let staleCutoff = Date().addingTimeInterval(-60 * 60 * 24 * 3)

        for host in fresh {
            if var existing = merged[host.ipAddress] {
                existing.hostName = host.hostName ?? existing.hostName
                existing.vendor = host.vendor ?? existing.vendor
                existing.isReachable = host.isReachable
                existing.isGateway = host.isGateway
                existing.hasBonjour = host.hasBonjour || existing.hasBonjour
                existing.openPorts = Array(Set(existing.openPorts + host.openPorts)).sorted()
                existing.discoverySource = mergedSource(existing.discoverySource, host.discoverySource)
                existing.lastSeen = .now
                merged[host.ipAddress] = existing
            } else {
                merged[host.ipAddress] = host
            }
        }

        for (ip, host) in merged {
            if host.lastSeen < staleCutoff {
                merged.removeValue(forKey: ip)
            } else if !fresh.contains(where: { $0.ipAddress == ip }) {
                var faded = host
                faded.discoverySource = .cached
                merged[ip] = faded
            }
        }

        return Array(merged.values).sorted { $0.ipAddress.localizedStandardCompare($1.ipAddress) == .orderedAscending }
    }

    private func mergedSource(_ lhs: DiscoverySource, _ rhs: DiscoverySource) -> DiscoverySource {
        if lhs == rhs { return lhs }
        if lhs == .cached { return rhs }
        if rhs == .cached { return lhs }
        return .both
    }

    var filteredHosts: [LANHost] {
        guard !searchText.isEmpty else { return hosts }
        return hosts.filter {
            $0.displayName.localizedCaseInsensitiveContains(searchText) ||
            $0.ipAddress.localizedCaseInsensitiveContains(searchText) ||
            ($0.vendor ?? "").localizedCaseInsensitiveContains(searchText)
        }
    }

    var reachableCount: Int {
        hosts.filter(\.isReachable).count
    }

    var bonjourCount: Int {
        hosts.filter(\.hasBonjour).count
    }

    var bothCount: Int {
        hosts.filter { $0.discoverySource == .both }.count
    }

    var cachedCount: Int {
        hosts.filter { $0.discoverySource == .cached }.count
    }

    var shouldShowPermissionHint: Bool {
        !hasAttemptedScan && hosts.isEmpty
    }

    var exportText: String {
        let lines = filteredHosts.map { host in
            let ports = host.openPorts.isEmpty ? "-" : host.openPorts.map(String.init).joined(separator: ",")
            return "\(host.ipAddress) | \(host.displayName) | \(host.discoverySource.rawValue) | \(ports) | last seen: \(host.lastSeen.formatted())"
        }
        return (["LANScope Scan Export", ""] + lines).joined(separator: "\n")
    }
}
