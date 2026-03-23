import Foundation

struct NetworkSummary: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let value: String
}

struct WiFiDetails: Hashable {
    var ssid: String = "Unavailable"
    var bssid: String = "Unavailable"
    var localIP: String = "Unknown"
    var subnetMask: String = "Unknown"
    var gateway: String = "Unknown"
    var dnsServers: [String] = []
    var externalIP: String = "Unknown"
}

struct CellularDetails: Hashable {
    var isConnected: Bool = false
    var networkType: String = "Unknown"
    var ipAddress: String = "Unavailable"
    var note: String = "Limited by iOS"
}

struct NetworkSnapshot: Hashable {
    var wifi = WiFiDetails()
    var cellular = CellularDetails()
}

enum DiscoverySource: String, Hashable, Codable {
    case port = "PORT"
    case bonjour = "BONJOUR"
    case both = "BOTH"
    case cached = "CACHED"
}

struct LANHost: Identifiable, Hashable, Codable {
    let id: UUID
    let ipAddress: String
    var hostName: String?
    var vendor: String?
    var isReachable: Bool
    var isGateway: Bool
    var hasBonjour: Bool
    var openPorts: [Int]
    var discoverySource: DiscoverySource = .port
    var lastSeen: Date = .now

    init(id: UUID = UUID(), ipAddress: String, hostName: String? = nil, vendor: String? = nil, isReachable: Bool, isGateway: Bool, hasBonjour: Bool, openPorts: [Int], discoverySource: DiscoverySource = .port, lastSeen: Date = .now) {
        self.id = id
        self.ipAddress = ipAddress
        self.hostName = hostName
        self.vendor = vendor
        self.isReachable = isReachable
        self.isGateway = isGateway
        self.hasBonjour = hasBonjour
        self.openPorts = openPorts
        self.discoverySource = discoverySource
        self.lastSeen = lastSeen
    }

    var displayName: String {
        hostName ?? vendor ?? "Unknown Device"
    }
}

struct BonjourServiceHost: Hashable {
    let ipAddress: String
    let hostName: String?
    let serviceType: String
}

struct PortScanResult: Identifiable, Hashable {
    let id = UUID()
    let host: String
    let port: Int
    let isOpen: Bool
}

struct PingResult: Hashable {
    let host: String
    let success: Bool
    let latencyMs: Double?
    let message: String
}

struct DNSLookupResult: Hashable {
    let host: String
    let addresses: [String]
}

struct WhoisResult: Hashable {
    let query: String
    let rawText: String
}
