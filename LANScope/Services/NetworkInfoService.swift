import Foundation
import Network
import NetworkExtension
import CoreTelephony
import SystemConfiguration.CaptiveNetwork

final class NetworkInfoService {
    func fetchSnapshot() async -> NetworkSnapshot {
        async let wifi = fetchWiFiDetails()
        async let cellular = fetchCellularDetails()
        return await NetworkSnapshot(wifi: wifi, cellular: cellular)
    }

    func fetchWiFiDetails() async -> WiFiDetails {
        let localIP = Self.ipAddress(forInterfaces: ["en0"]) ?? "Unavailable"
        let subnetMask = Self.subnetMask(forInterface: "en0") ?? "Unavailable"

        var details = WiFiDetails()
        details.localIP = localIP
        details.subnetMask = subnetMask
        details.gateway = Self.estimatedGateway(from: localIP)
        details.dnsServers = Self.dnsServers()
        details.externalIP = await fetchExternalIP() ?? "Unavailable"

        let wifi = await Self.currentWiFiInfo()
        details.ssid = wifi.ssid
        details.bssid = wifi.bssid
        return details
    }

    func fetchCellularDetails() async -> CellularDetails {
        let networkInfo = CTTelephonyNetworkInfo()
        var details = CellularDetails()

        let radioTech = networkInfo.serviceCurrentRadioAccessTechnology?.values.first
        details.networkType = Self.humanReadableRadioTech(radioTech)
        details.ipAddress = Self.ipAddress(forInterfaces: ["pdp_ip0", "pdp_ip1", "pdp_ip2", "pdp_ip3"]) ?? "Unavailable"
        details.isConnected = details.ipAddress != "Unavailable"
        details.note = "Carrier and SIM metadata are heavily limited/deprecated on modern iOS."

        return details
    }

    private func fetchExternalIP() async -> String? {
        guard let url = URL(string: "https://api.ipify.org") else { return nil }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            return nil
        }
    }

    static func estimatedGateway(from ip: String) -> String {
        let comps = ip.split(separator: ".")
        guard comps.count == 4 else { return "Unavailable" }
        return comps.prefix(3).joined(separator: ".") + ".1"
    }

    static func dnsServers() -> [String] {
        ["System Default"]
    }

    static func currentWiFiInfo() async -> (ssid: String, bssid: String) {
        if #available(iOS 14.0, *) {
            if let current = await NEHotspotNetwork.fetchCurrent() {
                return (current.ssid, current.bssid)
            }
        }

        guard let interfaces = CNCopySupportedInterfaces() as? [String] else {
            return ("Unavailable", "Unavailable")
        }

        for interface in interfaces {
            guard let info = CNCopyCurrentNetworkInfo(interface as CFString) as? [String: Any] else { continue }
            let ssid = (info[kCNNetworkInfoKeySSID as String] as? String) ?? "Unavailable"
            let bssid = (info[kCNNetworkInfoKeyBSSID as String] as? String) ?? "Unavailable"
            return (ssid, bssid)
        }

        return ("Unavailable", "Unavailable")
    }

    static func ipAddress(forInterfaces interfaceNames: [String]) -> String? {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?

        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else { return nil }
        defer { freeifaddrs(ifaddr) }

        for pointer in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let interface = pointer.pointee
            let addrFamily = interface.ifa_addr.pointee.sa_family
            let name = String(cString: interface.ifa_name)

            guard addrFamily == UInt8(AF_INET), interfaceNames.contains(name) else { continue }

            var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            let result = getnameinfo(
                interface.ifa_addr,
                socklen_t(interface.ifa_addr.pointee.sa_len),
                &hostname,
                socklen_t(hostname.count),
                nil,
                socklen_t(0),
                NI_NUMERICHOST
            )

            if result == 0 {
                address = String(cString: hostname)
                break
            }
        }

        return address
    }

    static func subnetMask(forInterface interfaceName: String) -> String? {
        var mask: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?

        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else { return nil }
        defer { freeifaddrs(ifaddr) }

        for pointer in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let interface = pointer.pointee
            let addrFamily = interface.ifa_addr.pointee.sa_family
            let name = String(cString: interface.ifa_name)

            guard addrFamily == UInt8(AF_INET), name == interfaceName, let netmask = interface.ifa_netmask else { continue }

            var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            let result = getnameinfo(
                netmask,
                socklen_t(netmask.pointee.sa_len),
                &hostname,
                socklen_t(hostname.count),
                nil,
                socklen_t(0),
                NI_NUMERICHOST
            )

            if result == 0 {
                mask = String(cString: hostname)
                break
            }
        }

        return mask
    }

    static func humanReadableRadioTech(_ value: String?) -> String {
        guard let value else { return "Unknown" }
        switch value {
        case CTRadioAccessTechnologyNR, CTRadioAccessTechnologyNRNSA:
            return "5G"
        case CTRadioAccessTechnologyLTE:
            return "LTE"
        case CTRadioAccessTechnologyWCDMA, CTRadioAccessTechnologyHSDPA, CTRadioAccessTechnologyHSUPA:
            return "3G"
        case CTRadioAccessTechnologyEdge:
            return "EDGE"
        case CTRadioAccessTechnologyGPRS:
            return "GPRS"
        case CTRadioAccessTechnologyCDMA1x, CTRadioAccessTechnologyCDMAEVDORev0, CTRadioAccessTechnologyCDMAEVDORevA, CTRadioAccessTechnologyCDMAEVDORevB, CTRadioAccessTechnologyeHRPD:
            return "CDMA"
        default:
            return value
        }
    }
}
