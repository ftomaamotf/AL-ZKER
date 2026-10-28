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
    private let currentZekrStorageKey = "fadhkuruni_current_zekr_v1"
    
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
        
        // استعادة الذكر المحفوظ والعدد الخاص به
        let savedZekrTitle = UserDefaults.standard.string(forKey: currentZekrStorageKey)
        if let title = savedZekrTitle, let activeItem = azkarList.first(where: { $0.title == title }) {
            self.currentZekr = activeItem.title
            self.currentCount = activeItem.count
            self.target = activeItem.defaultTarget
        } else if let firstItem = azkarList.first {
            self.currentZekr = firstItem.title
            self.currentCount = firstItem.count
            self.target = firstItem.defaultTarget
        }
    }
    
    public func saveAzkarLocally() {
        if let encoded = try? JSONEncoder().encode(azkarList) {
            UserDefaults.standard.set(encoded, forKey: azkarStorageKey)
        }
    }
    
    public func addZekr(title: String, target: Int) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let newItem = ZekrItem(title: trimmed, defaultTarget: max(1, target), count: 0)
        azkarList.append(newItem)
        saveAzkarLocally()
        syncAzkarListToPeer()
    }
    
    public func updateZekr(item: ZekrItem, newTitle: String, newTarget: Int) {
        guard let index = azkarList.firstIndex(where: { $0.id == item.id }) else { return }
        let trimmed = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let currentItemCount = azkarList[index].count
        let updated = ZekrItem(id: item.id, title: trimmed, defaultTarget: max(1, newTarget), count: currentItemCount)
        azkarList[index] = updated
        if currentZekr == item.title {
            currentZekr = trimmed
            self.target = max(1, newTarget)
            UserDefaults.standard.set(trimmed, forKey: currentZekrStorageKey)
        }
        saveAzkarLocally()
        syncAzkarListToPeer()
    }
    
    public func deleteZekr(at offsets: IndexSet) {
        azkarList.remove(atOffsets: offsets)
        if azkarList.isEmpty {
            azkarList = ZekrItem.builtInAzkar
        }
        if !azkarList.contains(where: { $0.title == currentZekr }), let first = azkarList.first {
            currentZekr = first.title
            currentCount = first.count
            target = first.defaultTarget
            UserDefaults.standard.set(first.title, forKey: currentZekrStorageKey)
        }
        saveAzkarLocally()
        syncAzkarListToPeer()
    }
    
    public func deleteZekr(item: ZekrItem) {
        azkarList.removeAll(where: { $0.id == item.id })
        if azkarList.isEmpty {
            azkarList = ZekrItem.builtInAzkar
        }
        if !azkarList.contains(where: { $0.title == currentZekr }), let first = azkarList.first {
            currentZekr = first.title
            currentCount = first.count
            target = first.defaultTarget
            UserDefaults.standard.set(first.title, forKey: currentZekrStorageKey)
        }
        saveAzkarLocally()
        syncAzkarListToPeer()
    }
    
    public func resetToDefaultAzkar() {
        azkarList = ZekrItem.builtInAzkar
        if let first = azkarList.first {
            currentZekr = first.title
            currentCount = first.count
            target = first.defaultTarget
            UserDefaults.standard.set(first.title, forKey: currentZekrStorageKey)
        }
        saveAzkarLocally()
        syncAzkarListToPeer()
    }
    
    // MARK: - اختيار الذكر مع الاحتفاظ بعدد كل ذكر على حدة
    public func selectZekr(_ item: ZekrItem) {
        // 1. حفظ عدد الذكر الحالي في القائمة محلياً قبل التبديل
        if let currentIdx = azkarList.firstIndex(where: { $0.title == currentZekr }) {
            azkarList[currentIdx].count = currentCount
            azkarList[currentIdx].defaultTarget = target
        }
        
        // 2. استرجاع العدد المحفوظ للذكر المختار الجديد
        let savedCount: Int
        let targetCount: Int
        if let targetIdx = azkarList.firstIndex(where: { $0.id == item.id || $0.title == item.title }) {
            savedCount = azkarList[targetIdx].count
            targetCount = azkarList[targetIdx].defaultTarget
        } else {
            savedCount = item.count
            targetCount = item.defaultTarget
        }
        
        self.currentZekr = item.title
        self.currentCount = savedCount
        self.target = targetCount
        UserDefaults.standard.set(item.title, forKey: currentZekrStorageKey)
        
        // منع إطلاق التنبيه الصوتي فور التبديل إذا كان الذكر قد وصل هدفه مسبقاً
        if savedCount >= targetCount && targetCount > 0 {
            lastAlertedTargetCount = savedCount
        } else {
            lastAlertedTargetCount = nil
        }
        
        saveAzkarLocally()
        sendSyncPayload(count: savedCount, zekr: item.title, target: targetCount)
        syncAzkarListToPeer()
    }
    
    // MARK: - تصفير عداد الذكر الحالي فقط (حصرياً من واجهة تطبيق الآيفون)
    public func resetCurrentZekrCount() {
        self.currentCount = 0
        if let idx = azkarList.firstIndex(where: { $0.title == currentZekr }) {
            azkarList[idx].count = 0
        }
        lastAlertedTargetCount = nil
        saveAzkarLocally()
        sendSyncPayload(count: 0, zekr: currentZekr, target: target)
        syncAzkarListToPeer()
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
        guard session.isPaired, session.isWatchAppInstalled else { return }
        
        // التأكد من تضمين أحدث عداد للذكر الحالي قبل الإرسال
        if let idx = azkarList.firstIndex(where: { $0.title == currentZekr }) {
            azkarList[idx].count = currentCount
            azkarList[idx].defaultTarget = target
        }
        
        guard let data = try? JSONEncoder().encode(azkarList) else { return }
        
        let payload: [String: Any] = [
            "azkarData": data,
            "currentZekr": currentZekr,
            "target": target,
            "count": currentCount,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        // 1. المسار الفوري الحي: عند فتح تطبيق الساعة
        if session.isReachable {
            session.sendMessage(payload, replyHandler: nil) { [weak self] error in
                print("Phone -> Watch azkar sendMessage error: \(error.localizedDescription), falling back to transferUserInfo")
                self?.sendReliableAzkarPayload(payload)
            }
        } else {
            // 2. المسار المضمون بالخلفية
            sendReliableAzkarPayload(payload)
        }
        
        // 3. تحديث سياق التطبيق العام
        try? session.updateApplicationContext(payload)
    }
    
    private func sendReliableAzkarPayload(_ payload: [String: Any]) {
        let session = WCSession.default
        guard session.activationState == .activated, session.isPaired, session.isWatchAppInstalled else { return }
        
        for transfer in session.outstandingUserInfoTransfers {
            if let dict = transfer.userInfo as? [String: Any], dict["azkarData"] != nil {
                transfer.cancel()
            }
        }
        
        session.transferUserInfo(payload)
        print("Phone: Enqueued reliable azkar transfer to watch (\(azkarList.count) items)")
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
        
        // تحديث عدد الذكر الحالي في القائمة المحلية فوراً
        if let idx = azkarList.firstIndex(where: { $0.title == zekr }) {
            if azkarList[idx].count != count || azkarList[idx].defaultTarget != target {
                azkarList[idx].count = count
                azkarList[idx].defaultTarget = target
                saveAzkarLocally()
            }
        }
        
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
            // 2. المسار المضمون بالخلفية
            sendReliableBackgroundPayload(payload)
        }
        
        // 3. تحديث سياق التطبيق العام للحفاظ على أحدث قيمة
        try? session.updateApplicationContext(payload)
    }
    
    private func sendReliableBackgroundPayload(_ payload: [String: Any]) {
        let session = WCSession.default
        guard session.activationState == .activated, session.isPaired, session.isWatchAppInstalled else { return }
        
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
            DispatchQueue.global(qos: .utility).async {
                self.syncAzkarListToPeer()
            }
        }
    }
    
    public func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            print("Phone WCSession reachability changed: \(session.isReachable)")
            if session.isReachable {
                self.sendSyncPayload(count: self.currentCount, zekr: self.currentZekr, target: self.target)
                self.syncAzkarListToPeer()
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
                self.syncAzkarListToPeer()
                return
            }
            
            // 1. استقبال وتحديث قائمة الأذكار إن وجدت
            if let azkarData = payload["azkarData"] as? Data,
               let decoded = try? JSONDecoder().decode([ZekrItem].self, from: azkarData),
               !decoded.isEmpty {
                self.azkarList = decoded
                self.saveAzkarLocally()
            }
            
            // 2. تحديث الذكر الحالي
            if let zekr = (payload["zekr"] as? String) ?? (payload["currentZekr"] as? String) {
                self.currentZekr = zekr
                UserDefaults.standard.set(zekr, forKey: self.currentZekrStorageKey)
            }
            
            // 3. تحديث الهدف
            if let targetVal = payload["target"] {
                if let targetInt = targetVal as? Int {
                    self.target = targetInt
                } else if let targetNum = targetVal as? NSNumber {
                    self.target = targetNum.intValue
                }
            }
            
            // 4. تحديث العداد
            if let countVal = payload["count"] {
                if let countInt = countVal as? Int {
                    self.currentCount = countInt
                } else if let countNum = countVal as? NSNumber {
                    self.currentCount = countNum.intValue
                }
            } else if let activeItem = self.azkarList.first(where: { $0.title == self.currentZekr }) {
                self.currentCount = activeItem.count
            }
            
            // 5. مزامنة عدد الذكر الحالي في azkarList
            if let idx = self.azkarList.firstIndex(where: { $0.title == self.currentZekr }) {
                self.azkarList[idx].count = self.currentCount
                self.azkarList[idx].defaultTarget = self.target
                self.saveAzkarLocally()
            }
            
            // فحص إكمال الهدف وإطلاق التنبيه الصوتي فوراً حتى لو كان الآيفون مقفلاً
            self.checkAndTriggerTargetAlert(count: self.currentCount)
        }
    }
}
