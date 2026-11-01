import CoreMotion
import CoreLocation
import Combine
import Foundation

/// Locks counting while the iPhone reports movement, and unlocks again only after stillness.
@MainActor
final class DrivingModeManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = DrivingModeManager()

    @Published private(set) var isDriving = false
    private let activityManager = CMMotionActivityManager()
    private let locationManager = CLLocationManager()
    private var releaseWorkItem: DispatchWorkItem?

    private override init() {
        super.init()
        // Safety mode is always enabled. Older versions exposed a preference; ignore it now.
        UserDefaults.standard.set(true, forKey: "fadhkuruni_driving_mode_enabled")
        isDriving = WatchSyncService.shared.isDrivingLocked
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        locationManager.distanceFilter = 20
    }

    func start() {
        if CMMotionActivityManager.isActivityAvailable() {
            activityManager.startActivityUpdates(to: .main) { [weak self] activity in
                guard let self, let activity else { return }
                Task { @MainActor in self.handle(activity) }
            }
        }
        startSpeedUpdates()
        // Motion classifications can remain active briefly after stopping.
        // Do not leave the app locked forever when no new movement evidence arrives.
        if isDriving { scheduleRelease(after: 8) }
    }

    private func handle(_ activity: CMMotionActivity) {
        // Safety lock is reserved for vehicle travel only.
        let isMoving = activity.automotive
        if isMoving && activity.confidence != .low {
            releaseWorkItem?.cancel()
            setDriving(true)
        } else if isDriving, activity.stationary {
            // The motion system explicitly confirmed stillness; return promptly on both devices.
            scheduleRelease(after: 3)
        } else if isDriving {
            scheduleRelease(after: 8)
        }
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
              location.horizontalAccuracy <= 100 else { return }

        if location.speed >= 3.5 { // about 13 km/h, avoids walking and normal GPS drift.
            releaseWorkItem?.cancel()
            setDriving(true)
        } else if isDriving, location.speed >= 0, location.speed < 1.0 {
            // A confirmed near-zero GPS speed is the quickest reliable signal that the car stopped.
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
