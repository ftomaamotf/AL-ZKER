import Foundation
import WatchKit

/// Keeps the counting session frontmost while active; watchOS controls screen brightness.
final class WatchKeepAwakeManager: NSObject, WKExtendedRuntimeSessionDelegate {
    static let shared = WatchKeepAwakeManager()
    static let inactivityInterval: TimeInterval = 5 * 60

    private var session: WKExtendedRuntimeSession?
    private var inactivityTimer: Timer?
    private var inactivityDeadline: TimeInterval?
    private var mayResumeSession = true
    private let uptime: () -> TimeInterval

    init(uptime: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }) {
        self.uptime = uptime
        super.init()
    }

    func beginCountingSession() {
        if inactivityDeadline == nil {
            recordCountingActivity()
        } else {
            resumeCountingSession()
        }
    }

    /// Called for local touch and Double Tap actions, never for counts received from iPhone.
    func recordCountingActivity() {
        inactivityDeadline = uptime() + Self.inactivityInterval
        mayResumeSession = true
        scheduleInactivityCheck()
        startSessionIfAllowed()
    }

    /// Raising the wrist must not extend the deadline without a new tasbih action.
    func resumeCountingSession() {
        guard inactivityDeadline != nil else { return }
        checkForInactivity()
        guard inactivityDeadline != nil else { return }
        startSessionIfAllowed()
    }

    func checkForInactivity() {
        guard let deadline = inactivityDeadline else { return }
        if uptime() >= deadline {
            stopKeepAwake()
        } else {
            scheduleInactivityCheck()
        }
    }

    func stopKeepAwake() {
        inactivityTimer?.invalidate()
        inactivityTimer = nil
        inactivityDeadline = nil
        // Clear the reference before invalidating: an old delegate callback must not clear a newer session.
        let previousSession = session
        session = nil
        if let previousSession, previousSession.state != .invalid {
            previousSession.invalidate()
        }
    }

    private func scheduleInactivityCheck() {
        inactivityTimer?.invalidate()
        guard let deadline = inactivityDeadline else { return }
        let remaining = max(0.01, deadline - uptime())
        let timer = Timer(timeInterval: remaining, repeats: false) { [weak self] _ in
            self?.checkForInactivity()
        }
        inactivityTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func startSessionIfAllowed() {
        guard mayResumeSession, inactivityDeadline != nil,
              WKApplication.shared().applicationState == .active else { return }
        if let session, session.state != .invalid { return }
        let newSession = WKExtendedRuntimeSession()
        newSession.delegate = self
        session = newSession
        newSession.start()
    }

    func extendedRuntimeSessionDidStart(_ extendedRuntimeSession: WKExtendedRuntimeSession) {
        guard session === extendedRuntimeSession else { return }
        checkForInactivity()
    }

    func extendedRuntimeSessionWillExpire(_ extendedRuntimeSession: WKExtendedRuntimeSession) {
        // Respect the system's session limit; never automatically loop sessions on expiry.
        guard session === extendedRuntimeSession else { return }
        mayResumeSession = false
    }

    func extendedRuntimeSession(_ extendedRuntimeSession: WKExtendedRuntimeSession,
                                didInvalidateWith reason: WKExtendedRuntimeSessionInvalidationReason,
                                error: Error?) {
        guard session === extendedRuntimeSession else { return }
        session = nil
        if reason == .expired { mayResumeSession = false }
    }
}
