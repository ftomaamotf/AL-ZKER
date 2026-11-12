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
        case .builtIn: "نغمة الصلاة"
        case .custom: "نغمة محفوظة سابقاً"
        }
    }
}

struct BuiltInAdhan: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let subtitle: String
    let fileName: String
    let toneID: Int

    nonisolated static let all: [BuiltInAdhan] = [
        .init(id: "dawn", title: "ندى الفجر", subtitle: "نغمة دافئة وهادئة", fileName: "fadhkuruni-prayer-dawn-v2.wav", toneID: 7),
        .init(id: "glass", title: "بلورة السكينة", subtitle: "رنين بلوري واضح", fileName: "fadhkuruni-prayer-glass-v2.wav", toneID: 3),
        .init(id: "harp", title: "وتر مطمئن", subtitle: "نغمة روحانية ناعمة", fileName: "fadhkuruni-prayer-harp-v2.wav", toneID: 6),
        .init(id: "soft", title: "جرس هادئ", subtitle: "تنبيه منخفض ولطيف", fileName: "fadhkuruni-prayer-soft-v2.wav", toneID: 2),
        .init(id: "drop", title: "قطرة نور", subtitle: "نغمة قصيرة جداً", fileName: "fadhkuruni-prayer-drop-v2.wav", toneID: 5)
    ]

    private static let preferencePrefix = "fadhkuruni_prayer_builtin_adhan_"

    static func selected(for prayerID: String) -> BuiltInAdhan {
        let selectedID = UserDefaults.standard.string(forKey: preferencePrefix + prayerID) ?? "dawn"
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

    /// Apply the requested tone once; subsequent user changes remain editable.
    static func configureLongToneForAllPrayersIfNeeded() {
        let defaults = UserDefaults.standard
        let migrationKey = "fadhkuruni_long_prayer_tone_configured_v1"
        guard !defaults.bool(forKey: migrationKey),
              let tone = BuiltInAdhan.all.first(where: { $0.id == "dawn" }) else { return }
        for prayerID in ["fajr", "dhuhr", "asr", "maghrib", "isha"] {
            BuiltInAdhan.select(tone, for: prayerID)
            set(.builtIn, for: prayerID)
        }
        defaults.set(true, forKey: "fadhkuruni_prayer_reminders_enabled")
        defaults.set(true, forKey: migrationKey)
    }

    static func mode(for prayerID: String) -> PrayerAlertMode {
        guard let value = UserDefaults.standard.string(forKey: prefix + prayerID),
              let mode = PrayerAlertMode(rawValue: value) else { return .builtIn }
        // الصوت الخاص لم يعد خياراً في التطبيق. نحول أي اختيار قديم
        // تلقائياً إلى إحدى النغمات الخمس الجديدة كي لا يتعطل التنبيه.
        if mode == .custom {
            set(.builtIn, for: prayerID)
            return .builtIn
        }
        return mode
    }

    static func set(_ mode: PrayerAlertMode, for prayerID: String) {
        UserDefaults.standard.set(mode.rawValue, forKey: prefix + prayerID)
    }
}

@MainActor
final class PrayerAdhanRecorder: NSObject, ObservableObject, @preconcurrency AVAudioRecorderDelegate, AVAudioPlayerDelegate {
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
            Task { @MainActor [weak self] in
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
        Self.ensureBuiltInSoundsInLibraryDirectory()
        let url = Self.bundledToneURL(named: adhan.fileName)
            ?? Self.soundsDirectory.appendingPathComponent(adhan.fileName)
        guard FileManager.default.fileExists(atPath: url.path) else {
            message = "تعذر العثور على النغمة. أعد فتح التطبيق ثم جرّب مرة أخرى."
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

    /// تشغيل نغمة الصلاة المختارة.
    func playFullAdhan(for prayerID: String) {
        let alertMode = PrayerAlertPreference.mode(for: prayerID)
        switch alertMode {
        case .none, .silent:
            return
        case .system, .builtIn:
            let adhan = BuiltInAdhan.selected(for: prayerID)
            playBuiltInAdhan(adhan)
        case .custom:
            if hasRecording(for: prayerID) {
                playRecording(for: prayerID)
            } else {
                let adhan = BuiltInAdhan.selected(for: prayerID)
                playBuiltInAdhan(adhan)
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
            Self.makeAvailableForLockedNotification(destination)
            
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

    func scheduleTestNotification(for prayerID: String, title: String, after delay: TimeInterval = 5) {
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
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, delay), repeats: false)
        let request = UNNotificationRequest(identifier: "fadhkuruni.test.prayer.\(prayerID)", content: content, trigger: trigger)
        center.add(request) { [weak self] error in
            Task { @MainActor [weak self] in
                if error == nil {
                    self?.message = "تمت جدولة إشعار التجربة بنجاح! سيصلك التنبيه خلال \(Int(max(1, delay))) ثوانٍ لسماع الصوت."
                } else {
                    self?.message = "تعذر إرسال التجربة، تأكد من تفعيل إذن الإشعارات."
                }
            }
        }
    }

    func scheduleDefaultSoundTest(after delay: TimeInterval = 20) {
        let content = UNMutableNotificationContent()
        content.title = "تجربة صوت الآيفون"
        content.body = "هذا هو صوت إشعارات النظام الافتراضي."
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, delay), repeats: false)
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: "fadhkuruni.test.default-sound", content: content, trigger: trigger)
        )
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
        if flag, let prayerID = recordingPrayerID {
            Self.makeAvailableForLockedNotification(Self.recordingURL(for: prayerID))
        }
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

    /// Generates a small, original notification-tone library directly on the
    /// device. The files are short and available while the device is locked.
    public nonisolated static func ensureBuiltInSoundsInLibraryDirectory() {
        let fileManager = FileManager.default
        let soundsDir = soundsDirectory
        try? fileManager.createDirectory(at: soundsDir, withIntermediateDirectories: true)

        let legacyNames = [
            "prayer-long-tone", "adhan-makkah-classic", "adhan-madinah",
            "adhan-egypt-abdulbasit", "adhan-quds-sham", "adhan-takbeerat",
            "adhan-makkah-maghrib", "adhan-casablanca", "adhan-aaqib-sweet",
            "adhan-calm", "adhan-short"
        ]
        for name in legacyNames {
            for extensionName in ["caf", "wav"] {
                try? fileManager.removeItem(at: soundsDir.appendingPathComponent("\(name).\(extensionName)"))
            }
        }

        let toneVersionKey = "fadhkuruni_prayer_tones_version"
        let needsRefresh = UserDefaults.standard.integer(forKey: toneVersionKey) < 3
        for adhan in BuiltInAdhan.all {
            let destination = soundsDir.appendingPathComponent(adhan.fileName)
            if needsRefresh || !fileManager.fileExists(atPath: destination.path) {
                if let bundledTone = bundledToneURL(named: adhan.fileName) {
                    try? fileManager.removeItem(at: destination)
                    try? fileManager.copyItem(at: bundledTone, to: destination)
                } else {
                    try? SoundSynthesizer.makeWav(for: adhan.toneID).write(to: destination, options: .atomic)
                }
            }
            makeAvailableForLockedNotification(destination)
        }
        UserDefaults.standard.set(3, forKey: toneVersionKey)
    }

    private nonisolated static func bundledToneURL(named fileName: String) -> URL? {
        let name = (fileName as NSString).deletingPathExtension
        let extensionName = (fileName as NSString).pathExtension
        return Bundle.main.url(forResource: name, withExtension: extensionName, subdirectory: "PrayerAdhanSounds")
            ?? Bundle.main.url(forResource: name, withExtension: extensionName)
    }

    private nonisolated static func makeAvailableForLockedNotification(_ url: URL) {
        try? FileManager.default.setAttributes(
            [.protectionKey: FileProtectionType.none],
            ofItemAtPath: url.path
        )
    }
}
