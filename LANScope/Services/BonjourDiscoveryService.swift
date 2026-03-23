import Foundation

final class BonjourDiscoveryService {
    private let serviceTypes = [
        "_http._tcp.",
        "_https._tcp.",
        "_ipp._tcp.",
        "_ipps._tcp.",
        "_airplay._tcp.",
        "_googlecast._tcp.",
        "_hap._tcp.",
        "_companion-link._tcp.",
        "_printer._tcp.",
        "_workstation._tcp.",
        "_smb._tcp.",
        "_ssh._tcp.",
        "_ftp._tcp.",
        "_raop._tcp.",
        "_mediaremotetv._tcp.",
        "_spotify-connect._tcp.",
        "_eppc._tcp.",
        "_rfb._tcp."
    ]

    func discover(timeout: TimeInterval = 3.0) async -> [BonjourServiceHost] {
        await withCheckedContinuation { continuation in
            let runner = BonjourDiscoveryRunner(serviceTypes: serviceTypes, timeout: timeout) { hosts in
                continuation.resume(returning: hosts)
            }
            BonjourDiscoveryKeeper.shared.retain(runner)
            runner.onFinish = {
                BonjourDiscoveryKeeper.shared.release(runner)
            }
            runner.start()
        }
    }
}

private final class BonjourDiscoveryKeeper {
    static let shared = BonjourDiscoveryKeeper()
    private var runners: [ObjectIdentifier: BonjourDiscoveryRunner] = [:]
    private let lock = NSLock()

    func retain(_ runner: BonjourDiscoveryRunner) {
        lock.lock(); defer { lock.unlock() }
        runners[ObjectIdentifier(runner)] = runner
    }

    func release(_ runner: BonjourDiscoveryRunner) {
        lock.lock(); defer { lock.unlock() }
        runners.removeValue(forKey: ObjectIdentifier(runner))
    }
}

private final class BonjourDiscoveryRunner: NSObject, NetServiceBrowserDelegate, NetServiceDelegate {
    private let serviceTypes: [String]
    private let timeout: TimeInterval
    private let completion: ([BonjourServiceHost]) -> Void
    private var browsers: [NetServiceBrowser] = []
    private var services: [NetService] = []
    private var results = Set<BonjourServiceHost>()
    private var didFinish = false
    var onFinish: (() -> Void)?

    init(serviceTypes: [String], timeout: TimeInterval, completion: @escaping ([BonjourServiceHost]) -> Void) {
        self.serviceTypes = serviceTypes
        self.timeout = timeout
        self.completion = completion
    }

    func start() {
        for type in serviceTypes {
            let browser = NetServiceBrowser()
            browser.delegate = self
            browsers.append(browser)
            browser.searchForServices(ofType: type, inDomain: "local.")
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + timeout) { [weak self] in
            self?.finish()
        }
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        service.delegate = self
        services.append(service)
        service.resolve(withTimeout: 1.5)
    }

    func netServiceDidResolveAddress(_ sender: NetService) {
        guard let addresses = sender.addresses else { return }
        for address in addresses {
            if let ip = ipAddress(from: address), ip.contains(".") {
                results.insert(BonjourServiceHost(ipAddress: ip, hostName: sender.name, serviceType: sender.type))
            }
        }
    }

    func netService(_ sender: NetService, didNotResolve errorDict: [String : NSNumber]) {
        _ = errorDict
    }

    private func finish() {
        guard !didFinish else { return }
        didFinish = true
        browsers.forEach { $0.stop() }
        completion(results.sorted { $0.ipAddress.localizedStandardCompare($1.ipAddress) == .orderedAscending })
        onFinish?()
        onFinish = nil
    }

    private func ipAddress(from data: Data) -> String? {
        data.withUnsafeBytes { rawBuffer in
            guard let base = rawBuffer.baseAddress else { return nil }
            let sockaddrPointer = base.assumingMemoryBound(to: sockaddr.self)
            switch Int32(sockaddrPointer.pointee.sa_family) {
            case AF_INET:
                let addr = base.assumingMemoryBound(to: sockaddr_in.self)
                var ip = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
                var sinAddr = addr.pointee.sin_addr
                inet_ntop(AF_INET, &sinAddr, &ip, socklen_t(INET_ADDRSTRLEN))
                return String(cString: ip)
            case AF_INET6:
                return nil
            default:
                return nil
            }
        }
    }
}
