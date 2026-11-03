import CoreLocation
import Combine
import Foundation

/// Locks counting once the iPhone reports vehicle-level speed, then mirrors the lock to Apple Watch.
@MainActor
final class DrivingModeManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = DrivingModeManager()

    /// 20 km/h, expressed in Core Location's metres per second.
    private let lockSpeed: CLLocationSpeed = 20.0 / 3.6
    /// A small lower threshold prevents GPS speed jitter from repeatedly locking and unlocking.
    private let unlockSpeed: CLLocationSpeed = 18.0 / 3.6

    @Published private(set) var isDriving = false
    private let locationManager = CLLocationManager()
    private var releaseWorkItem: DispatchWorkItem?

    private override init() {
        super.init()
        // Safety mode is always enabled. Older versions exposed a preference; ignore it now.
        UserDefaults.standard.set(true, forKey: "fadhkuruni_driving_mode_enabled")
        isDriving = WatchSyncService.shared.isDrivingLocked
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        locationManager.distanceFilter = 10
    }

    func start() {
        startSpeedUpdates()
        // Do not leave a previously mirrored lock active forever if a fresh location is delayed.
        if isDriving { scheduleRelease(after: 8) }
    }

    private func startSpeedUpdates() {
        guard CLLocationManager.locationServicesEnabled() else { return }
        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            locationManager.startUpdatingLocation()
        default:
            break
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus == .authorizedAlways || manager.authorizationStatus == .authorizedWhenInUse {
            manager.startUpdatingLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last,
              location.horizontalAccuracy >= 0,
              location.horizontalAccuracy <= 100,
              location.speed >= 0 else { return }

        if location.speed >= lockSpeed {
            releaseWorkItem?.cancel()
            setDriving(true)
        } else if isDriving, location.speed <= unlockSpeed {
            // Return after a short confirmation below 18 km/h so GPS jitter does not flicker the lock.
            scheduleRelease(after: 3)
        }
    }

    private func scheduleRelease(after seconds: TimeInterval) {
        releaseWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.setDriving(false) }
        releaseWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: work)
    }

    private func setDriving(_ value: Bool) {
        guard isDriving != value else { return }
        isDriving = value
        WatchSyncService.shared.setDrivingLocked(value)
    }
}
