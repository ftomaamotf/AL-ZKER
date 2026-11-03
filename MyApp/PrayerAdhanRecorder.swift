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
    let fullFileName: String

    static let all: [BuiltInAdhan] = [
        .init(id: "makkah-classic", title: "مكة — الحرم المكي", subtitle: "أذان الحرم المكي الشريف (كامل 3:17 د)", fileName: "adhan-makkah-classic.caf", fullFileName: "adhan-makkah-classic-full.m4a"),
        .init(id: "madinah", title: "المدينة — المسجد النبوي", subtitle: "أذان المسجد النبوي — الشيخ السريحي (كامل 4:26 د)", fileName: "adhan-madinah.caf", fullFileName: "adhan-madinah-full.m4a"),
        .init(id: "egypt-abdulbasit", title: "مصر — الشيخ عبد الباسط", subtitle: "أذان تاريخي بصوت الشيخ عبد الباسط (كامل 3:42 د)", fileName: "adhan-egypt-abdulbasit.caf", fullFileName: "adhan-egypt-abdulbasit-full.m4a"),
        .init(id: "quds-sham", title: "القدس والشام — تاريخي", subtitle: "تسجيل أذان شجي — صباح فخري (كامل 3:22 د)", fileName: "adhan-quds-sham.caf", fullFileName: "adhan-quds-sham-full.m4a"),
        .init(id: "takbeerat", title: "تكبيرات العيد والحرم", subtitle: "الله أكبر كبيراً والحمد لله كثيراً (نغمة تكبيرات)", fileName: "adhan-takbeerat.caf", fullFileName: "adhan-takbeerat-full.m4a"),
        .init(id: "makkah-maghrib", title: "مكة — أذان المغرب", subtitle: "أذان المغرب الروحاني من الحرم (كامل 5:01 د)", fileName: "adhan-makkah-maghrib.caf", fullFileName: "adhan-makkah-maghrib-full.m4a"),
        .init(id: "casablanca", title: "الدار البيضاء — جامع الحسن الثاني", subtitle: "تسجيل الأذان المغربي الأصيل (كامل 2:55 د)", fileName: "adhan-casablanca.caf", fullFileName: "adhan-casablanca-full.m4a"),
        .init(id: "aaqib-sweet", title: "أذان نديّ وهادئ", subtitle: "أذان عذب رخيم — القارئ عاقب عزيز (كامل 1:49 د)", fileName: "adhan-aaqib-sweet.caf", fullFileName: "adhan-aaqib-sweet-full.m4a"),
        .init(id: "calm", title: "أذان السكينة", subtitle: "نغمة أذان هادئة جداً وواضحة (كامل 2:54 د)", fileName: "adhan-calm.caf", fullFileName: "adhan-calm-full.m4a"),
        .init(id: "short", title: "أذان مختصر للتنبيه", subtitle: "خيار قصير للتنبيه السريع (45 ثانية)", fileName: "adhan-short.caf", fullFileName: "adhan-short-full.m4a")
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
              let mode = PrayerAlertMode(rawValue: value) else { return .builtIn }
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

    private override init() {
        super.init()
        Self.ensureBuiltInSoundsInLibraryDirectory()
    }

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

    func playBuiltInAdhan(_ adhan: BuiltInAdhan, full: Bool = false) {
        stopPlayback()
        let targetName = full ? adhan.fullFileName : adhan.fileName
        let nsTarget = targetName as NSString
        let base = nsTarget.deletingPathExtension
        let ext = nsTarget.pathExtension
        let libraryURL = Self.soundsDirectory.appendingPathComponent(targetName)
        let fallbackLibraryURL = Self.soundsDirectory.appendingPathComponent(adhan.fileName)

        guard let url = Bundle.main.url(forResource: targetName, withExtension: nil)
            ?? Bundle.main.url(forResource: base, withExtension: ext)
            ?? Bundle.main.url(forResource: adhan.fileName, withExtension: nil)
            ?? (FileManager.default.fileExists(atPath: libraryURL.path) ? libraryURL : nil)
            ?? (FileManager.default.fileExists(atPath: fallbackLibraryURL.path) ? fallbackLibraryURL : nil) else {
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
            message = "تعذر تشغيل الأذان."
        }
    }

    /// تشغيل الأذان المختار للصلاة كاملاً
    func playFullAdhan(for prayerID: String) {
        let alertMode = PrayerAlertPreference.mode(for: prayerID)
        switch alertMode {
        case .none, .silent:
            return
        case .system, .builtIn:
            let adhan = BuiltInAdhan.selected(for: prayerID)
            playBuiltInAdhan(adhan, full: true)
        case .custom:
            if hasRecording(for: prayerID) {
                playRecording(for: prayerID)
            } else {
                let adhan = BuiltInAdhan.selected(for: prayerID)
                playBuiltInAdhan(adhan, full: true)
            }
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
            message = "اختر ملف صوتي (MP3 أو M4A أو WAV أو CAF أو AIFF)."
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
            let destination = Self.soundsDirectory.appendingPathComponent("adhan-\(prayerID).caf")
            
            // تحويل وضبط الصوت إلى صيغة متوافقة تماماً مع إشعارات نظام iOS بحد أقصى 29.5 ثانية
            try Self.convertToNotificationCAF(sourceURL: sourceURL, destinationURL: destination)
            
            message = "تمت إضافة الصوت بنجاح وضبطه ليعمل مع إشعارات الآيفون."
            PrayerAlertPreference.set(.custom, for: prayerID)
            DhikrSummaryNotificationScheduler.shared.refreshPrayerReminders()
        } catch {
            message = "تعذر إضافة الملف الصوتي: \(error.localizedDescription)"
        }
    }

    /// تحويل وقص أي ملف صوتي إلى صيغة Linear PCM داخل ملف .caf متوافق مع نظام إشعارات iOS
    private static func convertToNotificationCAF(sourceURL: URL, destinationURL: URL, maxDuration: Double = 29.5) throws {
        let sourceFile = try AVAudioFile(forReading: sourceURL)
        let format = sourceFile.processingFormat
        let maxFrames = AVAudioFramePosition(min(Double(sourceFile.length), maxDuration * format.sampleRate))

        let targetSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: min(format.sampleRate, 44100.0),
            AVNumberOfChannelsKey: min(format.channelCount, 2),
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsFloatKey: false
        ]

        let outputFile = try AVAudioFile(forWriting: destinationURL, settings: targetSettings)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 4096)!
        var framesRemaining = maxFrames

        while framesRemaining > 0 && sourceFile.framePosition < sourceFile.length {
            let framesToRead = AVAudioFrameCount(min(AVAudioFramePosition(buffer.frameCapacity), framesRemaining))
            try sourceFile.read(into: buffer, frameCount: framesToRead)
            if buffer.frameLength == 0 { break }
            try outputFile.write(from: buffer)
            framesRemaining -= AVAudioFramePosition(buffer.frameLength)
        }
    }

    func scheduleTestNotification(for prayerID: String, title: String) {
        let center = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()
        content.title = "حان وقت صلاة \(title)"
        content.body = "حي على الصلاة — تجربة تنبيه الصلاة والصوت المختار"
        if #available(iOS 15.0, *) {
            content.interruptionLevel = .timeSensitive
        }
        let alertMode = PrayerAlertPreference.mode(for: prayerID)
        switch alertMode {
        case .none:
            content.sound = nil
        case .silent:
            content.sound = nil
        case .system:
            content.sound = .default
        case .builtIn:
            content.sound = BuiltInAdhan.notificationSound(for: prayerID)
        case .custom:
            content.sound = Self.notificationSound(for: prayerID) ?? .default
        }
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        let request = UNNotificationRequest(identifier: "fadhkuruni.test.prayer.\(prayerID)", content: content, trigger: trigger)
        center.add(request) { [weak self] error in
            Task { @MainActor in
                if error == nil {
                    self?.message = "تمت جدولة إشعار التجربة بنجاح! سيصلك التنبيه خلال 5 ثوانٍ لسماع الصوت."
                } else {
                    self?.message = "تعذر إرسال التجربة، تأكد من تفعيل إذن الإشعارات."
                }
            }
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
            // تسجيل حتى 5 دقائق لتمكين تسجيل الأذان كاملاً
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

    private nonisolated static let supportedExtensions = ["caf", "wav", "aiff", "aif", "mp3", "m4a", "aac"]

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

    /// نسخ جميع أصوات الأذان والتنبيهات المدمجة إلى مجلد Library/Sounds داخل الحاوية
    /// لضمان تعرف نظام iOS (SpringBoard) فوراً على ملف الصوت وتشغيله عند وصول الإشعار والشاشة مقفلة
    public nonisolated static func ensureBuiltInSoundsInLibraryDirectory() {
        let fileManager = FileManager.default
        let soundsDir = soundsDirectory
        try? fileManager.createDirectory(at: soundsDir, withIntermediateDirectories: true)

        for adhan in BuiltInAdhan.all {
            for ext in ["caf", "wav"] {
                let filename = (ext == "caf") ? adhan.fileName : adhan.fileName.replacingOccurrences(of: ".caf", with: ".wav")
                let destURL = soundsDir.appendingPathComponent(filename)
                let base = (filename as NSString).deletingPathExtension
                let bundleURL = Bundle.main.url(forResource: base, withExtension: ext)
                    ?? Bundle.main.url(forResource: filename, withExtension: nil)
                if let bundleURL, !fileManager.fileExists(atPath: destURL.path) {
                    try? fileManager.copyItem(at: bundleURL, to: destURL)
                }
            }
        }
    }
}
