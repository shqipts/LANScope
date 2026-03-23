import Foundation

final class LANHostCacheService {
    static let shared = LANHostCacheService()

    private let defaultsKey = "LANScope.cachedHosts"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    func loadHosts() -> [LANHost] {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let hosts = try? decoder.decode([LANHost].self, from: data) else {
            return []
        }
        return hosts
    }

    func saveHosts(_ hosts: [LANHost]) {
        guard let data = try? encoder.encode(hosts) else { return }
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }
}
