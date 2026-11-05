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
    private var watchdogTimer: Timer?
    private var lastHighSpeedTime: Date = .distantPast
    private var lastManualUnlockTime: Date = .distantPast

    private override init() {
        super.init()
        // Safety mode is always enabled. Older versions exposed a preference; ignore it now.
        UserDefaults.standard.set(true, forKey: "fadhkuruni_driving_mode_enabled")
        isDriving = WatchSyncService.shared.isDrivingLocked
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        locationManager.distanceFilter = kCLDistanceFilterNone
        locationManager.activityType = .automotiveNavigation
    }

    func start() {
        startSpeedUpdates()
        // Do not leave a previously mirrored lock active forever if a fresh location is delayed.
        if isDriving { scheduleRelease(after: 4.0) }
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
        guard let location = locations.last else { return }
        if location.horizontalAccuracy < 0 || location.horizontalAccuracy > 150 { return }

        // إذا قام المستخدم بتأكيد الوقوف مؤخراً، لا نعيد القفل إلا إذا تجاوزت السرعة فعلياً حد القيادة
        let timeSinceManual = Date().timeIntervalSince(lastManualUnlockTime)
        if timeSinceManual < 6.0 && location.speed < lockSpeed {
            return
        }

        if location.speed >= lockSpeed {
            lastHighSpeedTime = Date()
            releaseWorkItem?.cancel()
            setDriving(true)
            startWatchdog()
        } else if isDriving {
            // عند انخفاض السرعة أو توقف السيارة تماماً (حيث ترجع منظومة GPS سرعة -1 أو أقل من unlockSpeed)
            if location.speed >= 0 && location.speed <= unlockSpeed {
                let confirmationTime: TimeInterval = (location.speed <= 0.8) ? 1.0 : 1.8
                scheduleRelease(after: confirmationTime)
            } else if location.speed < 0 {
                // سرعة غير صالحة تعني توقف تام للمركبة وعدم وجود إزاحة Doppler
                scheduleRelease(after: 1.5)
            }
        }
    }

    /// فاحص دوري للتأكد من فك القفل تلقائياً عند توقف السيارة حتى لو تأخرت تحديثات الـ GPS من النظام
    private func startWatchdog() {
        watchdogTimer?.invalidate()
        watchdogTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self, self.isDriving else { return }
                let elapsed = Date().timeIntervalSince(self.lastHighSpeedTime)
                if elapsed >= 5.0 {
                    if let cur = self.locationManager.location {
                        if cur.speed < self.lockSpeed {
                            self.scheduleRelease(after: 1.0)
                        }
                    } else {
                        self.scheduleRelease(after: 1.0)
                    }
                }
            }
        }
    }

    private func stopWatchdog() {
        watchdogTimer?.invalidate()
        watchdogTimer = nil
    }

    private func scheduleRelease(after seconds: TimeInterval) {
        releaseWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            self.setDriving(false)
            self.stopWatchdog()
        }
        releaseWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: work)
    }

    /// زر "تأكيد الوقوف" اليدوي: فك القفل فوراً وإعلام الساعة
    func confirmStopped() {
        lastManualUnlockTime = Date()
        releaseWorkItem?.cancel()
        stopWatchdog()
        isDriving = false
        WatchSyncService.shared.setDrivingLocked(false)
    }

    private func setDriving(_ value: Bool) {
        guard isDriving != value else { return }
        isDriving = value
        WatchSyncService.shared.setDrivingLocked(value)
    }
}
