import Foundation

final class ToolsService {
    private let scanner = LANScannerService()

    func ping(host: String) async -> PingResult {
        let start = Date()
        let ports = [80, 443, 22, 53]

        for port in ports {
            let open = await scanner.checkTCPPort(host: host, port: port, timeout: 1.0)
            if open {
                let latency = Date().timeIntervalSince(start) * 1000
                return PingResult(
                    host: host,
                    success: true,
                    latencyMs: latency.rounded(),
                    message: "Reachable via TCP port \(port)"
                )
            }
        }

        return PingResult(host: host, success: false, latencyMs: nil, message: "No TCP response on common ports")
    }

    func dnsLookup(host: String) async -> DNSLookupResult {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                var hints = addrinfo(
                    ai_flags: AI_DEFAULT,
                    ai_family: AF_UNSPEC,
                    ai_socktype: SOCK_STREAM,
                    ai_protocol: IPPROTO_TCP,
                    ai_addrlen: 0,
                    ai_canonname: nil,
                    ai_addr: nil,
                    ai_next: nil
                )

                var infoPtr: UnsafeMutablePointer<addrinfo>?
                let status = getaddrinfo(host, nil, &hints, &infoPtr)
                guard status == 0, let first = infoPtr else {
                    continuation.resume(returning: DNSLookupResult(host: host, addresses: []))
                    return
                }
                defer { freeaddrinfo(first) }

                var addresses: Set<String> = []
                for ptr in sequence(first: first, next: { $0.pointee.ai_next }) {
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    let result = getnameinfo(
                        ptr.pointee.ai_addr,
                        ptr.pointee.ai_addrlen,
                        &hostname,
                        socklen_t(hostname.count),
                        nil,
                        0,
                        NI_NUMERICHOST
                    )
                    if result == 0 {
                        addresses.insert(String(cString: hostname))
                    }
                }

                continuation.resume(returning: DNSLookupResult(host: host, addresses: addresses.sorted()))
            }
        }
    }

    func whois(query: String) async -> WhoisResult {
        let endpoints = [
            "https://rdap.org/domain/\(query)",
            "https://rdap.org/ip/\(query)"
        ]

        for endpoint in endpoints {
            guard let url = URL(string: endpoint.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? endpoint) else { continue }
            do {
                let (data, response) = try await URLSession.shared.data(from: url)
                if let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode,
                   let text = String(data: data, encoding: .utf8) {
                    return WhoisResult(query: query, rawText: text)
                }
            } catch {
                continue
            }
        }

        return WhoisResult(query: query, rawText: "WHOIS/RDAP lookup failed or returned no data.")
    }
}
