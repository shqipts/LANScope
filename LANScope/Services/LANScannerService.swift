import Foundation
import Network

final class LANScannerService {
    struct DefaultProfile {
        let maxHosts: Int = 254
        let batchSize: Int = 18
        let probePorts: [Int] = [21, 22, 23, 25, 53, 80, 81, 88, 110, 123, 135, 137, 138, 139, 143, 161, 389, 443, 445, 465, 554, 587, 631, 993, 995, 1723, 1900, 3306, 3389, 5353, 5900, 62078, 7000, 7001, 7443, 8000, 8008, 8009, 8080, 8081, 8443, 8888]
        let probeTimeout: TimeInterval = 0.85
        let bonjourTimeout: TimeInterval = 5.0
    }

    private let commonPorts = [20, 21, 22, 23, 25, 53, 80, 110, 139, 143, 443, 445, 465, 587, 631, 8000, 8080, 8443]
    private let bonjour = BonjourDiscoveryService()
    private let profile = DefaultProfile()

    func scanSubnet(baseIP: String) async -> [LANHost] {
        let prefix = subnetPrefix(for: baseIP)
        guard !prefix.isEmpty else { return [] }

        async let bonjourHosts = bonjour.discover(timeout: profile.bonjourTimeout)

        var results: [LANHost] = []
        var current = 1

        while current <= profile.maxHosts {
            if Task.isCancelled { return results }
            let upperBound = min(current + profile.batchSize - 1, profile.maxHosts)
            let batch = Array(current...upperBound)

            let batchResults = await withTaskGroup(of: LANHost?.self) { group in
                for host in batch {
                    let ip = "\(prefix).\(host)"
                    group.addTask {
                        await self.probeHost(ip)
                    }
                }

                var partial: [LANHost] = []
                for await result in group {
                    if let result {
                        partial.append(result)
                    }
                }
                return partial
            }

            results.append(contentsOf: batchResults)
            current = upperBound + 1
        }

        let discoveredServices = await bonjourHosts
        results = mergeBonjour(discoveredServices, into: results)

        let secondPass = results.filter { $0.openPorts.isEmpty && $0.hasBonjour }
        if !secondPass.isEmpty {
            for host in secondPass {
                if let refreshed = await probeHost(host.ipAddress) {
                    results.removeAll { $0.ipAddress == host.ipAddress }
                    results.append(refreshed)
                }
            }
        }

        return results.sorted { $0.ipAddress.localizedStandardCompare($1.ipAddress) == .orderedAscending }
    }

    func scanPorts(host: String, ports: [Int]? = nil) async -> [PortScanResult] {
        let targets = ports ?? commonPorts
        let chunkSize = targets.count > 1024 ? 128 : 32
        var collected: [PortScanResult] = []
        var index = 0

        while index < targets.count {
            if Task.isCancelled { break }
            let upper = min(index + chunkSize, targets.count)
            let chunk = Array(targets[index..<upper])

            let results = await withTaskGroup(of: PortScanResult.self) { group in
                for port in chunk {
                    group.addTask {
                        let timeout: TimeInterval = targets.count > 1024 ? 0.25 : 0.8
                        let isOpen = await self.checkTCPPort(host: host, port: port, timeout: timeout)
                        return PortScanResult(host: host, port: port, isOpen: isOpen)
                    }
                }

                var partial: [PortScanResult] = []
                for await result in group {
                    partial.append(result)
                }
                return partial
            }

            collected.append(contentsOf: results)
            index = upper
        }

        return collected.sorted { $0.port < $1.port }
    }

    private func subnetPrefix(for ip: String) -> String {
        let comps = ip.split(separator: ".")
        guard comps.count == 4 else { return "" }
        return comps.prefix(3).joined(separator: ".")
    }

    private func probeHost(_ ip: String) async -> LANHost? {
        let openPorts = await discoverOpenPorts(host: ip)
        guard !openPorts.isEmpty else { return nil }

        let hostName = await reverseLookup(ip: ip)
        let bonjourLike = [5353, 62078].contains(where: openPorts.contains)

        return LANHost(
            ipAddress: ip,
            hostName: hostName,
            vendor: vendorGuess(hostName: hostName, openPorts: openPorts),
            isReachable: true,
            isGateway: ip.hasSuffix(".1"),
            hasBonjour: bonjourLike,
            openPorts: openPorts,
            discoverySource: bonjourLike ? .both : .port
        )
    }

    private func discoverOpenPorts(host: String) async -> [Int] {
        await withTaskGroup(of: Int?.self) { group in
            for port in profile.probePorts {
                group.addTask {
                    let isOpen = await self.checkTCPPort(host: host, port: port, timeout: self.profile.probeTimeout)
                    return isOpen ? port : nil
                }
            }

            var openPorts: [Int] = []
            for await result in group {
                if let port = result {
                    openPorts.append(port)
                }
            }
            return openPorts.sorted()
        }
    }

    func checkTCPPort(host: String, port: Int, timeout: TimeInterval) async -> Bool {
        return await withCheckedContinuation { continuation in
            let queue = DispatchQueue(label: "LANScope.PortCheck.\(host).\(port)")
            let endpointPort = NWEndpoint.Port(rawValue: UInt16(port)) ?? .http
            let connection = NWConnection(host: NWEndpoint.Host(host), port: endpointPort, using: .tcp)
            let box = ResumeBox()

            let finish: @Sendable (Bool) -> Void = { result in
                guard box.tryResume() else { return }
                connection.cancel()
                continuation.resume(returning: result)
            }

            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    finish(true)
                case .failed(_), .cancelled:
                    finish(false)
                default:
                    break
                }
            }

            connection.start(queue: queue)
            queue.asyncAfter(deadline: .now() + timeout) {
                finish(false)
            }
        }
    }

    private func reverseLookup(ip: String) async -> String? {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                var sa = sockaddr_in()
                sa.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
                sa.sin_family = sa_family_t(AF_INET)
                inet_pton(AF_INET, ip, &sa.sin_addr)

                var hostBuffer = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                let result = withUnsafePointer(to: &sa) {
                    $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                        getnameinfo(
                            $0,
                            socklen_t(MemoryLayout<sockaddr_in>.size),
                            &hostBuffer,
                            socklen_t(hostBuffer.count),
                            nil,
                            0,
                            NI_NAMEREQD
                        )
                    }
                }

                if result == 0 {
                    continuation.resume(returning: String(cString: hostBuffer))
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    private func mergeBonjour(_ services: [BonjourServiceHost], into hosts: [LANHost]) -> [LANHost] {
        var merged = Dictionary(uniqueKeysWithValues: hosts.map { ($0.ipAddress, $0) })

        for service in services {
            if var existing = merged[service.ipAddress] {
                if existing.hostName == nil { existing.hostName = service.hostName }
                existing.hasBonjour = true
                existing.discoverySource = existing.discoverySource == .port ? .both : .bonjour
                if existing.vendor == nil {
                    existing.vendor = vendorGuess(hostName: service.hostName, openPorts: existing.openPorts)
                }
                merged[service.ipAddress] = existing
            } else {
                merged[service.ipAddress] = LANHost(
                    ipAddress: service.ipAddress,
                    hostName: service.hostName,
                    vendor: vendorGuess(hostName: service.hostName, openPorts: []),
                    isReachable: true,
                    isGateway: service.ipAddress.hasSuffix(".1"),
                    hasBonjour: true,
                    openPorts: [],
                    discoverySource: .bonjour
                )
            }
        }

        return Array(merged.values)
    }

    private func vendorGuess(hostName: String?, openPorts: [Int]) -> String? {
        let lower = (hostName ?? "").lowercased()

        if lower.contains("iphone") || lower.contains("ipad") || lower.contains("macbook") || lower.contains("imac") || openPorts.contains(62078) {
            return "Apple"
        }
        if lower.contains("printer") || openPorts.contains(631) {
            return "Printer"
        }
        if lower.contains("router") || lower.contains("gateway") || openPorts.contains(53) {
            return "Router"
        }
        if openPorts.contains(445) {
            return "SMB Device"
        }
        if openPorts.contains(554) || openPorts.contains(8000) || openPorts.contains(8080) {
            return "Camera / Media Device"
        }
        return nil
    }
}

private nonisolated final class ResumeBox: @unchecked Sendable {
    private let lock = NSLock()
    private var resumed = false

    nonisolated func tryResume() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard !resumed else { return false }
        resumed = true
        return true
    }
}
