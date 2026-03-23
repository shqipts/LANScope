import Foundation
import Combine

@MainActor
final class ToolsViewModel: ObservableObject {
    enum Tool: String, CaseIterable, Identifiable {
        case ping = "Ping"
        case portScan = "Port Scan"
        case dns = "DNS"
        case whois = "Whois"

        var id: String { rawValue }
    }

    enum PortScanMode: String, CaseIterable, Identifiable {
        case common = "Common"
        case extended = "Extended"
        case custom = "Custom"

        var id: String { rawValue }
    }

    @Published var selectedTool: Tool = .ping
    @Published var target = "192.168.1.1"
    @Published var pingResult: PingResult?
    @Published var dnsResult: DNSLookupResult?
    @Published var whoisResult: WhoisResult?
    @Published var portResults: [PortScanResult] = []
    @Published var portScanMode: PortScanMode = .common
    @Published var customPortsInput = "22,80,443"
    @Published var isRunning = false
    @Published var statusText = ""

    private let tools = ToolsService()
    private let scanner = LANScannerService()

    func run() async {
        isRunning = true
        pingResult = nil
        dnsResult = nil
        whoisResult = nil
        portResults = []
        statusText = ""
        defer { isRunning = false }

        switch selectedTool {
        case .ping:
            pingResult = await tools.ping(host: target)
        case .dns:
            dnsResult = await tools.dnsLookup(host: target)
        case .whois:
            whoisResult = await tools.whois(query: target)
        case .portScan:
            statusText = statusLabelForScan
            let ports = portsForCurrentMode()
            portResults = await scanner.scanPorts(host: target, ports: ports).filter(\.isOpen)
            statusText = portResults.isEmpty ? "No open ports found" : "Found \(portResults.count) open port(s)"
        }
    }

    var visiblePortResults: [PortScanResult] {
        portResults.filter(\.isOpen)
    }

    var statusLabelForScan: String {
        switch portScanMode {
        case .common: return "Scanning common ports…"
        case .extended: return "Scanning extended port set…"
        case .custom: return "Scanning custom ports…"
        }
    }

    private func portsForCurrentMode() -> [Int]? {
        switch portScanMode {
        case .common:
            return nil
        case .extended:
            return Array(Set([20, 21, 22, 23, 25, 53, 80, 110, 123, 135, 137, 138, 139, 143, 161, 389, 443, 445, 465, 587, 631, 993, 995, 1723, 1900, 3306, 3389, 5353, 5900, 8080, 8081, 8443, 8888, 62078])).sorted()
        case .custom:
            let parsed = parsePorts(customPortsInput)
            return parsed.isEmpty ? [22, 80, 443] : parsed
        }
    }

    private func parsePorts(_ input: String) -> [Int] {
        let tokens = input
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var ports = Set<Int>()

        for token in tokens {
            if token.contains("-") {
                let bounds = token.split(separator: "-").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                if bounds.count == 2,
                   let start = Int(bounds[0]),
                   let end = Int(bounds[1]),
                   start > 0, end <= 65535, start <= end {
                    for port in start...end {
                        ports.insert(port)
                    }
                }
            } else if let port = Int(token), port > 0, port <= 65535 {
                ports.insert(port)
            }
        }

        return ports.sorted()
    }
}
