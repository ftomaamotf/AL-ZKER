//
//  WatchSyncService.swift
//  Fadhkuruni (Shared WatchConnectivity Engine)
//

import Foundation
import WatchConnectivity
import Combine
import SwiftUI

struct WatchPrayerScheduleEntry: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let symbol: String
    let date: Date
}

public final class WatchSyncService: NSObject, ObservableObject, WCSessionDelegate {
    public static let shared = WatchSyncService()

    /// Mirrored from the iPhone when vehicle movement is detected.
    @Published public private(set) var isDrivingLocked = UserDefaults.standard.bool(forKey: "fadhkuruni_driving_locked")

    public func setDrivingLocked(_ value: Bool) {
        guard isDrivingLocked != value else { return }
        isDrivingLocked = value
        UserDefaults.standard.set(value, forKey: "fadhkuruni_driving_locked")
        sendSyncPayload(count: currentCount, zekr: currentZekr, target: target)
    }

    /// فك القفل يدوياً من زر "تأكيد الوقوف" على الساعة وإعلام الآيفون فوراً
    public func confirmStopped() {
        isDrivingLocked = false
        UserDefaults.standard.set(false, forKey: "fadhkuruni_driving_locked")
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated else {
            session.activate()
            return
        }
        let payload: [String: Any] = [
            "action": "confirmStopped",
            "drivingLocked": false,
            "timestamp": Date().timeIntervalSince1970
        ]
        if session.isReachable {
            session.sendMessage(payload, replyHandler: nil, errorHandler: { _ in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    if session.isReachable {
                        session.sendMessage(payload, replyHandler: nil, errorHandler: nil)
                    }
                }
            })
        }
        try? session.updateApplicationContext(payload)
    }

    private func applyDrivingLock(_ payload: [String: Any]) {
        guard let value = payload["drivingLocked"] as? Bool else { return }
        isDrivingLocked = value
        UserDefaults.standard.set(value, forKey: "fadhkuruni_driving_locked")
    }

    @Published public private(set) var showsDecrementButton = UserDefaults.standard.object(forKey: "watchMinusVisible") as? Bool ?? true
    private var minusTime: Double { UserDefaults.standard.double(forKey: "watchMinusTime") }
    private var minusOrigin: String { UserDefaults.standard.string(forKey: "watchMinusOrigin") ?? "" }
    public func setShowsDecrementButton(_ value: Bool) {
        showsDecrementButton = value
        UserDefaults.standard.set(value, forKey: "watchMinusVisible")
        UserDefaults.standard.set(max(Date().timeIntervalSince1970, minusTime.nextUp), forKey: "watchMinusTime")
        UserDefaults.standard.set(deviceOrigin, forKey: "watchMinusOrigin")
        sendSyncPayload(count: currentCount, zekr: currentZekr, target: target)
    }
    private func applyMinusPreference(_ payload: [String: Any]) {
        guard let value = payload["watchMinusVisible"] as? Bool,
              let time = payload["watchMinusTime"] as? Double, time.isFinite, time > 0,
              let origin = payload["watchMinusOrigin"] as? String,
              time > minusTime || (time == minusTime && origin > minusOrigin) else { return }
        showsDecrementButton = value
        UserDefaults.standard.set(value, forKey: "watchMinusVisible")
        UserDefaults.standard.set(time, forKey: "watchMinusTime")
        UserDefaults.standard.set(origin, forKey: "watchMinusOrigin")
    }

    @Published public private(set) var showsResetButton = UserDefaults.standard.object(forKey: "watchResetVisible") as? Bool ?? true
    private var resetVisibilityTime: Double { UserDefaults.standard.double(forKey: "watchResetTime") }
    private var resetVisibilityOrigin: String { UserDefaults.standard.string(forKey: "watchResetOrigin") ?? "" }
    public func setShowsResetButton(_ value: Bool) {
        showsResetButton = value
        UserDefaults.standard.set(value, forKey: "watchResetVisible")
        UserDefaults.standard.set(max(Date().timeIntervalSince1970, resetVisibilityTime.nextUp), forKey: "watchResetTime")
        UserDefaults.standard.set(deviceOrigin, forKey: "watchResetOrigin")
        sendSyncPayload(count: currentCount, zekr: currentZekr, target: target)
    }
    private func applyResetPreference(_ payload: [String: Any]) {
        guard let value = payload["watchResetVisible"] as? Bool,
              let time = payload["watchResetTime"] as? Double, time.isFinite, time > 0,
              let origin = payload["watchResetOrigin"] as? String,
              time > resetVisibilityTime || (time == resetVisibilityTime && origin > resetVisibilityOrigin) else { return }
        showsResetButton = value
        UserDefaults.standard.set(value, forKey: "watchResetVisible")
        UserDefaults.standard.set(time, forKey: "watchResetTime")
        UserDefaults.standard.set(origin, forKey: "watchResetOrigin")
    }

    /// Mirrored from the iPhone to replace the displayed counter number with time.
    @Published public private(set) var showsWatchClockCover = UserDefaults.standard.object(forKey: "watchClockCover") as? Bool ?? false
    private var clockCoverTime: Double { UserDefaults.standard.double(forKey: "watchClockCoverTime") }
    private var clockCoverOrigin: String { UserDefaults.standard.string(forKey: "watchClockCoverOrigin") ?? "" }
    public func setWatchClockCover(_ value: Bool) {
        showsWatchClockCover = value
        UserDefaults.standard.set(value, forKey: "watchClockCover")
        UserDefaults.standard.set(max(Date().timeIntervalSince1970, clockCoverTime.nextUp), forKey: "watchClockCoverTime")
        UserDefaults.standard.set(deviceOrigin, forKey: "watchClockCoverOrigin")
        sendSyncPayload(count: currentCount, zekr: currentZekr, target: target)
    }
    private func applyClockCoverPreference(_ payload: [String: Any]) {
        guard let value = payload["watchClockCover"] as? Bool,
              let time = payload["watchClockCoverTime"] as? Double, time.isFinite, time > 0,
              let origin = payload["watchClockCoverOrigin"] as? String else { return }
        // This preference is controlled by the iPhone. Do not reject a current
        // phone command because the Watch retained an older future timestamp.
        showsWatchClockCover = value
        UserDefaults.standard.set(value, forKey: "watchClockCover")
        UserDefaults.standard.set(time, forKey: "watchClockCoverTime")
        UserDefaults.standard.set(origin, forKey: "watchClockCoverOrigin")
    }

    @Published public private(set) var watchClockPhotoData = UserDefaults.standard.data(forKey: "watchClockPhotoData")
    private var watchClockPhotoTime: Double { UserDefaults.standard.double(forKey: "watchClockPhotoTime") }
    private var watchClockPhotoOrigin: String { UserDefaults.standard.string(forKey: "watchClockPhotoOrigin") ?? "" }
    public func setWatchClockPhoto(_ data: Data) {
        watchClockPhotoData = data
        UserDefaults.standard.set(data, forKey: "watchClockPhotoData")
        UserDefaults.standard.set(max(Date().timeIntervalSince1970, watchClockPhotoTime.nextUp), forKey: "watchClockPhotoTime")
        UserDefaults.standard.set(deviceOrigin, forKey: "watchClockPhotoOrigin")
        sendWatchClockPhotoFile()
        sendSyncPayload(count: currentCount, zekr: currentZekr, target: target)
    }
    private func sendWatchClockPhotoFile() {
        guard WCSession.isSupported(), let data = watchClockPhotoData,
              watchClockPhotoTime > 0 else { return }
        let session = WCSession.default
        guard session.activationState == .activated else { return }
        let metadata: [String: Any] = [
            "kind": "watchClockPhoto",
            "watchClockPhotoTime": watchClockPhotoTime,
            "watchClockPhotoOrigin": watchClockPhotoOrigin
        ]
        guard !session.outstandingFileTransfers.contains(where: {
            $0.file.metadata?["kind"] as? String == "watchClockPhoto"
                && $0.file.metadata?["watchClockPhotoTime"] as? Double == watchClockPhotoTime
                && $0.file.metadata?["watchClockPhotoOrigin"] as? String == watchClockPhotoOrigin
        }) else { return }
        do {
            let directory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("WatchPhotoTransfers", isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let url = directory.appendingPathComponent(UUID().uuidString).appendingPathExtension("jpg")
            try data.write(to: url, options: .atomic)
            session.transferFile(url, metadata: metadata)
        } catch {
            print("Watch photo file preparation failed: \(error.localizedDescription)")
        }
    }

    public func session(_ session: WCSession, didReceive file: WCSessionFile) {
        guard var payload = file.metadata,
              payload["kind"] as? String == "watchClockPhoto" else { return }
        // Read before returning: WatchConnectivity owns the temporary received URL.
        do {
            payload["watchClockPhotoData"] = try Data(contentsOf: file.fileURL)
            DispatchQueue.main.async { self.applyWatchClockPhoto(payload) }
        } catch {
            print("Watch photo file read failed: \(error.localizedDescription)")
        }
    }

    public func session(_ session: WCSession, didFinish fileTransfer: WCSessionFileTransfer, error: Error?) {
        guard fileTransfer.file.metadata?["kind"] as? String == "watchClockPhoto" else { return }
        if let error { print("Watch photo transfer failed: \(error.localizedDescription)") }
        try? FileManager.default.removeItem(at: fileTransfer.file.fileURL)
    }

    private func applyWatchClockPhoto(_ payload: [String: Any]) {
        guard let data = payload["watchClockPhotoData"] as? Data,
              let time = payload["watchClockPhotoTime"] as? Double, time.isFinite, time > 0,
              let origin = payload["watchClockPhotoOrigin"] as? String,
              time > watchClockPhotoTime || (time == watchClockPhotoTime && origin > watchClockPhotoOrigin) else { return }
        watchClockPhotoData = data
        UserDefaults.standard.set(data, forKey: "watchClockPhotoData")
        UserDefaults.standard.set(time, forKey: "watchClockPhotoTime")
        UserDefaults.standard.set(origin, forKey: "watchClockPhotoOrigin")
    }

    @Published public var currentCount: Int = 0
    @Published public var currentZekr: String = "سبحان الله"
    @Published public var target: Int = 33
    @Published public var azkarList: [ZekrItem] = []
    @Published public private(set) var statistics = DhikrStatisticsLedger()
    @Published private(set) var prayerTimes: [WatchPrayerScheduleEntry] = []

    private func traceSync(_ text: String) {
        #if DEBUG
        let line = "\(Date().timeIntervalSince1970) \(text)\n"
        let url = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("connectivity-debug.log")
        var log = (try? Data(contentsOf: url)) ?? Data()
        if log.count > 24000 { log = Data() }
        log.append(Data(line.utf8))
        try? log.write(to: url, options: .atomic)
        #endif
    }

    private var ledger = DhikrLedger()
    private var previousItems: [ZekrItem] = []
    private var applyingLedger = false
    private var ledgerReady = false
    private let ledgerKey = "fadhkuruni_merge_ledger_v2"
    private var encodedAzkarSnapshot: Data?
    private let azkarStorageKey = "fadhkuruni_saved_azkar_v1"
    private let currentZekrStorageKey = "fadhkuruni_current_zekr_v1"
    private let statisticsStorageKey = "fadhkuruni_statistics_v1"
    private let prayerTimesStorageKey = "fadhkuruni_watch_prayer_times_v1"
    private let statisticsResetTimeKey = "fadhkuruni_statistics_reset_time_v1"
    private let statisticsDhikrClearTimesKey = "fadhkuruni_statistics_dhikr_clear_times_v1"
    private var statisticsResetTime: Double { UserDefaults.standard.double(forKey: statisticsResetTimeKey) }
    private var statisticsDhikrClearTimes: [String: Double] = [:]

    private let revisionTimeKey = "fadhkuruni_sync_revision_time"
    private let revisionOriginKey = "fadhkuruni_sync_revision_origin"
    private let deviceOriginKey = "fadhkuruni_sync_device_origin"
    private lazy var deviceOrigin: String = {
        if let saved = UserDefaults.standard.string(forKey: deviceOriginKey) { return saved }
        let value = UUID().uuidString
        UserDefaults.standard.set(value, forKey: deviceOriginKey)
        return value
    }()
    private var revision: SyncRevision {
        SyncRevision(timestamp: UserDefaults.standard.double(forKey: revisionTimeKey),
                     origin: UserDefaults.standard.string(forKey: revisionOriginKey) ?? "")
    }
    private func storeRevision(_ value: SyncRevision) {
        UserDefaults.standard.set(value.timestamp, forKey: revisionTimeKey)
        UserDefaults.standard.set(value.origin, forKey: revisionOriginKey)
    }
    private func makeSnapshot() -> [String: Any] {
        var payload: [String: Any] = ["count": currentCount, "zekr": currentZekr,
            "currentZekr": currentZekr, "target": target,
            "timestamp": revision.timestamp, "origin": revision.origin]
        if let data = encodedAzkarSnapshot ?? (try? JSONEncoder().encode(azkarList)) {
            payload["azkarData"] = data
        }
        payload["ledgerV2"] = try? JSONEncoder().encode(ledger)
        payload["statisticsV1"] = try? JSONEncoder().encode(statistics)
        payload["statisticsResetTime"] = statisticsResetTime
        payload["statisticsDhikrClearTimesV1"] = try? JSONEncoder().encode(statisticsDhikrClearTimes)
        payload["watchMinusVisible"] = showsDecrementButton
        payload["watchMinusTime"] = minusTime
        payload["watchMinusOrigin"] = minusOrigin
        payload["watchResetVisible"] = showsResetButton
        payload["watchResetTime"] = resetVisibilityTime
        payload["watchResetOrigin"] = resetVisibilityOrigin
        payload["watchClockCover"] = showsWatchClockCover
        payload["watchClockCoverTime"] = clockCoverTime
        payload["watchClockCoverOrigin"] = clockCoverOrigin
        // Photos travel as files, never in counter messages or their replies.
        // A saved photo plus the ledger can exceed WatchConnectivity's payload budget.
        payload["drivingLocked"] = isDrivingLocked
        return payload
    }

    private override init() {
        super.init()
        if let data = UserDefaults.standard.data(forKey: prayerTimesStorageKey),
           let saved = try? JSONDecoder().decode([WatchPrayerScheduleEntry].self, from: data) {
            prayerTimes = saved
        }
        if let data = UserDefaults.standard.data(forKey: statisticsStorageKey),
           let saved = try? JSONDecoder().decode(DhikrStatisticsLedger.self, from: data) {
            statistics = saved
        }
        if let data = UserDefaults.standard.data(forKey: statisticsDhikrClearTimesKey),
           let saved = try? JSONDecoder().decode([String: Double].self, from: data) {
            statisticsDhikrClearTimes = saved
        }
        loadSavedAzkar()
        if let data = UserDefaults.standard.data(forKey: ledgerKey), let saved = try? JSONDecoder().decode(DhikrLedger.self, from: data), saved.isValid {
            ledger = saved
            azkarList = ledger.items
        } else {
            ledger.capture(azkarList, previous: [], stamp: .init(time: revision.timestamp, origin: deviceOrigin))
        }
        azkarList = ledger.items
        previousItems = azkarList
        ledgerReady = true
        restoreActiveItem()
        saveAzkarLocally(isLocalChange: false)
        activateSession()
    }

    /// Clears only statistics, never the dhikr list, goals, or the visible counters.
    public func clearStatistics() {
        statistics = DhikrStatisticsLedger()
        let stamp = max(Date().timeIntervalSince1970, statisticsResetTime.nextUp)
        UserDefaults.standard.set(stamp, forKey: statisticsResetTimeKey)
        persistStatistics()
        sendSyncPayload(count: currentCount, zekr: currentZekr, target: target)
    }

    // MARK: - Azkar Persistence & Management
    public func loadSavedAzkar() {
        if let data = UserDefaults.standard.data(forKey: azkarStorageKey),
           let decoded = try? JSONDecoder().decode([ZekrItem].self, from: data),
           decoded.allSatisfy({ $0.count >= 0 }) {
            self.azkarList = decoded
            encodedAzkarSnapshot = data
            // Preserve existing installations when upgrading from pre-revision builds.
            if UserDefaults.standard.object(forKey: revisionTimeKey) == nil {
                storeRevision(SyncRevision(timestamp: 1, origin: deviceOrigin))
            }
        } else {
            self.azkarList = ZekrItem.builtInAzkar
            saveAzkarLocally(isLocalChange: false)
        }

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

    public func saveAzkarLocally(isLocalChange: Bool = true) {
        if isLocalChange {
            storeRevision(SyncRevision(timestamp: max(Date().timeIntervalSince1970, revision.timestamp.nextUp), origin: deviceOrigin))
        }
        if !applyingLedger && ledgerReady {
            ledger.capture(azkarList, previous: previousItems, stamp: .init(time: revision.timestamp, origin: deviceOrigin))
            for index in azkarList.indices {
                if let entry = ledger.entries[DhikrText.key(azkarList[index].title)], !entry.deleted {
                    azkarList[index].count = entry.count
                }
            }
            if let active = azkarList.first(where: { $0.title == currentZekr }) { currentCount = active.count }
        }
        previousItems = azkarList
        if ledgerReady, let data = try? JSONEncoder().encode(ledger) { UserDefaults.standard.set(data, forKey: ledgerKey) }
        if let encoded = try? JSONEncoder().encode(azkarList) {
            encodedAzkarSnapshot = encoded
            UserDefaults.standard.set(encoded, forKey: azkarStorageKey)
        }
    }

    public func addZekr(title: String, target: Int) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !DhikrText.key(trimmed).isEmpty else { return }
        guard !azkarList.contains(where: { DhikrText.key($0.title) == DhikrText.key(trimmed) }) else { return }
        let newItem = ZekrItem(title: trimmed, defaultTarget: max(1, target), count: 0, isBuiltIn: false)
        azkarList.append(newItem)
        saveAzkarLocally()
        syncAzkarListToPeer()
    }

    public func updateZekr(item: ZekrItem, newTitle: String, newTarget: Int) {
        guard let index = azkarList.firstIndex(where: { $0.id == item.id }) else { return }
        let trimmed = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !DhikrText.key(trimmed).isEmpty,
              !azkarList.contains(where: { $0.id != item.id && DhikrText.key($0.title) == DhikrText.key(trimmed) }) else { return }
        let currentItemCount = azkarList[index].count
        let updated = ZekrItem(id: item.id, title: trimmed, defaultTarget: max(1, newTarget), count: currentItemCount, isBuiltIn: azkarList[index].isBuiltIn)
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
        let removable = IndexSet(offsets.filter { azkarList.indices.contains($0) && !azkarList[$0].isBuiltIn })
        guard !removable.isEmpty else { return }
        azkarList.remove(atOffsets: removable)
        if azkarList.isEmpty { currentZekr = ""; currentCount = 0; target = 33 }
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
        guard let stored = azkarList.first(where: { $0.id == item.id }), !stored.isBuiltIn else { return }
        azkarList.removeAll(where: { $0.id == item.id })
        if azkarList.isEmpty { currentZekr = ""; currentCount = 0; target = 33 }
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

    // MARK: - اختيار الذكر في الساعة مع استرجاع عدده المستقل
    public func selectZekr(_ item: ZekrItem) {
        // 1. حفظ عدد الذكر الحالي في قائمة الساعة
        if let currentIdx = azkarList.firstIndex(where: { $0.title == currentZekr }) {
            azkarList[currentIdx].count = currentCount
            azkarList[currentIdx].defaultTarget = target
        }

        // 2. استرجاع العدد المحفوظ للذكر المختار
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

        saveAzkarLocally()
        sendSyncPayload(count: savedCount, zekr: item.title, target: targetCount)
        syncAzkarListToPeer()
    }

    // MARK: - تصفير عداد الذكر الحالي فقط
    public func resetCurrentZekrCount() {
        self.currentCount = 0
        if let idx = azkarList.firstIndex(where: { $0.title == currentZekr }) {
            azkarList[idx].count = 0
        }
        saveAzkarLocally()
        sendSyncPayload(count: 0, zekr: currentZekr, target: target)
        syncAzkarListToPeer()
    }

    // MARK: - تصفير عداد ذكر محدد من القائمة
    public func resetZekrCount(for item: ZekrItem) {
        if let idx = azkarList.firstIndex(where: { $0.id == item.id || $0.title == item.title }) {
            azkarList[idx].count = 0
            if currentZekr == azkarList[idx].title {
                currentCount = 0
                sendSyncPayload(count: 0, zekr: currentZekr, target: target)
            }
            saveAzkarLocally()
            syncAzkarListToPeer()
        }
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

        // التأكد من تضمين أحدث عداد للذكر الحالي قبل الإرسال
        if let idx = azkarList.firstIndex(where: { $0.title == currentZekr }),
           azkarList[idx].count != currentCount || azkarList[idx].defaultTarget != target {
            azkarList[idx].count = currentCount
            azkarList[idx].defaultTarget = target
            saveAzkarLocally()
        }

        let payload = makeSnapshot()

        if session.isReachable {
            // The reply contains the phone's current ledger. Merge it immediately
            // so concurrent phone/watch taps cannot leave a visible count gap.
            session.sendMessage(payload, replyHandler: { [weak self] snapshot in
                self?.handleIncomingPayload(snapshot)
            }) { [weak self] error in
                print("Watch -> Phone azkar sendMessage error: \(error.localizedDescription), falling back to transferUserInfo")
                self?.sendReliableAzkarPayload(payload)
            }
        } else {
            sendReliableAzkarPayload(payload)
        }
        try? session.updateApplicationContext(payload)
    }

    private func sendReliableAzkarPayload(_ payload: [String: Any]) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { self.sendReliableAzkarPayload(payload) }
            return
        }
        guard payload["timestamp"] as? Double == revision.timestamp,
              payload["origin"] as? String == revision.origin else { return }
        let session = WCSession.default
        guard session.activationState == .activated else { return }
        for transfer in session.outstandingUserInfoTransfers {
            if transfer.userInfo["azkarData"] != nil {
                transfer.cancel()
            }
        }
        session.transferUserInfo(payload)
        print("Watch: Enqueued reliable azkar transfer to phone (\(azkarList.count) items)")
    }

    public func notifyWatchPurchaseChanged() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated else { session.activate(); return }
        let hint = ["action": "refreshWatchPurchase"]
        if session.isReachable {
            session.sendMessage(hint, replyHandler: nil, errorHandler: { _ in
                DispatchQueue.main.async {
                    if !session.outstandingUserInfoTransfers.contains(where: { $0.userInfo["action"] as? String == "refreshWatchPurchase" }) {
                        session.transferUserInfo(hint)
                    }
                }
            })
        } else if !session.outstandingUserInfoTransfers.contains(where: { $0.userInfo["action"] as? String == "refreshWatchPurchase" }) {
            session.transferUserInfo(hint)
        }
    }

    public func activateSession() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        if session.activationState == .activated {
            refreshSynchronization()
        } else {
            session.activate()
        }
    }

    /// Reconcile the saved received context before advertising local state.
    public func refreshSynchronization() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated else {
            session.activate()
            return
        }
        checkDrivingStatusFromPhone()
        if !session.receivedApplicationContext.isEmpty {
            handleIncomingPayload(session.receivedApplicationContext)
        }
        syncAzkarListToPeer()
        requestLatestStateFromPeer()
    }

    private var foregroundSyncRequestID: UUID?

    /// Exchange both ledgers while visible. Sending only a request repairs
    /// phone-to-watch delivery but leaves lost watch-to-phone taps stranded.
    public func refreshVisibleCounter() {
        traceSync("SYNC Watch foreground exchange state=\(WCSession.default.activationState.rawValue) reachable=\(WCSession.default.isReachable)")
        guard WCSession.isSupported(), foregroundSyncRequestID == nil else { return }
        let session = WCSession.default
        guard session.activationState == .activated, session.isReachable else { return }
        let requestID = UUID()
        foregroundSyncRequestID = requestID
        let finish: ([String: Any]?) -> Void = { [weak self] snapshot in
            DispatchQueue.main.async {
                guard let self, self.foregroundSyncRequestID == requestID else { return }
                self.foregroundSyncRequestID = nil
                if let snapshot { self.handleIncomingPayload(snapshot) }
            }
        }
        var exchange = makeSnapshot()
        exchange["action"] = "exchangeSync"
        session.sendMessage(exchange, replyHandler: { finish($0) }, errorHandler: { error in
            print("Watch foreground sync failed: \(error.localizedDescription)")
            finish(nil)
        })
        // Permit recovery if WatchConnectivity never completes a callback.
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
            if self?.foregroundSyncRequestID == requestID {
                self?.foregroundSyncRequestID = nil
            }
        }
    }

    private func requestLatestStateFromPeer() {
        let session = WCSession.default
        guard session.activationState == .activated else { return }
        let request: [String: Any] = ["action": "requestSync"]
        if session.isReachable {
            // A watch-initiated request can wake iOS. Return state on that same route
            // instead of relying solely on a separate iOS-to-watch push succeeding.
            session.sendMessage(request, replyHandler: { [weak self] snapshot in
                self?.handleIncomingPayload(snapshot)
            }, errorHandler: { error in
                print("Snapshot request failed: \(error.localizedDescription)")
                if session.activationState == .activated {
                    session.transferUserInfo(request)
                }
            })
        } else {
            // Coalesce pending requests; keep the latest state context untouched.
            let hasPendingRequest = session.outstandingUserInfoTransfers.contains {
                $0.userInfo["action"] as? String == "requestSync"
            }
            if !hasPendingRequest { session.transferUserInfo(request) }
        }
    }

    // MARK: - طلب المزامنة الفورية من الآيفون
    public func requestSyncFromPhone() {
        refreshSynchronization()
    }

    /// فحص حالة قفل القيادة فوراً وبشكل خفيف جداً من الآيفون
    public func checkDrivingStatusFromPhone() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated else {
            session.activate()
            return
        }
        if session.isReachable {
            let request: [String: Any] = ["action": "checkDrivingStatus"]
            session.sendMessage(request, replyHandler: { [weak self] reply in
                if let locked = reply["drivingLocked"] as? Bool {
                    DispatchQueue.main.async {
                        if self?.isDrivingLocked != locked {
                            self?.isDrivingLocked = locked
                            UserDefaults.standard.set(locked, forKey: "fadhkuruni_driving_locked")
                        }
                    }
                }
            }, errorHandler: nil)
        } else if !session.receivedApplicationContext.isEmpty {
            if let locked = session.receivedApplicationContext["drivingLocked"] as? Bool {
                DispatchQueue.main.async {
                    if self.isDrivingLocked != locked {
                        self.isDrivingLocked = locked
                        UserDefaults.standard.set(locked, forKey: "fadhkuruni_driving_locked")
                    }
                }
            }
        }
    }

    /// Count one local tap without emitting a destructive reset at cycle boundaries.
    @discardableResult
    public func incrementCurrentZekr() -> Bool? {
        guard !isDrivingLocked else { return nil }
        guard azkarList.contains(where: { $0.title == currentZekr }) else { return nil }
        let next = SyncRevision(timestamp: max(Date().timeIntervalSince1970, revision.timestamp.nextUp), origin: deviceOrigin)
        guard let reachedGoal = ledger.recordTap(title: currentZekr, stamp: .init(time: next.timestamp, origin: next.origin)) else { return nil }
        storeRevision(next)
        statistics.recordTap(origin: deviceOrigin, title: currentZekr)
        persistStatistics()
        azkarList = ledger.items
        restoreActiveItem()
        applyingLedger = true
        saveAzkarLocally(isLocalChange: false)
        applyingLedger = false
        sendSyncPayload(count: currentCount, zekr: currentZekr, target: target)
        return reachedGoal
    }

    /// Correct one accidental tap as a ledger operation, so it survives a device merge.
    public func decrementCurrentZekr() {
        guard !isDrivingLocked, currentCount > 0,
              azkarList.contains(where: { $0.title == currentZekr }) else { return }
        let next = SyncRevision(timestamp: max(Date().timeIntervalSince1970, revision.timestamp.nextUp), origin: deviceOrigin)
        guard ledger.recordDecrement(title: currentZekr, stamp: .init(time: next.timestamp, origin: next.origin)) else { return }
        storeRevision(next)
        statistics.recordDecrement(origin: deviceOrigin, title: currentZekr)
        persistStatistics()
        azkarList = ledger.items
        restoreActiveItem()
        applyingLedger = true
        saveAzkarLocally(isLocalChange: false)
        applyingLedger = false
        sendSyncPayload(count: currentCount, zekr: currentZekr, target: target)
    }

    /// Synchronize state changes to paired watch or phone
    public func sendSyncPayload(count: Int, zekr: String, target: Int) {
        traceSync("SYNC Watch local send count=\(count) target=\(target) state=\(WCSession.default.activationState.rawValue) reachable=\(WCSession.default.isReachable)")
        guard count >= 0, (1...10000).contains(target), azkarList.contains(where: { $0.title == zekr }) else { return }
        if self.currentCount != count { self.currentCount = count }
        if self.currentZekr != zekr { self.currentZekr = zekr }
        if self.target != target { self.target = target }

        // تحديث عدد الذكر الحالي في قائمة الساعة فوراً
        if let idx = azkarList.firstIndex(where: { $0.title == zekr }) {
            if azkarList[idx].count != count || azkarList[idx].defaultTarget != target {
                azkarList[idx].count = count
                azkarList[idx].defaultTarget = target
                saveAzkarLocally()
            }
        }

        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated else {
            session.activate()
            return
        }

        let payload = makeSnapshot()

        if session.isReachable {
            // Reconcile with the phone after every foreground counter update.
            session.sendMessage(payload, replyHandler: { [weak self] snapshot in
                self?.handleIncomingPayload(snapshot)
            }, errorHandler: { [weak self] error in
                self?.traceSync("SYNC Watch direct send failed: \(error)")
                self?.sendReliableBackgroundPayload(payload)
            })
        } else {
            sendReliableBackgroundPayload(payload)
        }
        // Retain the latest complete state for delivery after a disconnection.
        try? session.updateApplicationContext(payload)
    }

    private func sendReliableBackgroundPayload(_ payload: [String: Any]) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { self.sendReliableBackgroundPayload(payload) }
            return
        }
        guard payload["timestamp"] as? Double == revision.timestamp,
              payload["origin"] as? String == revision.origin else { return }
        let session = WCSession.default
        guard session.activationState == .activated else { return }
        for transfer in session.outstandingUserInfoTransfers {
            if transfer.userInfo["count"] != nil {
                transfer.cancel()
            }
        }
        traceSync("SYNC Watch queued count=\(payload["count"] as? Int ?? -1)")
        session.transferUserInfo(payload)
    }

    // MARK: - WCSessionDelegate
    public func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        traceSync("SYNC Watch activated state=\(activationState.rawValue) error=\(String(describing:error))")
        guard activationState == .activated else { return }
        DispatchQueue.main.async {
            self.refreshSynchronization()
            self.sendWatchClockPhotoFile()
        }
    }

    public func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            if session.isReachable { self.refreshSynchronization() }
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
        if message["action"] as? String == "exchangeSync" {
            DispatchQueue.main.async {
                self.applyIncomingPayload(message)
                replyHandler(self.makeSnapshot())
            }
            return
        }
        handleIncomingPayload(message)
        DispatchQueue.main.async {
            if message["action"] as? String == "requestSync" {
                replyHandler(self.makeSnapshot())
            } else if message["action"] as? String == "checkDrivingStatus" {
                replyHandler(["drivingLocked": self.isDrivingLocked])
            } else {
                // Return the full merged state, not a bare acknowledgement.
                replyHandler(self.makeSnapshot())
            }
        }
    }

    public func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any] = [:]) {
        handleIncomingPayload(userInfo)
    }

    public func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        handleIncomingPayload(applicationContext)
    }

    private func handleIncomingPayload(_ payload: [String: Any]) {
        if Thread.isMainThread {
            applyIncomingPayload(payload)
        } else {
            DispatchQueue.main.async { self.applyIncomingPayload(payload) }
        }
    }

    private func applyIncomingPayload(_ payload: [String: Any]) {
        traceSync("SYNC Watch receive action=\(payload["action"] as? String ?? "state") count=\(payload["count"] as? Int ?? -1) ledgerBytes=\((payload["ledgerV2"] as? Data)?.count ?? 0)")
        if let action = payload["action"] as? String, action == "drivingLockUpdate",
           let locked = payload["drivingLocked"] as? Bool {
            if isDrivingLocked != locked {
                isDrivingLocked = locked
                UserDefaults.standard.set(locked, forKey: "fadhkuruni_driving_locked")
            }
            return
        }
        applyMinusPreference(payload)
        applyResetPreference(payload)
        applyClockCoverPreference(payload)
        applyWatchClockPhoto(payload)
        applyDrivingLock(payload)
        if let data = payload["watchPrayerTimesV1"] as? Data,
           let received = try? JSONDecoder().decode([WatchPrayerScheduleEntry].self, from: data),
           received != prayerTimes {
            prayerTimes = received
            UserDefaults.standard.set(data, forKey: prayerTimesStorageKey)
        }
        if payload["action"] as? String == "refreshWatchPurchase" {
            // Connectivity is a refresh hint, never proof of payment.
            Task { await WatchPurchaseAccess.shared.refresh() }
            return
        }
        let remoteResetTime = payload["statisticsResetTime"] as? Double ?? 0
        if remoteResetTime > statisticsResetTime {
            UserDefaults.standard.set(remoteResetTime, forKey: statisticsResetTimeKey)
            statistics = DhikrStatisticsLedger()
            persistStatistics()
        }
        var newlyClearedDhikrKeys = Set<String>()
        if let data = payload["statisticsDhikrClearTimesV1"] as? Data,
           let remoteClearTimes = try? JSONDecoder().decode([String: Double].self, from: data) {
            for (key, stamp) in remoteClearTimes where stamp > (statisticsDhikrClearTimes[key] ?? 0) {
                statisticsDhikrClearTimes[key] = stamp
                newlyClearedDhikrKeys.insert(key)
            }
            if !newlyClearedDhikrKeys.isEmpty { persistDhikrStatisticsClearTimes() }
        }
        if remoteResetTime >= statisticsResetTime,
           let data = payload["statisticsV1"] as? Data,
           let remoteStatistics = try? JSONDecoder().decode(DhikrStatisticsLedger.self, from: data) {
            let beforeStatistics = statistics
            statistics.merge(remoteStatistics)
            if statistics != beforeStatistics { persistStatistics() }
        }
        if !newlyClearedDhikrKeys.isEmpty {
            for key in newlyClearedDhikrKeys { statistics.clear(dhikrKey: key) }
            persistStatistics()
        }
        if let action = payload["action"] as? String, action == "requestSync" {
            self.sendSyncPayload(count: self.currentCount, zekr: self.currentZekr, target: self.target)
            return
        }

        guard let data = payload["ledgerV2"] as? Data,
              let remote = try? JSONDecoder().decode(DhikrLedger.self, from: data), remote.isValid else { return }
        let before = ledger
        ledger.merge(remote)
        let newer = SyncRevision(timestamp: payload["timestamp"] as? Double ?? 0, origin: payload["origin"] as? String ?? "")
        if newer.timestamp.isFinite && newer.isNewer(than: revision) {
            storeRevision(newer)
            currentZekr = payload["zekr"] as? String ?? currentZekr
        }
        azkarList = ledger.items
        restoreActiveItem()
        applyingLedger = true
        saveAzkarLocally(isLocalChange: false)
        applyingLedger = false
        // Publish only on a semantic merge, avoiding connectivity echo loops.
        if before != ledger, WCSession.default.activationState == .activated {
            try? WCSession.default.updateApplicationContext(makeSnapshot())
        }
    }

    private func restoreActiveItem() {
        if let item = azkarList.first(where: { $0.title == currentZekr }) ?? azkarList.first {
            currentZekr = item.title; currentCount = item.count; target = item.defaultTarget
        } else { currentZekr = ""; currentCount = 0; target = 33 }
        UserDefaults.standard.set(currentZekr, forKey: currentZekrStorageKey)
    }

    private func persistStatistics() {
        if let data = try? JSONEncoder().encode(statistics) {
            UserDefaults.standard.set(data, forKey: statisticsStorageKey)
        }
    }

    private func persistDhikrStatisticsClearTimes() {
        if let data = try? JSONEncoder().encode(statisticsDhikrClearTimes) {
            UserDefaults.standard.set(data, forKey: statisticsDhikrClearTimesKey)
        }
    }


}
