import UserNotifications

/// Serialize system writes, retaining only the newest count during a burst.
@MainActor
final class IconBadgeManager {
    static let shared = IconBadgeManager()
    private var pendingCount: Int?
    private var writing = false

    func update(count: Int) {
        pendingCount = max(0, count)
        writeNext()
    }

    private func writeNext() {
        guard !writing, let count = pendingCount else { return }
        pendingCount = nil
        writing = true
        UNUserNotificationCenter.current().setBadgeCount(count) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.writing = false
                self.writeNext()
            }
        }
    }
}
