import CoreMotion
import Combine
import Foundation

/// Pauses counting while the iPhone reports automotive movement. Apple reports the
/// mode of transport, not whether the person is the driver or a passenger.
@MainActor
final class DrivingModeManager: ObservableObject {
    static let shared = DrivingModeManager()

    @Published private(set) var isDriving = false
    private let activityManager = CMMotionActivityManager()
    private var lastAutomotiveDate: Date?
    private var releaseWorkItem: DispatchWorkItem?

    private init() {
        isDriving = WatchSyncService.shared.isDrivingLocked
    }

    func start() {
        guard UserDefaults.standard.object(forKey: "fadhkuruni_driving_mode_enabled") as? Bool ?? true else { return }
        guard CMMotionActivityManager.isActivityAvailable() else { return }
        activityManager.startActivityUpdates(to: .main) { [weak self] activity in
            guard let self, let activity else { return }
            Task { @MainActor in self.handle(activity) }
        }
    }

    func setEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: "fadhkuruni_driving_mode_enabled")
        if enabled {
            start()
        } else {
            activityManager.stopActivityUpdates()
            setDriving(false)
        }
    }

    private func handle(_ activity: CMMotionActivity) {
        if activity.automotive && activity.confidence != .low {
            lastAutomotiveDate = Date()
            releaseWorkItem?.cancel()
            setDriving(true)
        } else if isDriving {
            // Keep the lock briefly so a single uncertain sample does not re-enable taps in traffic.
            releaseWorkItem?.cancel()
            let work = DispatchWorkItem { [weak self] in self?.setDriving(false) }
            releaseWorkItem = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 90, execute: work)
        }
    }

    private func setDriving(_ value: Bool) {
        guard isDriving != value else { return }
        isDriving = value
        WatchSyncService.shared.setDrivingLocked(value)
    }
}
