import AVFoundation
import Combine
import Foundation
import UserNotifications

enum PrayerAlertMode: String, CaseIterable {
    case none
    case silent
    case system
    case builtIn
    case custom

    var title: String {
        switch self {
        case .none: "لا يوجد"
        case .silent: "إشعار صامت"
        case .system: "الصوت الافتراضي"
        case .builtIn: "أذان مدمج"
        case .custom: "أذان خاص"
        }
    }
}

struct BuiltInAdhan: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let fileName: String

    static let all: [BuiltInAdhan] = [
        .init(id: "makkah-classic", title: "مكة — الحرم", subtitle: "تسجيل الحرم المكي", fileName: "adhan-makkah-classic.caf"),
        .init(id: "makkah-maghrib", title: "مكة — المغرب", subtitle: "تسجيل أذان المغرب من الحرم", fileName: "adhan-makkah-maghrib.caf"),
        .init(id: "casablanca", title: "الدار البيضاء", subtitle: "مسجد الحسن الثاني", fileName: "adhan-casablanca.caf"),
        .init(id: "calm", title: "أذان هادئ", subtitle: "نغمة أذان واضحة وهادئة", fileName: "adhan-calm.caf"),
        .init(id: "short", title: "أذان مختصر", subtitle: "خيار قصير للتنبيه", fileName: "adhan-short.caf")
    ]

    private static let preferencePrefix = "fadhkuruni_prayer_builtin_adhan_"

    static func selected(for prayerID: String) -> BuiltInAdhan {
        let selectedID = UserDefaults.standard.string(forKey: preferencePrefix + prayerID) ?? "makkah-classic"
        return all.first(where: { $0.id == selectedID }) ?? all[0]
    }

    static func select(_ adhan: BuiltInAdhan, for prayerID: String) {
        UserDefaults.standard.set(adhan.id, forKey: preferencePrefix + prayerID)
    }

    static func notificationSound(for prayerID: String) -> UNNotificationSound {
        UNNotificationSound(named: UNNotificationSoundName(rawValue: selected(for: prayerID).fileName))
    }
}

enum PrayerAlertPreference {
    private static let prefix = "fadhkuruni_prayer_alert_mode_"

    static func mode(for prayerID: String) -> PrayerAlertMode {
        guard let value = UserDefaults.standard.string(forKey: prefix + prayerID),
              let mode = PrayerAlertMode(rawValue: value) else { return .system }
        return mode
    }

    static func set(_ mode: PrayerAlertMode, for prayerID: String) {
        UserDefaults.standard.set(mode.rawValue, forKey: prefix + prayerID)
    }
}

@MainActor
final class PrayerAdhanRecorder: NSObject, ObservableObject, @preconcurrency AVAudioRecorderDelegate, @preconcurrency AVAudioPlayerDelegate {
    static let shared = PrayerAdhanRecorder()

    @Published private(set) var recordingPrayerID: String?
    @Published private(set) var playingPrayerID: String?
    @Published private(set) var playingBuiltInAdhanID: String?
    @Published private(set) var message: String?

    private var recorder: AVAudioRecorder?
    private var player: AVAudioPlayer?

    private override init() { super.init() }

    func hasRecording(for prayerID: String) -> Bool {
        FileManager.default.fileExists(atPath: recordingURL(for: prayerID).path)
    }

    func requestAndStartRecording(for prayerID: String) {
        message = nil
        AVAudioApplication.requestRecordPermission { [weak self] granted in
            Task { @MainActor in
                guard granted else {
                    self?.message = "اسمح بالميكروفون من إعدادات الآيفون لتسجيل الأذان."
                    return
                }
                self?.startRecording(for: prayerID)
            }
        }
    }

    func stopRecording() {
        recorder?.stop()
        recorder = nil
        recordingPrayerID = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        DhikrSummaryNotificationScheduler.shared.refreshPrayerReminders()
    }

    func playRecording(for prayerID: String) {
        stopPlayback()
        guard hasRecording(for: prayerID) else {
            message = "لا يوجد تسجيل لهذا الوقت بعد."
            return
        }
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            player = try AVAudioPlayer(contentsOf: recordingURL(for: prayerID))
            player?.delegate = self
            player?.play()
            playingPrayerID = prayerID
        } catch {
            message = "تعذر تشغيل التسجيل."
        }
    }

    func stopPlayback() {
        player?.stop()
        player = nil
        playingPrayerID = nil
        playingBuiltInAdhanID = nil
    }

    func playBuiltInAdhan(_ adhan: BuiltInAdhan) {
        stopPlayback()
        guard let url = Bundle.main.url(forResource: adhan.fileName, withExtension: nil) else {
            message = "تعذر العثور على ملف الأذان. أعد تثبيت التطبيق ثم جرّب مرة أخرى."
            return
        }
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            player = try AVAudioPlayer(contentsOf: url)
            player?.delegate = self
            player?.play()
            playingBuiltInAdhanID = adhan.id
        } catch {
            message = "تعذر تشغيل معاينة الأذان."
        }
    }

    func deleteRecording(for prayerID: String) {
        stopPlayback()
        Self.recordingURLs(for: prayerID).forEach { try? FileManager.default.removeItem(at: $0) }
        DhikrSummaryNotificationScheduler.shared.refreshPrayerReminders()
    }

    func importAudio(from sourceURL: URL, for prayerID: String) {
        let fileExtension = sourceURL.pathExtension.lowercased()
        guard Self.supportedExtensions.contains(fileExtension) else {
            message = "اختر ملف WAV أو CAF أو AIFF ليعمل الصوت في إشعار الصلاة."
            return
        }
        guard sourceURL.startAccessingSecurityScopedResource() else {
            message = "تعذر الوصول إلى الملف المختار."
            return
        }
        defer { sourceURL.stopAccessingSecurityScopedResource() }
        do {
            stopPlayback()
            try FileManager.default.createDirectory(at: Self.soundsDirectory, withIntermediateDirectories: true)
            Self.recordingURLs(for: prayerID).forEach { try? FileManager.default.removeItem(at: $0) }
            let destination = Self.soundsDirectory.appendingPathComponent("adhan-\(prayerID).\(fileExtension)")
            try FileManager.default.copyItem(at: sourceURL, to: destination)
            message = "تمت إضافة الصوت إلى أذان الصلاة."
            DhikrSummaryNotificationScheduler.shared.refreshPrayerReminders()
        } catch {
            message = "تعذر إضافة الملف."
        }
    }

    func clearMessage() { message = nil }

    nonisolated static func notificationSound(for prayerID: String) -> UNNotificationSound? {
        let url = Self.recordingURL(for: prayerID)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return UNNotificationSound(named: UNNotificationSoundName(rawValue: url.lastPathComponent))
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        playingPrayerID = nil
        playingBuiltInAdhanID = nil
    }

    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        self.recorder = nil
        recordingPrayerID = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        DhikrSummaryNotificationScheduler.shared.refreshPrayerReminders()
    }

    private func startRecording(for prayerID: String) {
        stopPlayback()
        if recordingPrayerID != nil { stopRecording() }
        do {
            try FileManager.default.createDirectory(at: Self.soundsDirectory, withIntermediateDirectories: true)
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .default)
            try session.setActive(true)
            let settings: [String: Any] = [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVSampleRateKey: 16_000,
                AVNumberOfChannelsKey: 1,
                AVLinearPCMBitDepthKey: 16,
                AVLinearPCMIsBigEndianKey: false,
                AVLinearPCMIsFloatKey: false
            ]
            recorder = try AVAudioRecorder(url: recordingURL(for: prayerID), settings: settings)
            recorder?.delegate = self
            recorder?.record(forDuration: 300)
            recordingPrayerID = prayerID
        } catch {
            message = "تعذر بدء التسجيل."
            try? AVAudioSession.sharedInstance().setActive(false)
        }
    }

    private func recordingURL(for prayerID: String) -> URL {
        Self.recordingURL(for: prayerID)
    }

    private nonisolated static let supportedExtensions = ["caf", "wav", "aiff", "aif"]

    private nonisolated static var soundsDirectory: URL {
        FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Sounds", isDirectory: true)
    }

    private nonisolated static func recordingURL(for prayerID: String) -> URL {
        recordingURLs(for: prayerID).first(where: { FileManager.default.fileExists(atPath: $0.path) })
            ?? soundsDirectory.appendingPathComponent("adhan-\(prayerID).caf")
    }

    private nonisolated static func recordingURLs(for prayerID: String) -> [URL] {
        supportedExtensions.map { soundsDirectory.appendingPathComponent("adhan-\(prayerID).\($0)") }
    }
}
