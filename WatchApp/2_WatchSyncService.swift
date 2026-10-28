//
//  WatchSyncService.swift
//  Fadhkuruni (Shared WatchConnectivity Engine)
//

import Foundation
import WatchConnectivity
import Combine
import SwiftUI

public final class WatchSyncService: NSObject, ObservableObject, WCSessionDelegate {
    public static let shared = WatchSyncService()
    
    @Published public var currentCount: Int = 0
    @Published public var currentZekr: String = "سبحان الله"
    @Published public var target: Int = 33
    @Published public var azkarList: [ZekrItem] = []
    
    private let azkarStorageKey = "fadhkuruni_saved_azkar_v1"
    
    private override init() {
        super.init()
        loadSavedAzkar()
        activateSession()
    }
    
    // MARK: - Azkar Persistence & Management
    public func loadSavedAzkar() {
        if let data = UserDefaults.standard.data(forKey: azkarStorageKey),
           let decoded = try? JSONDecoder().decode([ZekrItem].self, from: data),
           !decoded.isEmpty {
            self.azkarList = decoded
        } else {
            self.azkarList = ZekrItem.builtInAzkar
            saveAzkarLocally()
        }
    }
    
    private func saveAzkarLocally() {
        if let encoded = try? JSONEncoder().encode(azkarList) {
            UserDefaults.standard.set(encoded, forKey: azkarStorageKey)
        }
    }
    
    public func addZekr(title: String, target: Int) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let newItem = ZekrItem(title: trimmed, defaultTarget: max(1, target))
        azkarList.append(newItem)
        saveAzkarLocally()
        syncAzkarListToPeer()
    }
    
    public func updateZekr(item: ZekrItem, newTitle: String, newTarget: Int) {
        guard let index = azkarList.firstIndex(where: { $0.id == item.id }) else { return }
        let trimmed = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let updated = ZekrItem(id: item.id, title: trimmed, defaultTarget: max(1, newTarget))
        azkarList[index] = updated
        if currentZekr == item.title {
            currentZekr = trimmed
            self.target = max(1, newTarget)
        }
        saveAzkarLocally()
        syncAzkarListToPeer()
    }
    
    public func deleteZekr(at offsets: IndexSet) {
        azkarList.remove(atOffsets: offsets)
        if azkarList.isEmpty {
            azkarList = ZekrItem.builtInAzkar
        }
        saveAzkarLocally()
        syncAzkarListToPeer()
    }
    
    public func deleteZekr(item: ZekrItem) {
        azkarList.removeAll(where: { $0.id == item.id })
        if azkarList.isEmpty {
            azkarList = ZekrItem.builtInAzkar
        }
        saveAzkarLocally()
        syncAzkarListToPeer()
    }
    
    public func resetToDefaultAzkar() {
        azkarList = ZekrItem.builtInAzkar
        saveAzkarLocally()
        syncAzkarListToPeer()
    }
    
    public func selectZekr(_ item: ZekrItem) {
        sendSyncPayload(count: 0, zekr: item.title, target: item.defaultTarget)
    }
    
    public func selectNextZekr() {
        guard !azkarList.isEmpty else { return }
        if let idx = azkarList.firstIndex(where: { $0.title == currentZekr }) {
            let nextIdx = (idx + 1) % azkarList.count
            selectZekr(azkarList[nextIdx])
        } else {
            selectZekr(azkarList[0])
        }
    }
    
    public func selectPreviousZekr() {
        guard !azkarList.isEmpty else { return }
        if let idx = azkarList.firstIndex(where: { $0.title == currentZekr }) {
            let prevIdx = (idx - 1 + azkarList.count) % azkarList.count
            selectZekr(azkarList[prevIdx])
        } else {
            selectZekr(azkarList[0])
        }
    }
    
    public func syncAzkarListToPeer() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated else {
            session.activate()
            return
        }
        guard let data = try? JSONEncoder().encode(azkarList) else { return }
        
        let payload: [String: Any] = [
            "azkarData": data,
            "currentZekr": currentZekr,
            "target": target,
            "count": currentCount,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        if session.isReachable {
            session.sendMessage(payload, replyHandler: nil) { [weak self] error in
                print("Watch -> Phone azkar sendMessage error: \(error.localizedDescription), falling back to transferUserInfo")
                self?.sendReliableAzkarPayload(payload)
            }
        } else {
            sendReliableAzkarPayload(payload)
        }
        try? session.updateApplicationContext(payload)
    }
    
    private func sendReliableAzkarPayload(_ payload: [String: Any]) {
        let session = WCSession.default
        guard session.activationState == .activated else { return }
        for transfer in session.outstandingUserInfoTransfers {
            if let dict = transfer.userInfo as? [String: Any], dict["azkarData"] != nil {
                transfer.cancel()
            }
        }
        session.transferUserInfo(payload)
        print("Watch: Enqueued reliable azkar transfer to phone (\(azkarList.count) items)")
    }
    
    public func activateSession() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }
    
    // MARK: - طلب المزامنة الفورية من الآيفون
    public func requestSyncFromPhone() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        if session.activationState != .activated {
            session.activate()
        }
        let pingPayload: [String: Any] = [
            "action": "requestSync",
            "timestamp": Date().timeIntervalSince1970
        ]
        if session.isReachable {
            session.sendMessage(pingPayload, replyHandler: nil) { _ in
                WCSession.default.transferUserInfo(pingPayload)
            }
        } else {
            session.transferUserInfo(pingPayload)
        }
    }
    
    /// Synchronize state changes to paired watch or phone
    public func sendSyncPayload(count: Int, zekr: String, target: Int) {
        if self.currentCount != count { self.currentCount = count }
        if self.currentZekr != zekr { self.currentZekr = zekr }
        if self.target != target { self.target = target }
        
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated else {
            session.activate()
            return
        }
        
        let payload: [String: Any] = [
            "count": count,
            "zekr": zekr,
            "target": target,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        // 1. إرسال مباشر فوري
        if session.isReachable {
            session.sendMessage(payload, replyHandler: nil) { [weak self] error in
                print("Watch -> Phone sendMessage error: \(error.localizedDescription)")
                self?.sendReliableBackgroundPayload(payload)
            }
        } else {
            sendReliableBackgroundPayload(payload)
        }
        
        // 2. تحديث سياق التطبيق
        do {
            try session.updateApplicationContext(payload)
        } catch {
            // تجاهل الخطأ عند التحديث السريع
        }
        
        // 3. إرسال فوري يوقظ الآيفون في الخلفية ويطلق الصوت عند الوصول للهدف حتى ولو كانت شاشة الآيفون مقفلة
        if count == target || count == 0 {
            session.transferUserInfo(payload)
        }
    }
    
    private func sendReliableBackgroundPayload(_ payload: [String: Any]) {
        let session = WCSession.default
        guard session.activationState == .activated else { return }
        for transfer in session.outstandingUserInfoTransfers {
            if let dict = transfer.userInfo as? [String: Any], dict["count"] != nil, dict["azkarData"] == nil {
                transfer.cancel()
            }
        }
        session.transferUserInfo(payload)
    }
    
    // MARK: - WCSessionDelegate
    public func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if activationState == .activated {
            requestSyncFromPhone()
        }
    }
    
    public func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            print("Watch WCSession reachability changed: \(session.isReachable)")
            if session.isReachable {
                self.requestSyncFromPhone()
            }
        }
    }
    
    #if os(iOS)
    public func sessionDidBecomeInactive(_ session: WCSession) {}
    public func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }
    #endif
    
    public func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        handleIncomingPayload(message)
    }
    
    public func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        handleIncomingPayload(message)
        replyHandler(["status": "ok", "currentCount": self.currentCount])
    }
    
    // استقبال البيانات عند إيقاظ التطبيق بالخلفية
    public func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any] = [:]) {
        handleIncomingPayload(userInfo)
    }
    
    public func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        handleIncomingPayload(applicationContext)
    }
    
    private func handleIncomingPayload(_ payload: [String: Any]) {
        DispatchQueue.main.async {
            if let action = payload["action"] as? String, action == "requestSync" {
                self.sendSyncPayload(count: self.currentCount, zekr: self.currentZekr, target: self.target)
                return
            }
            
            if let countVal = payload["count"] {
                if let countInt = countVal as? Int {
                    self.currentCount = countInt
                } else if let countNum = countVal as? NSNumber {
                    self.currentCount = countNum.intValue
                }
            }
            
            if let zekr = (payload["zekr"] as? String) ?? (payload["currentZekr"] as? String) {
                self.currentZekr = zekr
            }
            
            if let targetVal = payload["target"] {
                if let targetInt = targetVal as? Int {
                    self.target = targetInt
                } else if let targetNum = targetVal as? NSNumber {
                    self.target = targetNum.intValue
                }
            }
            
            if let azkarData = payload["azkarData"] as? Data,
               let decoded = try? JSONDecoder().decode([ZekrItem].self, from: azkarData),
               !decoded.isEmpty {
                self.azkarList = decoded
                self.saveAzkarLocally()
            }
        }
    }
}
