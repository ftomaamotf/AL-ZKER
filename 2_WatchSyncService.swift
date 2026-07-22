//
//  WatchSyncService.swift
//  Fathkoroni (Shared WatchConnectivity Engine)
//

import Foundation
import WatchConnectivity
import Combine

public final class WatchSyncService: NSObject, ObservableObject, WCSessionDelegate {
    public static let shared = WatchSyncService()
    
    @Published public var currentCount: Int = 0
    @Published public var currentZekr: String = "سبحان الله"
    @Published public var target: Int = 33
    
    private override init() {
        super.init()
        activateSession()
    }
    
    public func activateSession() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }
    
    /// Synchronize state changes to paired watch or phone
    public func sendSyncPayload(count: Int, zekr: String, target: Int) {
        self.currentCount = count
        self.currentZekr = zekr
        self.target = target
        
        guard WCSession.default.isReachable else { return }
        let payload: [String: Any] = [
            "count": count,
            "zekr": zekr,
            "target": target
        ]
        WCSession.default.sendMessage(payload, replyHandler: nil, errorHandler: nil)
    }
    
    // MARK: - WCSessionDelegate
    public func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}
    public func sessionDidBecomeInactive(_ session: WCSession) {}
    public func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }
    public func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        DispatchQueue.main.async {
            if let count = message["count"] as? Int { self.currentCount = count }
            if let zekr = message["zekr"] as? String { self.currentZekr = zekr }
            if let target = message["target"] as? Int { self.target = target }
        }
    }
}
