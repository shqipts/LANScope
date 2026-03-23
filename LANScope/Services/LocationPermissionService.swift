import Foundation
import Combine
import CoreLocation

@MainActor
final class LocationPermissionService: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = LocationPermissionService()

    private let manager = CLLocationManager()
    @Published private(set) var status: CLAuthorizationStatus

    override init() {
        self.status = manager.authorizationStatus
        super.init()
        manager.delegate = self
    }

    func requestWhenInUse() {
        manager.requestWhenInUseAuthorization()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        status = manager.authorizationStatus
    }
}
