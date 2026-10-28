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
    
    private func syncAzkarListToPeer() {
        guard WCSession.isSupported() else { return }
        guard let data = try? JSONEncoder().encode(azkarList) else { return }
        
        let payload: [String: Any] = [
            "azkarData": data,
            "currentZekr": currentZekr,
            "target": target,
            "count": currentCount
        ]
        
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(payload, replyHandler: nil, errorHandler: nil)
        }
        try? WCSession.default.updateApplicationContext(payload)
    }
    
    public func activateSession() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }
    
    // MARK: - فحص وإطلاق تنبيه اكتمال الهدف في الآيفون (حتى أثناء قفل الشاشة)
    private var lastAlertedTargetCount: Int? = nil
    
    public func checkAndTriggerTargetAlert(count: Int) {
        if count < target || count == 0 {
            lastAlertedTargetCount = nil
        } else if count == target && lastAlertedTargetCount != count {
            lastAlertedTargetCount = count
            // 1. تشغيل الصوت عالي النقاء عبر مكبر الصوت (يتخطى زر الصامت وقفل الشاشة بفضل Background Audio)
            SoundManager.shared.playFromStorage()
            // 2. إرسال إشعار فوري يضيء شاشة القفل ويعرض التهنئة بصوت وتنبيه
            NotificationManager.shared.triggerTargetNotification(zekr: currentZekr, count: count)
        }
    }
    
    /// Synchronize state changes to paired watch or phone
    public func sendSyncPayload(count: Int, zekr: String, target: Int) {
        if self.currentCount != count { self.currentCount = count }
        if self.currentZekr != zekr { self.currentZekr = zekr }
        if self.target != target { self.target = target }
        
        checkAndTriggerTargetAlert(count: count)
        
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated else {
            session.activate()
            return
        }
        guard session.isPaired, session.isWatchAppInstalled else { return }
        
        let payload: [String: Any] = [
            "count": count,
            "zekr": zekr,
            "target": target,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        // 1. المسار الفوري الحي (Real-time Messaging): عند فتح تطبيق الساعة
        if session.isReachable {
            session.sendMessage(payload, replyHandler: nil) { [weak self] error in
                print("Phone -> Watch sendMessage error: \(error.localizedDescription), falling back to transferUserInfo")
                self?.sendReliableBackgroundPayload(payload)
            }
        } else {
            // 2. المسار المضمون بالخلفية: إذا كانت شاشة الساعة خافتة أو غير مستيقظة تماماً
            sendReliableBackgroundPayload(payload)
        }
        
        // 3. تحديث سياق التطبيق العام للحفاظ على أحدث قيمة
        try? session.updateApplicationContext(payload)
    }
    
    // إرسال البيانات المضمونة في الخلفية مع إلغاء المعلق القديم لتجنب التأخير
    private func sendReliableBackgroundPayload(_ payload: [String: Any]) {
        let session = WCSession.default
        guard session.activationState == .activated, session.isPaired, session.isWatchAppInstalled else { return }
        
        // إلغاء أي نقل سابق معلق للعداد حتى تصل أحدث قيمة فوراً دون تراكم الطابور
        for transfer in session.outstandingUserInfoTransfers {
            if let dict = transfer.userInfo as? [String: Any], dict["count"] != nil {
                transfer.cancel()
            }
        }
        
        session.transferUserInfo(payload)
    }
    
    // MARK: - WCSessionDelegate
    public func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if activationState == .activated {
            DispatchQueue.global(qos: .utility).async {
                self.syncAzkarListToPeer()
            }
        }
    }
    
    public func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            print("Phone WCSession reachability changed: \(session.isReachable)")
            if session.isReachable {
                // فور اتصال الساعة الحي واستيقاظها، نرسل لها أحدث تسبيح فوراً
                self.sendSyncPayload(count: self.currentCount, zekr: self.currentZekr, target: self.target)
            }
        }
    }
    
    #if os(iOS)
    public func sessionDidBecomeInactive(_ session: WCSession) {}
    public func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }
    #endif
    
    // استقبال الرسائل التفاعلية الفورية (بدون ReplyHandler)
    public func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        handleIncomingPayload(message)
    }
    
    // استقبال الرسائل التفاعلية الفورية (مع ReplyHandler)
    public func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        handleIncomingPayload(message)
        replyHandler(["status": "ok", "currentCount": self.currentCount])
    }
    
    // استقبال البيانات عند إيقاظ الآيفون في الخلفية والشاشة مقفلة
    public func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any] = [:]) {
        handleIncomingPayload(userInfo)
    }
    
    public func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        handleIncomingPayload(applicationContext)
    }
    
    private func handleIncomingPayload(_ payload: [String: Any]) {
        DispatchQueue.main.async {
            // استجابة لطلب المزامنة القادم من الساعة فور فتحها
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
            
            // فحص إكمال الهدف وإطلاق التنبيه الصوتي فوراً حتى لو كان الآيفون مقفلاً
            self.checkAndTriggerTargetAlert(count: self.currentCount)
        }
    }
}
