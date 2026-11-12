import WatchConnectivity
//
//  PhoneCompanionView.swift
//  Fadhkuruni (iPhone Companion App View)
//

import SwiftUI
import StoreKit
import AVFoundation
import AudioToolbox
import PhotosUI
import UIKit
import UniformTypeIdentifiers

// MARK: - محاكي توليد النغمات فائقة النقاء (WAV Synthesizer)
public final class SoundSynthesizer {
    public static func makeWav(for id: Int) -> Data {
        switch id {
        case 1:
            // نغمة الإنجاز والبهجة (C5 -> E5 -> G5 -> C6)
            return makeChime(tones: [
                (523.25, 0.00, 1.2, 3.8, 0.35),
                (659.25, 0.11, 1.2, 3.8, 0.35),
                (783.99, 0.22, 1.2, 3.8, 0.35),
                (1046.50, 0.33, 1.4, 2.8, 0.45)
            ], totalDuration: 1.6)
            
        case 2:
            // جرس هادئ ومريح (440Hz + 880Hz + 1320Hz)
            return makeChime(tones: [
                (440.0, 0.0, 2.0, 2.0, 0.40),
                (880.0, 0.0, 2.0, 2.8, 0.20),
                (1320.0, 0.0, 2.0, 4.0, 0.10)
            ], totalDuration: 2.0)
            
        case 3:
            // رنين الكريستال (1046Hz + 2093Hz)
            return makeChime(tones: [
                (1046.50, 0.0, 1.4, 3.2, 0.40),
                (2093.00, 0.04, 1.4, 4.0, 0.25),
                (3135.96, 0.08, 1.2, 5.0, 0.10)
            ], totalDuration: 1.5)
            
        case 4:
            // نغمة إشعار صافية (ماريمبا G5 -> C6)
            return makeChime(tones: [
                (783.99, 0.00, 0.8, 4.5, 0.45),
                (1046.50, 0.12, 1.2, 3.5, 0.50)
            ], totalDuration: 1.2)
            
        case 5:
            // نقرة زجاجية رقيقة (قطرة ماء ناعمة)
            return makeChime(tones: [
                (1760.00, 0.00, 0.5, 7.0, 0.50),
                (2637.02, 0.02, 0.4, 8.5, 0.30)
            ], totalDuration: 0.6)
            
        case 6:
            // قيثارة روحانية (E5, G#5, B5, E6)
            return makeChime(tones: [
                (659.25, 0.00, 1.4, 3.2, 0.35),
                (830.61, 0.10, 1.4, 3.2, 0.35),
                (987.77, 0.20, 1.4, 3.2, 0.35),
                (1318.51, 0.30, 1.6, 2.5, 0.45)
            ], totalDuration: 1.8)
            
        case 7:
            // طمأنينة وسكينة (ترددات دافئة خافتة)
            return makeChime(tones: [
                (349.23, 0.00, 2.0, 2.0, 0.45),
                (523.25, 0.08, 2.0, 2.5, 0.35),
                (698.46, 0.16, 2.0, 3.0, 0.25)
            ], totalDuration: 2.0)
            
        default:
            return Data()
        }
    }
    
    private static func makeChime(tones: [(freq: Double, start: Double, duration: Double, decay: Double, gain: Double)], totalDuration: Double, sampleRate: Double = 44100.0) -> Data {
        let numSamples = Int(sampleRate * totalDuration)
        var pcmData = Data(capacity: numSamples * 2)
        
        for i in 0..<numSamples {
            let t = Double(i) / sampleRate
            var sample: Double = 0.0
            
            for tone in tones {
                if t >= tone.start && t < (tone.start + tone.duration) {
                    let dt = t - tone.start
                    let envelope = exp(-tone.decay * dt)
                    let fundamental = sin(2.0 * .pi * tone.freq * dt)
                    let harmonic = sin(4.0 * .pi * tone.freq * dt) * 0.2
                    sample += (fundamental + harmonic) * envelope * tone.gain
                }
            }
            
            sample = max(-0.95, min(0.95, sample))
            let intSample = Int16(sample * 32767.0)
            var leSample = intSample.littleEndian
            withUnsafeBytes(of: &leSample) { pcmData.append(contentsOf: $0) }
        }
        
        var header = Data()
        header.append(contentsOf: "RIFF".utf8)
        let chunkSize = UInt32(36 + pcmData.count).littleEndian
        withUnsafeBytes(of: chunkSize) { header.append(contentsOf: $0) }
        header.append(contentsOf: "WAVE".utf8)
        header.append(contentsOf: "fmt ".utf8)
        let subchunk1Size = UInt32(16).littleEndian
        withUnsafeBytes(of: subchunk1Size) { header.append(contentsOf: $0) }
        let audioFormat = UInt16(1).littleEndian
        withUnsafeBytes(of: audioFormat) { header.append(contentsOf: $0) }
        let numChannels = UInt16(1).littleEndian
        withUnsafeBytes(of: numChannels) { header.append(contentsOf: $0) }
        let sRate = UInt32(sampleRate).littleEndian
        withUnsafeBytes(of: sRate) { header.append(contentsOf: $0) }
        let byteRate = UInt32(sampleRate * 2).littleEndian
        withUnsafeBytes(of: byteRate) { header.append(contentsOf: $0) }
        let blockAlign = UInt16(2).littleEndian
        withUnsafeBytes(of: blockAlign) { header.append(contentsOf: $0) }
        let bitsPerSample = UInt16(16).littleEndian
        withUnsafeBytes(of: bitsPerSample) { header.append(contentsOf: $0) }
        header.append(contentsOf: "data".utf8)
        let subchunk2Size = UInt32(pcmData.count).littleEndian
        withUnsafeBytes(of: subchunk2Size) { header.append(contentsOf: $0) }
        
        return header + pcmData
    }
}

// MARK: - مدير الصوت (تشغيل الأصوات متجاوزاً الوضع الصامت)
public final class SoundManager: NSObject, AVAudioPlayerDelegate {
    public static let shared = SoundManager()
    
    private var audioPlayer: AVAudioPlayer?
    private var soundCache: [Int: Data] = [:]
    
    private override init() {
        super.init()
        configureAudioSession()
    }
    
    public func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            print("Failed to configure audio session: \(error)")
        }
    }
    
    public func play(soundId: Int) {
        // إذا كان المعرف قديماً (> 7) نحوله للافتراضي 1
        let resolvedId: Int
        if soundId > 7 {
            resolvedId = 1
        } else {
            resolvedId = soundId
        }
        
        // اهتزاز تفاعلي دائماً
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        
        // إذا كان صامتاً تماماً (0) نكتفي بالاهتزاز
        guard resolvedId > 0 else { return }
        
        // تفعيل جلسة الصوت بوضعية Playback لتخطي وضع الصامت (Silent Mode)
        configureAudioSession()
        
        let wavData: Data
        if let cached = soundCache[resolvedId] {
            wavData = cached
        } else {
            let generated = SoundSynthesizer.makeWav(for: resolvedId)
            guard !generated.isEmpty else { return }
            soundCache[resolvedId] = generated
            wavData = generated
        }
        
        do {
            audioPlayer?.stop()
            audioPlayer = try AVAudioPlayer(data: wavData)
            audioPlayer?.delegate = self
            audioPlayer?.volume = 1.0
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
        } catch {
            print("Audio playback error: \(error)")
        }
    }
    
    // تشغيل النغمة المحفوظة مباشرة (يُستدعى أيضاً في الخلفية وعند قفل الشاشة)
    public func playFromStorage() {
        let isEnabled = UserDefaults.standard.object(forKey: "fadhkuruni_target_sound_enabled") as? Bool ?? true
        guard isEnabled else { return }
        let soundId = (UserDefaults.standard.object(forKey: "fadhkuruni_target_sound_id") as? Int) ?? 1
        play(soundId: soundId)
    }
}

// MARK: - مدير الإشعارات وشاشة القفل (Lock Screen & Background Alert)
import UserNotifications

public final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    public static let shared = NotificationManager()
    
    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }
    
    public func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge, .timeSensitive]) { _, _ in
            Task { @MainActor in
                IconBadgeManager.shared.update(count: WatchSyncService.shared.currentCount)
            }
        }
    }
    
    public func triggerTargetNotification(zekr: String, count: Int) {
        let isEnabled = UserDefaults.standard.object(forKey: "fadhkuruni_target_sound_enabled") as? Bool ?? true
        guard isEnabled else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "فَاذْكُرُونِي - ما شاء الله! اكتمل الهدف 🎉"
        content.body = "تم بحمد الله إتمام \(count) مرة من: \(zekr)"
        let soundId = UserDefaults.standard.object(forKey: "fadhkuruni_target_sound_id") as? Int ?? 1
        if soundId > 0 {
            let resolvedId = (1...7).contains(soundId) ? soundId : 1
            do {
                let directory = try FileManager.default.url(for: .libraryDirectory, in: .userDomainMask,
                                                             appropriateFor: nil, create: true)
                    .appendingPathComponent("Sounds", isDirectory: true)
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                let name = "target-\(resolvedId).wav"
                try SoundSynthesizer.makeWav(for: resolvedId).write(to: directory.appendingPathComponent(name), options: .atomic)
                content.sound = UNNotificationSound(named: UNNotificationSoundName(rawValue: name))
            } catch {
                content.sound = .default
            }
        }
        
        let request = UNNotificationRequest(
            identifier: "fadhkuruni_target_completion",
            content: content,
            trigger: nil // يطلق فوراً ليضيء شاشة القفل ويصدر التنبيه
        )
        
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }
    
    public func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        let identifier = notification.request.identifier
        if identifier.hasPrefix("fadhkuruni.prayer.") {
            let prayerID = String(identifier.dropFirst("fadhkuruni.prayer.".count))
            Task { @MainActor in
                PrayerAdhanRecorder.shared.playFullAdhan(for: prayerID)
            }
        } else if identifier.hasPrefix("fadhkuruni.test.prayer.") {
            let prayerID = String(identifier.dropFirst("fadhkuruni.test.prayer.".count))
            Task { @MainActor in
                PrayerAdhanRecorder.shared.playFullAdhan(for: prayerID)
            }
        }
        completionHandler([.banner, .list, .sound])
    }

    public func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let identifier = response.notification.request.identifier
        if identifier.hasPrefix("fadhkuruni.prayer.") {
            let prayerID = String(identifier.dropFirst("fadhkuruni.prayer.".count))
            Task { @MainActor in
                PrayerAdhanRecorder.shared.playFullAdhan(for: prayerID)
            }
        } else if identifier.hasPrefix("fadhkuruni.test.prayer.") {
            let prayerID = String(identifier.dropFirst("fadhkuruni.test.prayer.".count))
            Task { @MainActor in
                PrayerAdhanRecorder.shared.playFullAdhan(for: prayerID)
            }
        }
        completionHandler()
    }
}

// MARK: - إعدادات ونغمات التنبيه عند اكتمال الهدف
public struct TargetSoundItem: Identifiable, Hashable {
    public let id: Int
    public let name: String
    public let icon: String
    public let description: String
    
    public static let defaultSounds: [TargetSoundItem] = [
        TargetSoundItem(id: 1, name: "نغمة الإنجاز والبهجة (افتراضي)", icon: "sparkles", description: "نغمة متناسقة مبهجة عند إكمال الورد"),
        TargetSoundItem(id: 2, name: "جرس هادئ ومريح", icon: "bell.fill", description: "رنين جرس دافئ وهادئ ومريح للنفس"),
        TargetSoundItem(id: 3, name: "رنين الكريستال الصافي", icon: "diamond.fill", description: "صوت كريستالي لطيف وصافٍ جداً"),
        TargetSoundItem(id: 4, name: "نغمة إشعار صافية", icon: "speaker.wave.3.fill", description: "نغمة تنبيه عصرية وواضحة (ماريمبا)"),
        TargetSoundItem(id: 5, name: "نقرة زجاجية رقيقة", icon: "drop.fill", description: "صوت قطرة أو نقرة زجاجية ناعمة"),
        TargetSoundItem(id: 6, name: "قيثارة روحانية", icon: "music.quarternote.3", description: "أوتار قيثارة هادئة ومتصاعدة تبعث على السكينة"),
        TargetSoundItem(id: 7, name: "طمأنينة وسكينة", icon: "star.fill", description: "نغمة تأملية هادئة ومنخفضة الوقع"),
        TargetSoundItem(id: 0, name: "صامت (اهتزاز فقط)", icon: "speaker.slash.fill", description: "تنبيه بالاهتزاز التفاعلي فقط دون إصدار صوت")
    ]
    
    public static func play(soundId: Int) {
        SoundManager.shared.play(soundId: soundId)
    }
}

public struct PhoneCompanionView: View {
    @ObservedObject private var watchAccess = WatchPurchaseAccess.shared
    @AppStorage(TapFeedbackPreference.soundEnabledKey) private var isTapSoundEnabled = true
    @ObservedObject private var sync = WatchSyncService.shared
    @State private var selectedTab = 0
    @State private var showQiblaInCard = false
    @State private var showPrayerTimesInCard = false
    @State private var isPickingWatchPhoto = false
    @State private var selectedWatchPhotoItem: PhotosPickerItem?
    @ObservedObject private var qibla = PhoneQiblaManager.shared
    @ObservedObject private var prayerTimes = PrayerTimesManager.shared
    
    // Add/Edit State
    @State private var showAddSheet = false
    @State private var newZekrTitle = ""
    @State private var newZekrTarget = 33
    
    @State private var editingItem: ZekrItem? = nil
    @State private var editZekrTitle = ""
    @State private var editZekrTarget = 33
    
    @State private var pendingDeletion: [ZekrItem] = []
    @State private var showDeleteConfirmation = false
    @State private var showResetAlert = false
    @State private var azkarRestoreErrorMessage: String?
    @State private var showCounterResetConfirmation = false
    @State private var pendingCounterReset: ZekrItem?
    @AppStorage("fadhkuruni_buttons_locked") private var isButtonsLocked = false
    @AppStorage("fadhkuruni_phone_counter_cover") private var isPhoneCounterCoverActive = false
    
    // صوت التنبيه عند وصول الهدف
    @AppStorage("fadhkuruni_target_sound_id") private var selectedTargetSoundId: Int = 1
    @AppStorage("fadhkuruni_target_sound_enabled") private var isTargetSoundEnabled: Bool = true
    @State private var hasAlertedForCurrentTarget: Bool = false
    // A single physical touch can occasionally reach overlapping SwiftUI gesture layers.
    // Keep rapid intentional tasbih responsive while ignoring a duplicate callback.
    @State private var lastPhoneIncrementTime: Date = .distantPast
    @Environment(\.scenePhase) private var scenePhase

    // تفاعل حركة وانضغاط زر الحجب تحت الإصبع أثناء الضغط المطول
    @State private var isPressingCoverOnPhone: Bool = false
    @State private var isPressingToolbarCover: Bool = false

    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            ZStack {
                switch selectedTab {
                case 0:
                    counterTabView
                case 1:
                    azkarTabView
                case 2:
                    settingsTabView
                case 3:
                    NavigationStack { DhikrRemindersView() }
                default:
                    counterTabView
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // إخفاء التبويبات عند القفل مع حجز مساحتها لإبقاء أدوات التحكم ثابتة.
            customBottomTabBar
                .opacity(isButtonsLocked ? 0 : 1)
                .allowsHitTesting(!isButtonsLocked)
                .accessibilityHidden(isButtonsLocked)
                .overlay {
                    if isButtonsLocked {
                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture { incrementPhoneCount() }
                            .accessibilityHidden(true)
                    }
                }
        }
        .alert("تصفير عدّاد الذكر؟", isPresented: $showCounterResetConfirmation, presenting: pendingCounterReset) { item in
            Button("إلغاء", role: .cancel) { pendingCounterReset = nil }
            Button("قبول", role: .destructive) {
                if sync.currentZekr == item.title { hasAlertedForCurrentTarget = false }
                sync.resetZekrCount(for: item)
                pendingCounterReset = nil
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
            }
        } message: { item in
            Text("سيُصفّر عدّاد «\(item.title)» فقط، وسيبقى الذكر والهدف محفوظين. هل تريد المتابعة؟")
        }
        .preferredColorScheme(isButtonsLocked ? .light : nil)
        .background(
            (isButtonsLocked ? Color.white : Color(UIColor.systemBackground))
                .ignoresSafeArea()
        )
        .tint(.green)
        .ignoresSafeArea(.keyboard)
        .onAppear {
            sync.activateSession()
            if selectedTargetSoundId > 7 {
                selectedTargetSoundId = 1
            }
            if sync.currentCount >= sync.target && sync.target > 0 {
                hasAlertedForCurrentTarget = true
            }
            
            // إبقاء شاشة الآيفون مضاءة طالما التطبيق مفتوح لمنع الخفوت والقفل التلقائي
            UIApplication.shared.isIdleTimerDisabled = true
            
            // تهيئة الصوت والإشعارات بشكل غير تزامني لتفادي أي تجميد للشاشة عند بدء التشغيل
            NotificationManager.shared.requestAuthorization()
            
            // إرسال المزامنة بعد اكتمال تحميل الواجهة بسلاسة لتفادي أي تعارض في الخيوط

        }
        .onChange(of: scenePhase) { _, newPhase in
            UIApplication.shared.isIdleTimerDisabled = (newPhase == .active)
            if newPhase == .active {
                sync.activateSession()
                if showQiblaInCard {
                    PhoneQiblaManager.shared.start()
                }
                if showPrayerTimesInCard {
                    PrayerTimesManager.shared.refresh()
                }
            } else {
                if showQiblaInCard {
                    PhoneQiblaManager.shared.stop()
                }
            }
        }
        .onDisappear {
            // إعادة ضبط مؤقت القفل التلقائي عند الخروج من التطبيق
            UIApplication.shared.isIdleTimerDisabled = false
            if showQiblaInCard {
                PhoneQiblaManager.shared.stop()
            }
        }
        .onChange(of: selectedTab) { _, newTab in
            if newTab != 0 && (showQiblaInCard || showPrayerTimesInCard) {
                withAnimation {
                    showQiblaInCard = false
                    showPrayerTimesInCard = false
                    PhoneQiblaManager.shared.stop()
                }
            }
        }
        .onChange(of: sync.currentCount) { _, newCount in
            handleCountChange(newCount: newCount)
        }
        .onChange(of: sync.target) { _, newTarget in
            if sync.currentCount < newTarget {
                hasAlertedForCurrentTarget = false
            }
        }
        .onChange(of: sync.currentZekr) { _, _ in
            hasAlertedForCurrentTarget = (sync.currentCount >= sync.target && sync.target > 0)
        }
        .photosPicker(isPresented: $isPickingWatchPhoto, selection: $selectedWatchPhotoItem, matching: .images)
        .onChange(of: selectedWatchPhotoItem) { _, item in
            guard let item else { return }
            Task {
                guard let sourceData = try? await item.loadTransferable(type: Data.self),
                      let compactData = compactWatchPhoto(from: sourceData) else { return }
                sync.setWatchClockPhoto(compactData)
                sync.setWatchClockCover(true)
            }
        }
    }

    private func compactWatchPhoto(from data: Data) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        let maximumEdge: CGFloat = 280
        let scale = min(1, maximumEdge / max(image.size.width, image.size.height))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: size)
        let resized = renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
        return resized.jpegData(compressionQuality: 0.62)
    }
    
    // MARK: - Counter Tab
    private var counterTabView: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                // 1. كامل مساحة شاشة الآيفون: تصبح كلها مساحة تسبيح تفاعلية ومؤمّنة 100%
                VStack(spacing: 0) {
                    Spacer(minLength: 16)
                    
                    // نوع الذكر الحالي أو عنوان القبلة
                    VStack(spacing: 6) {
                        Text(showPrayerTimesInCard ? "مواقيت الصلاة" : (showQiblaInCard ? "بوصلة القبلة الشريفة" : "الذكر الحالي"))
                            .font(.subheadline)
                            .foregroundColor(isButtonsLocked ? Color.black.opacity(0.5) : .secondary)
                        
                        Text(showPrayerTimesInCard ? "بحسب موقعك اليوم" : (showQiblaInCard ? "وجّه الهاتف نحو الكعبة" : sync.currentZekr))
                            .font(.system(size: (showQiblaInCard || showPrayerTimesInCard) ? 24 : 28, weight: .bold))
                            .foregroundColor(isButtonsLocked ? .black : .primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.30)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                            .frame(height: 34)
                    }
                    
                    Spacer(minLength: 12)
                    
                    // بطاقة العداد الكبيرة والهدف
                    counterCardView
                    
                    Spacer(minLength: 12)
                    
                    // إرشاد النقر على الشاشة
                    HStack(spacing: 6) {
                        Image(systemName: showPrayerTimesInCard ? "clock.fill" : (showQiblaInCard ? "safari.fill" : "hand.tap.fill"))
                            .font(.footnote)
                        Text(showPrayerTimesInCard ? "المس زر المواقيت بأعلى الشاشة للعودة للعدّاد" : (showQiblaInCard ? "المس زر القبلة بأعلى الشاشة للعودة للعدّاد" : "المس في أي مكان بالشاشة للتسبيح"))
                            .font(.subheadline)
                    }
                    .foregroundColor(isButtonsLocked ? Color.black.opacity(0.6) : .secondary)
                    .offset(y: 10)

                    if isButtonsLocked && !showQiblaInCard && !showPrayerTimesInCard {
                        floatingErrorLockControls
                            .padding(.top, 22)
                            .padding(.bottom, 4)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    
                    Spacer(minLength: 84)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                // إيماءة تغطي كامل شاشة الآيفون من الحافة للحافة
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onEnded { value in
                            if showQiblaInCard || showPrayerTimesInCard {
                                return
                            }
                            let h = value.translation.width
                            let v = value.translation.height
                            if abs(h) < 20 && abs(v) < 20 {
                                // نقرة في أي مكان على كامل الشاشة للعد
                                incrementPhoneCount()
                            } else if !isButtonsLocked && h < -40 {
                                // تغيير الذكر بالسحب متاح فقط عند فتح القفل
                                sync.selectNextZekr()
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            } else if !isButtonsLocked && h > 40 {
                                // تغيير الذكر بالسحب متاح فقط عند فتح القفل
                                sync.selectPreviousZekr()
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            } else if isButtonsLocked {
                                // عند القفل: حتى لو كانت سحبة نحسبها تسبيحة لعدم تفويت أي لمسة
                                incrementPhoneCount()
                            }
                        }
                )
                
                // يبقى شريط أدوات العد وحده أسفل الشاشة؛ المتبقي للصلاة داخل مربع المواقيت.
                bottomControlBar
                .padding(.horizontal, 16)
                .padding(.bottom, 6)
                .opacity((showQiblaInCard || showPrayerTimesInCard || isButtonsLocked) ? 0 : 1)
                .allowsHitTesting(!(showQiblaInCard || showPrayerTimesInCard || isButtonsLocked))

            }
            .background(
                (isButtonsLocked ? Color.white : Color(UIColor.systemBackground))
                    .ignoresSafeArea()
            )
            .navigationTitle("فَاذْكُرُونِي")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(isButtonsLocked ? Color.white : Color.clear, for: .navigationBar)
            .toolbarBackground(isButtonsLocked ? .visible : .automatic, for: .navigationBar)
            .toolbar {
                // أثناء قفل العداد يبقى عنوان شريط التنقل خارج مساحة العداد؛
                // لذلك يكون العنوان نفسه منطقة تسبيح بدون إظهار أي أزرار إضافية.
                ToolbarItem(placement: .principal) {
                    if isButtonsLocked {
                        Button(action: incrementPhoneCount) {
                            Text("فَاذْكُرُونِي")
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(.primary)
                                .frame(width: 250, height: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("التسبيح")
                        .accessibilityHint("المس لإضافة تسبيحة")
                    }
                }

                ToolbarItem(placement: .navigationBarLeading) {
                    if !isButtonsLocked {
                        HStack(spacing: 8) {
                            NavigationLink { PurchasedWatchSettingsGate { WatchGuideView() } } label: {
                                Image(systemName: "applewatch")
                                    .accessibilityLabel("فاذكروني على الساعة — صور وطريقة الاستخدام")
                            }

                            Button {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
                                    sync.setWatchClockCover(!sync.showsWatchClockCover)
                                }
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            } label: {
                                watchClockCoverButton
                            }
                            .disabled(showQiblaInCard || showPrayerTimesInCard)
                            .opacity((showQiblaInCard || showPrayerTimesInCard) ? 0.35 : 1)
                            .simultaneousGesture(
                                LongPressGesture(minimumDuration: 0.45)
                                    .onEnded { _ in isPickingWatchPhoto = true }
                            )
                            .simultaneousGesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { _ in
                                        if !isPressingToolbarCover {
                                            isPressingToolbarCover = true
                                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                        }
                                    }
                                    .onEnded { _ in
                                        isPressingToolbarCover = false
                                    }
                            )
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !isButtonsLocked {
                        HStack(spacing: 10) {
                            Button {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    showPrayerTimesInCard = false
                                    showQiblaInCard.toggle()
                                    if showQiblaInCard {
                                        PhoneQiblaManager.shared.start()
                                    } else {
                                        PhoneQiblaManager.shared.stop()
                                    }
                                }
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(showQiblaInCard ? Color.green : Color.green.opacity(0.14))
                                        .frame(width: 34, height: 34)
                                        .overlay(
                                            Circle()
                                                .strokeBorder(Color.green.opacity(0.35), lineWidth: 0.8)
                                        )
                                    Image(systemName: "safari.fill")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(showQiblaInCard ? Color.black : Color.green)
                                }
                                .accessibilityLabel(showQiblaInCard ? "العودة للعدّاد" : "اتجاه القبلة")
                            }

                            Button {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    if showPrayerTimesInCard {
                                        showPrayerTimesInCard = false
                                    } else {
                                        showQiblaInCard = false
                                        PhoneQiblaManager.shared.stop()
                                        showPrayerTimesInCard = true
                                        PrayerTimesManager.shared.refresh()
                                    }
                                }
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(showPrayerTimesInCard ? Color.green : Color.green.opacity(0.14))
                                        .frame(width: 34, height: 34)
                                        .overlay(Circle().strokeBorder(Color.green.opacity(0.35), lineWidth: 0.8))
                                    Image(systemName: "clock.fill")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(showPrayerTimesInCard ? Color.black : Color.green)
                                }
                                .accessibilityLabel(showPrayerTimesInCard ? "العودة للعدّاد" : "مواقيت الصلاة")
                            }
                        }
                    }
                }
            }
        }
    }
    
    private var watchClockCoverButton: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: sync.showsWatchClockCover
                            ? [Color(red: 0.05, green: 0.66, blue: 0.47), Color(red: 0.02, green: 0.25, blue: 0.23)]
                            : [Color.white.opacity(0.82), Color.mint.opacity(0.24), Color.green.opacity(0.10)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 44, height: 44)
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [.white.opacity(0.9), Color.mint.opacity(0.38), .white.opacity(0.16)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.15
                        )
                }
                .shadow(color: Color.mint.opacity(sync.showsWatchClockCover ? 0.38 : 0.15), radius: 10, y: 5)

            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: 31, height: 31)
                .overlay {
                    Circle().strokeBorder(.white.opacity(0.38), lineWidth: 0.7)
                }

            Image(systemName: sync.showsWatchClockCover ? "eye.slash.fill" : "eye.fill")
                .font(.system(size: 17, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(sync.showsWatchClockCover ? .white : Color.green)
                .shadow(color: sync.showsWatchClockCover ? .black.opacity(0.22) : .white.opacity(0.6), radius: 2, y: 1)

            Image(systemName: sync.showsWatchClockCover ? "checkmark" : "clock.fill")
                .font(.system(size: 7, weight: .heavy))
                .foregroundStyle(sync.showsWatchClockCover ? Color.green : .white)
                .frame(width: 14, height: 14)
                .background(sync.showsWatchClockCover ? Color.white : Color.green, in: Circle())
                .overlay(Circle().strokeBorder(.white.opacity(0.85), lineWidth: 0.7))
                .offset(x: 14, y: 14)
        }
        .scaleEffect(isPressingToolbarCover ? 0.84 : 1.0)
        .offset(y: isPressingToolbarCover ? 2.0 : 0)
        .animation(.spring(response: 0.25, dampingFraction: 0.65), value: isPressingToolbarCover)
        .accessibilityLabel(sync.showsWatchClockCover ? "إظهار رقم عداد الساعة" : "عرض الوقت بدل رقم عداد الساعة")
    }

    // MARK: - بطاقة العداد والهدف وخلفيتها
    private var counterCardBackground: some View {
        RoundedRectangle(cornerRadius: 38, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay {
                RoundedRectangle(cornerRadius: 38, style: .continuous)
                    .fill(LinearGradient(colors: [.clear, Color.green.opacity(isButtonsLocked ? 0.04 : 0.12)], startPoint: .top, endPoint: .bottom))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 38, style: .continuous)
                    .strokeBorder(LinearGradient(colors: [Color.primary.opacity(0.16), Color.green.opacity(0.12), Color.primary.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 0.8)
            }
            .shadow(color: .green.opacity(0.07), radius: 18, y: 8)
            .accessibilityHidden(true)
    }

    private var counterCardView: some View {
        Group {
            if showPrayerTimesInCard {
                prayerTimesCardContent
            } else if showQiblaInCard {
                qiblaCardContent
            } else if isButtonsLocked && isPhoneCounterCoverActive {
                lockedCounterCardContent
            } else {
                normalCounterCardContent
            }
        }
    }

    // Reuse the watch cover's original photo and clock appearance without changing count state.
    private var lockedCounterCardContent: some View {
        ZStack(alignment: .bottom) {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                PhoneLockedCounterCover(date: context.date, photoData: sync.watchClockPhotoData)
                    // The privacy photo now occupies the same main card space as
                    // the counter, qibla, and prayer-times views.
                    .scaleEffect(2.18)
                    .frame(width: 296, height: 296)
            }
            .allowsHitTesting(false)
            .accessibilityLabel("غطاء عدّاد الذكر")

        }
        .frame(maxHeight: .infinity)
        .frame(maxWidth: .infinity, minHeight: 360, maxHeight: 360, alignment: .top)
        .background(counterCardBackground)
        .padding(.horizontal, 16)
    }

    private var prayerTimesCardContent: some View {
        VStack(spacing: 10) {
            HStack {
                Label("مواقيت الصلاة", systemImage: "clock.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.green)
                Spacer()
                if prayerTimes.isLoading {
                    ProgressView().controlSize(.small)
                } else if let next = prayerTimes.times.first(where: { $0.date > Date() }) {
                    Text("القادمة: \(next.title)")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 10)

            if prayerTimes.times.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: prayerTimes.isLoading ? "location.circle" : "location.slash")
                        .font(.system(size: 44, weight: .light))
                        .foregroundStyle(.green)
                    Text(prayerTimes.statusMessage)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button("تحديث الموقع") { PrayerTimesManager.shared.refresh() }
                        .buttonStyle(.bordered)
                        .tint(.green)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                TimelineView(.periodic(from: .now, by: 30)) { timeline in
                    if let schedule = upcomingPrayer(at: timeline.date) {
                        HStack(spacing: 10) {
                            Image(systemName: schedule.prayer.symbol)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.green)
                                .frame(width: 34, height: 34)
                                .background(Color.green.opacity(0.13), in: Circle())
                            VStack(alignment: .leading, spacing: 1) {
                                Text("الصلاة القادمة: \(schedule.prayer.title)")
                                    .font(.caption.weight(.bold))
                                Text(schedule.prayer.date.formatted(date: .omitted, time: .shortened))
                                    .font(.caption2.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 3) {
                                Text(schedule.remainingText)
                                    .font(.caption.weight(.bold))
                                GeometryReader { geometry in
                                    Capsule()
                                        .fill(Color.green.opacity(0.12))
                                        .overlay(alignment: .leading) {
                                            Capsule()
                                                .fill(LinearGradient(colors: [.green, .mint], startPoint: .leading, endPoint: .trailing))
                                                .frame(width: geometry.size.width * CGFloat(schedule.progress))
                                        }
                                }
                                .frame(width: 72, height: 4)
                            }
                            .foregroundStyle(.green)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay { RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Color.green.opacity(0.18), lineWidth: 0.8) }
                    }
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                    ForEach(prayerTimes.times) { prayer in
                        HStack(spacing: 7) {
                            Image(systemName: prayer.symbol)
                                .font(.caption)
                                .foregroundStyle(prayer.date > Date() ? .green : .secondary)
                                .frame(width: 17)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(prayer.title).font(.caption.weight(.semibold))
                                Text(prayer.date.formatted(date: .omitted, time: .shortened))
                                    .font(.caption2.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(prayer.date > Date() ? Color.green.opacity(0.09) : Color.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                    }
                }
                HStack(spacing: 8) {
                    NavigationLink {
                        PrayerTimeAdjustmentsView()
                    } label: {
                        Label("التعديلات اليدوية", systemImage: "slider.horizontal.3")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.green)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.green.opacity(0.10), in: Capsule())
                    }
                    .buttonStyle(.plain)
                    Spacer()
                    Text(prayerTimes.statusMessage)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Button {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    showPrayerTimesInCard = false
                }
            } label: {
                Label("العودة لعدّاد التسبيح", systemImage: "arrow.uturn.backward")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.green)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 5)
                    .background(Color.green.opacity(0.10), in: Capsule())
            }
        }
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, minHeight: 360, maxHeight: 360, alignment: .top)
        .background(counterCardBackground)
        .padding(.horizontal, 16)
    }

    private var normalCounterCardContent: some View {
        VStack(spacing: 6) {
            // مساحة ثابتة تطابق شريط معلومات القبلة، فتظل الدائرتان في الموضع نفسه.
            Color.clear.frame(height: 14)
            ZStack {
                Circle().stroke(Color.green.opacity(0.10), lineWidth: 7)
                Circle()
                    .trim(from: 0, to: sync.target > 0 ? min(1, max(0, Double(sync.currentCount) / Double(sync.target))) : 0)
                    .stroke(LinearGradient(colors: [.green.opacity(0.55), .mint], startPoint: .bottomLeading, endPoint: .topTrailing), style: StrokeStyle(lineWidth: 7, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .accessibilityHidden(true)
                VStack(spacing: 4) {
                    Text(sync.currentCount.formatted())
                        .font(.system(size: 72, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.45)
                        .foregroundStyle(.green)
                        .contentTransition(.numericText())
                    Text("الهدف \(sync.target.formatted())")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(isButtonsLocked ? Color.black.opacity(0.6) : .secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .padding(20)

            }
            .frame(width: 190, height: 190)
            .environment(\.layoutDirection, .leftToRight)
            .scaleEffect(isPressingCoverOnPhone ? 0.91 : 1.0)
            .offset(y: isPressingCoverOnPhone ? 3.5 : 0)
            .shadow(color: Color.mint.opacity(isPressingCoverOnPhone ? 0.45 : 0), radius: isPressingCoverOnPhone ? 18 : 0)
            .animation(.spring(response: 0.28, dampingFraction: 0.65), value: isPressingCoverOnPhone)
            .contentShape(Circle())
            .onLongPressGesture(minimumDuration: 0.45) {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.55)) {
                    isPressingCoverOnPhone = false
                    sync.setWatchClockCover(!sync.showsWatchClockCover)
                }
                UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
            } onPressingChanged: { isPressing in
                withAnimation(.spring(response: 0.25, dampingFraction: 0.65)) {
                    isPressingCoverOnPhone = isPressing
                }
                if isPressing {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                        if isPressingCoverOnPhone {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }
                    }
                }
            }
            Text("\(max(0, sync.target - sync.currentCount).formatted()) مرات لإكمال الهدف")
                .font(.caption)
                .foregroundStyle(isButtonsLocked ? Color.black.opacity(0.6) : .secondary)
                .padding(.top, 4)

            // ملخصات الذكر تحت رقم مرات إكمال الهدف
            dhikrSummaryPill
                .padding(.top, 4)

            // مؤشر قفل الأخطاء
            HStack(spacing: 6) {
                Image(systemName: "lock.shield.fill")
                    .font(.caption2)
                Text("قفل العدّاد مفعّل: المس أي مكان للعدّ")
                    .font(.caption.bold())
            }
                .foregroundColor(.red)
                .padding(.horizontal, 14)
                .padding(.vertical, 4)
                .background(Color.red.opacity(0.12))
                .clipShape(Capsule())
                .padding(.top, 2)
                .opacity(isButtonsLocked ? 1 : 0)
                .accessibilityHidden(!isButtonsLocked)

        }
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity, minHeight: 360, maxHeight: 360, alignment: .top)
        .background(counterCardBackground)
        .padding(.horizontal, 16)
    }

    // MARK: - كبسولة ملخص الذكر اليومي داخل بطاقة العداد
    private var dhikrSummaryPill: some View {
        HStack(spacing: 6) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.green)

            Text(dhikrComparisonSummary)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(isButtonsLocked ? Color.black.opacity(0.7) : .primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Image(systemName: "chevron.left")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.secondary.opacity(0.6))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(Color.green.opacity(0.25), lineWidth: 0.8))
        .allowsHitTesting(false)
        .accessibilityLabel("ملخص الذكر: \(dhikrComparisonSummary)")
    }

    private var dhikrComparisonSummary: String {
        let current = sync.statistics.totalToday(for: sync.currentZekr)
        let previous = sync.statistics.totalYesterday(for: sync.currentZekr)
        guard previous > 0 else {
            return current > 0 ? "تسبيح اليوم: \(current.formatted())" : "ملخص الذكر اليوم: 0"
        }
        if current > previous {
            return "اليوم: \(current.formatted()) (أكثر من الأمس بـ \((current - previous).formatted()))"
        } else if current < previous {
            return "اليوم: \(current.formatted()) (أقل من الأمس بـ \((previous - current).formatted()))"
        } else {
            return "اليوم: \(current.formatted()) (مثل الأمس تماماً)"
        }
    }

    // MARK: - بطاقة القبلة والكعبة المدمجة داخل العداد
    private var qiblaCardContent: some View {
        VStack(spacing: 10) {
            // شريط علوي صغير للبطاقة
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "safari.fill")
                        .foregroundStyle(qibla.isAligned ? Color(red: 0.98, green: 0.75, blue: 0.14) : Color.green)
                    Text("اتجاه القبلة الشريفة")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.primary)
                }
                Spacer()
                if qibla.isAligned {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 10, weight: .bold))
                        Text("محاذاة تامة")
                            .font(.caption2.bold())
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 3.5)
                    .background(Color(red: 0.98, green: 0.75, blue: 0.14).opacity(0.20))
                    .foregroundColor(Color(red: 0.98, green: 0.75, blue: 0.14))
                    .clipShape(Capsule())
                } else if qibla.isReady {
                    Text("\(Int(round(qibla.qiblaBearing)))°")
                        .font(.caption2.monospacedDigit().bold())
                        .padding(.horizontal, 9)
                        .padding(.vertical, 3.5)
                        .background(Color.green.opacity(0.12))
                        .foregroundColor(.green)
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 10)

            // الدائرة المركزية
            ZStack {
                // الحلقة الخارجية
                Circle()
                    .stroke(
                        qibla.isAligned
                            ? LinearGradient(colors: [Color(red: 0.98, green: 0.75, blue: 0.14), Color.yellow, Color(red: 0.98, green: 0.75, blue: 0.14)], startPoint: .topLeading, endPoint: .bottomTrailing)
                            : LinearGradient(colors: [Color.green.opacity(0.35), Color.green.opacity(0.10)], startPoint: .topLeading, endPoint: .bottomTrailing),
                        lineWidth: qibla.isAligned ? 3.5 : 2
                    )
                    .frame(width: 190, height: 190)
                    .shadow(color: qibla.isAligned ? Color(red: 0.98, green: 0.75, blue: 0.14).opacity(0.40) : .clear, radius: 10)

                if qibla.isAligned {
                    // صورة الكعبة المشرفة تحت العدسة الزجاجية الكريستالية
                    ZStack {
                        // الطبقة 1: صورة الكعبة
                        Image("HolyKaaba")
                            .resizable()
                            .scaledToFill()
                            .frame(width: 174, height: 174)
                            .clipShape(Circle())

                        // الطبقة 2: عدسة زجاجية ياقوتية ثلاثية الأبعاد (Crystal Dome)
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        Color.white.opacity(0.48),
                                        Color.white.opacity(0.15),
                                        Color.black.opacity(0.32),
                                        Color.white.opacity(0.26)
                                    ],
                                    center: .init(x: 0.35, y: 0.25),
                                    startRadius: 0,
                                    endRadius: 90
                                )
                            )
                            .frame(width: 174, height: 174)
                            .overlay(
                                Circle()
                                    .strokeBorder(
                                        LinearGradient(
                                            colors: [
                                                Color.white.opacity(0.85),
                                                Color(red: 0.98, green: 0.75, blue: 0.14).opacity(0.45),
                                                Color.white.opacity(0.20)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 2
                                    )
                            )
                            // لمعة التقوس الكروي للزجاج
                            .overlay(alignment: .top) {
                                Ellipse()
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.white.opacity(0.70), Color.white.opacity(0.18), Color.clear],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    .frame(width: 108, height: 46)
                                    .padding(.top, 6)
                            }
                            // انعكاس الحافة السفلية للزجاج
                            .overlay(alignment: .bottom) {
                                Ellipse()
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.clear, Color.white.opacity(0.28)],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    .frame(width: 80, height: 15)
                                    .padding(.bottom, 6)
                            }
                    }
                    .transition(.scale(scale: 0.88).combined(with: .opacity))
                } else {
                    // بوصلة التوجيه
                    ZStack {
                        Circle()
                            .fill(Color.green.opacity(0.04))
                            .frame(width: 174, height: 174)

                        // علامات الجهات
                        VStack {
                            Text("ش")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.red)
                            Spacer()
                            Text("ج")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }
                        .frame(height: 166)

                        HStack {
                            Text("غ")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("ش")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }
                        .frame(width: 166)

                        // إبرة قبلة زجاجية — تدويرها يبقى مرتبطاً بالاتجاه الحقيقي للقبلة.
                        VStack(spacing: 0) {
                            ZStack {
                                Image(systemName: "location.north.fill")
                                    .font(.system(size: 33, weight: .bold))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [.white.opacity(0.97), .mint.opacity(0.9), .green.opacity(0.94)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                Image(systemName: "location.north.fill")
                                    .font(.system(size: 33, weight: .bold))
                                    .foregroundStyle(.white.opacity(0.38))
                                    .blur(radius: 0.8)
                                    .offset(x: -1.2, y: -1.2)
                            }
                            .shadow(color: .green.opacity(0.45), radius: 8, y: 3)
                        }
                        .rotationEffect(.degrees(qibla.needleAngle))
                        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: qibla.needleAngle)

                        // إرشاد الحركة
                        VStack {
                            Spacer()
                            let angle = qibla.needleAngle
                            Text(abs(angle) <= 12 ? "اقتربت من القبلة" : (angle > 0 ? "اتجه يميناً" : "اتجه يساراً"))
                                .font(.caption.bold())
                                .foregroundStyle(abs(angle) <= 12 ? Color(red: 0.98, green: 0.75, blue: 0.14) : Color.green)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 3)
                                .background(Color(UIColor.secondarySystemBackground).opacity(0.85))
                                .clipShape(Capsule())
                                .padding(.bottom, 20)
                        }
                    }
                }
            }
            .frame(width: 190, height: 190)

            // نص التوجيه أسفل الدائرة
            VStack(spacing: 3) {
                if qibla.isAligned {
                    HStack(spacing: 5) {
                        Circle().fill(Color(red: 0.98, green: 0.75, blue: 0.14)).frame(width: 7, height: 7)
                        Text("الكعبة المشرفة أمامك تماماً (\(Int(round(qibla.qiblaBearing)))°)")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Color(red: 0.98, green: 0.75, blue: 0.14))
                    }
                } else {
                    Text(qibla.statusMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.top, 2)

            // زر العودة لعداد التسبيح
            Button {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    showQiblaInCard = false
                    PhoneQiblaManager.shared.stop()
                }
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.caption2.bold())
                    Text("العودة لعدّاد التسبيح")
                        .font(.caption.weight(.semibold))
                }
                .foregroundStyle(.green)
                .padding(.horizontal, 14)
                .padding(.vertical, 5)
                .background(Color.green.opacity(0.10))
                .clipShape(Capsule())
            }
            .padding(.top, 2)
        }
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity, minHeight: 360, maxHeight: 360, alignment: .top)
        .background(counterCardBackground)
        .padding(.horizontal, 16)
    }
    
    // MARK: - الشريط السفلي لخيارات التحكم وقفل الأخطاء
    private var bottomControlBar: some View {
        HStack(spacing: 14) {
            Button { incrementPhoneCount() } label: {
                counterControlLabel(title: "زيادة", symbol: "plus", tint: .green, isPrimary: true)
            }
            .frame(maxWidth: .infinity)

            Button {
                sync.decrementCurrentZekr()
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } label: {
                counterControlLabel(title: "إنقاص", symbol: "minus", tint: .red)
            }
            .frame(maxWidth: .infinity)

            Button { resetPhoneCount() } label: {
                counterControlLabel(title: "تصفير", symbol: "arrow.counterclockwise", tint: .orange)
            }
            .frame(maxWidth: .infinity)

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isButtonsLocked = true
                }
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            } label: {
                counterControlLabel(title: "قفل العدّاد", symbol: "lock.shield.fill", tint: .red)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .environment(\.layoutDirection, .leftToRight)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background {
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(UIColor.secondarySystemBackground))
                .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
                .opacity(isButtonsLocked ? 0 : 1)
        }
    }

    private var floatingErrorLockControls: some View {
        VStack(spacing: 8) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isButtonsLocked = false
                    isPhoneCounterCoverActive = false
                }
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            } label: {
                counterControlLabel(title: "فتح قفل العداد", symbol: "lock.open.fill", tint: .red)
            }

            Button {
                isPhoneCounterCoverActive.toggle()
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            } label: {
                counterControlLabel(
                    title: isPhoneCounterCoverActive ? "إظهار العداد" : "حجب العداد",
                    symbol: isPhoneCounterCoverActive ? "eye.fill" : "eye.slash.fill",
                    tint: .green
                )
            }
        }
        .frame(width: 152)
        .buttonStyle(.plain)
    }

    // MARK: - موعد الصلاة القادمة
    private var nextPrayerSummaryCard: some View {
        TimelineView(.periodic(from: .now, by: 30)) { timeline in
            if let schedule = upcomingPrayer(at: timeline.date) {
                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        showQiblaInCard = false
                        PhoneQiblaManager.shared.stop()
                        showPrayerTimesInCard = true
                    }
                    PrayerTimesManager.shared.refresh()
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    VStack(alignment: .trailing, spacing: 8) {
                        HStack(spacing: 10) {
                            Image(systemName: schedule.prayer.symbol)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(.green)
                                .frame(width: 36, height: 36)
                                .background(Color.green.opacity(0.13), in: Circle())
                            VStack(alignment: .leading, spacing: 1) {
                                Text("الصلاة القادمة").font(.caption2.weight(.medium)).foregroundStyle(.secondary)
                                Text(schedule.prayer.title).font(.headline.weight(.bold)).foregroundStyle(.primary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 1) {
                                Text(schedule.prayer.date.formatted(date: .omitted, time: .shortened))
                                    .font(.subheadline.weight(.bold).monospacedDigit()).foregroundStyle(.green)
                                Text(schedule.remainingText).font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.green.opacity(0.12))
                                Capsule().fill(LinearGradient(colors: [.green, .mint], startPoint: .leading, endPoint: .trailing))
                                    .frame(width: geometry.size.width * CGFloat(schedule.progress))
                            }
                        }
                        .frame(height: 4)
                        if !schedule.following.isEmpty {
                            HStack(spacing: 8) {
                                ForEach(Array(schedule.following.prefix(2))) { prayer in
                                    Text("\(prayer.title) \(prayer.date.formatted(date: .omitted, time: .shortened))")
                                        .font(.caption2).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.left").font(.caption2.weight(.bold)).foregroundStyle(.green)
                            }
                        }
                    }
                    .padding(12)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay { RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Color.green.opacity(0.22), lineWidth: 0.8) }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("الصلاة القادمة: \(schedule.prayer.title)، \(schedule.remainingText)")
            } else {
                Button { PrayerTimesManager.shared.refresh() } label: {
                    Label("تحديث مواقيت الصلاة حسب موقعك", systemImage: "location.circle.fill")
                        .font(.subheadline.weight(.semibold)).foregroundStyle(.green).frame(maxWidth: .infinity).padding(.vertical, 12)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func upcomingPrayer(at now: Date) -> UpcomingPrayerInfo? {
        let prayerIDs: Set<String> = ["fajr", "dhuhr", "asr", "maghrib", "isha"]
        let today = prayerTimes.times.filter { prayerIDs.contains($0.id) }.sorted { $0.date < $1.date }
        guard !today.isEmpty else { return nil }
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? now
        let tomorrowTimes = today.map { prayer -> PrayerTime in
            let parts = calendar.dateComponents([.hour, .minute], from: prayer.date)
            let date = calendar.date(bySettingHour: parts.hour ?? 0, minute: parts.minute ?? 0, second: 0, of: tomorrow) ?? tomorrow
            return PrayerTime(id: "tomorrow-\(prayer.id)", title: prayer.title, symbol: prayer.symbol, date: date)
        }
        let all = (today + tomorrowTimes).sorted { $0.date < $1.date }
        guard let nextIndex = all.firstIndex(where: { $0.date > now }) else { return nil }
        let next = all[nextIndex]
        let previous = nextIndex > 0 ? all[nextIndex - 1] : PrayerTime(id: "previous-\(next.id)", title: next.title, symbol: next.symbol, date: next.date.addingTimeInterval(-3 * 60 * 60))
        let interval = max(1, next.date.timeIntervalSince(previous.date))
        let elapsed = min(max(0, now.timeIntervalSince(previous.date)), interval)
        return UpcomingPrayerInfo(prayer: next, following: Array(all.dropFirst(nextIndex + 1).prefix(2)), progress: elapsed / interval, remainingText: prayerRemainingText(until: next.date, from: now))
    }

    private func prayerRemainingText(until date: Date, from now: Date) -> String {
        let minutes = max(1, Int((date.timeIntervalSince(now) / 60.0).rounded(.up)))
        if minutes < 60 { return "بعد \(minutes) د" }
        let hours = minutes / 60
        let remainder = minutes % 60
        return remainder == 0 ? "بعد \(hours) س" : "بعد \(hours) س \(remainder) د"
    }

    private func counterControlLabel(title: String, symbol: String, tint: Color, isPrimary: Bool = false) -> some View {
        VStack(spacing: 4) {
            Image(systemName: symbol)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(isPrimary ? Color.white : tint)
                .frame(width: 52, height: 52)
                .fadhkuruniGlass(tint: isPrimary ? .green : tint, radius: 26)
            Text(title)
                .font(.caption2.bold())
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(minHeight: 16)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
    }

    // MARK: - شريط التبويبات السفلي
    private var customBottomTabBar: some View {
        HStack(spacing: 0) {
            // 1. زر العداد
            Button {
                selectedTab = 0
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "timer")
                        .font(.system(size: 20, weight: selectedTab == 0 ? .bold : .regular))
                    Text("العداد")
                        .font(.system(size: 11, weight: selectedTab == 0 ? .bold : .medium))
                }
                .foregroundColor(selectedTab == 0 ? .green : .secondary)
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            // 2. زر الأذكار والأهداف
            Button {
                selectedTab = 1
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "list.bullet")
                        .font(.system(size: 20, weight: selectedTab == 1 ? .bold : .regular))
                    Text("الأذكار والأهداف")
                        .font(.system(size: 11, weight: selectedTab == 1 ? .bold : .medium))
                }
                .accessibilityLabel("الأذكار والأهداف")
                .foregroundColor(selectedTab == 1 ? .green : .secondary)
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            // 3. زر التذكيرات
            Button {
                selectedTab = 3
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "bell.badge.fill")
                        .font(.system(size: 20, weight: selectedTab == 3 ? .bold : .regular))
                    Text("التذكيرات")
                        .font(.system(size: 11, weight: selectedTab == 3 ? .bold : .medium))
                }
                .accessibilityLabel("التذكيرات")
                .foregroundColor(selectedTab == 3 ? .green : .secondary)
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // 4. زر الإعدادات
            Button {
                selectedTab = 2
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 20, weight: selectedTab == 2 ? .bold : .regular))
                    Text("الإعدادات")
                        .font(.system(size: 11, weight: selectedTab == 2 ? .bold : .medium))
                }
                .accessibilityLabel("الإعدادات")
                .foregroundColor(selectedTab == 2 ? .green : .secondary)
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 8)
        .padding(.bottom, 6)
        .fadhkuruniGlass(radius: 24)
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(Color(UIColor.separator)),
            alignment: .top
        )
    }
    
    private func incrementPhoneCount() {
        let now = Date()
        guard now.timeIntervalSince(lastPhoneIncrementTime) > 0.12 else { return }
        lastPhoneIncrementTime = now
        guard let reachedGoal = sync.incrementCurrentZekr() else { return }
        TapFeedback.shared.play(goalReached: reachedGoal)
    }
    
    private func resetPhoneCount() {
        guard let item = sync.azkarList.first(where: { $0.title == sync.currentZekr }) else { return }
        requestCounterReset(item)
    }

    private func requestCounterReset(_ item: ZekrItem) {
        pendingCounterReset = item
        showCounterResetConfirmation = true
    }
    
    // فحص اكتمال الهدف وإطلاق التنبيه الصوتي والاهتزاز
    private func handleCountChange(newCount: Int) {
        if newCount < sync.target || newCount == 0 {
            hasAlertedForCurrentTarget = false
        } else if newCount == sync.target && !hasAlertedForCurrentTarget {
            hasAlertedForCurrentTarget = true
            // WatchSyncService owns the completion sound and notification.
        }
    }

    // تشغيل الصوت المختار والاهتزاز في الآيفون
    private func playTargetAlert() {
        if isTargetSoundEnabled && selectedTargetSoundId > 0 {
            TargetSoundItem.play(soundId: selectedTargetSoundId)
        } else {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }
    
    // MARK: - Azkar Tab (Add / Edit / Delete)
    private var azkarTabView: some View {
        NavigationStack {
            List {
                Section {
                    Button(action: {
                        newZekrTitle = ""
                        newZekrTarget = 33
                        showAddSheet = true
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                                .foregroundColor(.green)
                            Text("إضافة ذكر جديد")
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                Section(header: Text("قائمة الأذكار — الحذف للأذكار المضافة فقط")) {
                    ForEach(sync.azkarList) { item in
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.title)
                                    .font(.headline)
                                    .foregroundColor(sync.currentZekr == item.title ? .green : .primary)
                                
                                HStack(spacing: 8) {
                                    Text("المنجز: \(item.count) مرة")
                                        .font(.caption.bold())
                                        .foregroundColor(.green)
                                    
                                    Text("•")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    
                                    Text("الهدف: \(item.defaultTarget) مرة")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                            
                            Button(action: {
                                editZekrTitle = item.title
                                editZekrTarget = item.defaultTarget
                                editingItem = item
                            }) {
                                Image(systemName: "pencil.circle")
                                    .font(.title2)
                                    .foregroundColor(.blue)
                            }
                            .buttonStyle(BorderlessButtonStyle())
                        }
                        .deleteDisabled(item.isBuiltIn)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            sync.selectZekr(item)
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedTab = 0
                            }
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: false) {
                            Button {
                                requestCounterReset(item)
                            } label: {
                                Label("تصفير العداد", systemImage: "arrow.counterclockwise")
                            }
                            .tint(.orange)
                        }
                    }
                    .onDelete { offsets in
                        pendingDeletion = offsets.map { sync.azkarList[$0] }.filter { !$0.isBuiltIn }
                        showDeleteConfirmation = !pendingDeletion.isEmpty
                    }
                }
                
                Section {
                    Button(role: .destructive, action: {
                        showResetAlert = true
                    }) {
                        HStack {
                            Image(systemName: "arrow.counterclockwise")
                            Text("استعادة الأذكار المدمجة الافتراضية")
                        }
                    }
                }
            }
            .navigationTitle("الأذكار والأهداف")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
            }
            // Sheet: Add New Zekr
            .sheet(isPresented: $showAddSheet) {
                NavigationStack {
                    Form {
                        Section(header: Text("نص الذكر")) {
                            TextField("مثال: سبحان الله وبحمده", text: $newZekrTitle)
                                .textInputAutocapitalization(.never)
                        }
                        
                        Section(header: Text("الهدف المحدد (عدد المرات)")) {
                            Stepper("الهدف: \(newZekrTarget)", value: $newZekrTarget, in: 1...10000)
                            
                            HStack(spacing: 12) {
                                Button("33") { newZekrTarget = 33 }.buttonStyle(.bordered)
                                Button("100") { newZekrTarget = 100 }.buttonStyle(.bordered)
                                Button("300") { newZekrTarget = 300 }.buttonStyle(.bordered)
                                Button("1000") { newZekrTarget = 1000 }.buttonStyle(.bordered)
                            }
                        }
                    }
                    .navigationTitle("إضافة ذكر جديد")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("إلغاء") { showAddSheet = false }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("حفظ") {
                                sync.addZekr(title: newZekrTitle, target: newZekrTarget)
                                showAddSheet = false
                            }
                            .disabled(newZekrTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                }
                .presentationDetents([.medium])
            }
            // Sheet: Edit Zekr
            .sheet(item: $editingItem) { item in
                NavigationStack {
                    Form {
                        Section(header: Text("تعديل نص الذكر")) {
                            TextField("نص الذكر", text: $editZekrTitle)
                                .textInputAutocapitalization(.never)
                        }
                        
                        Section(header: Text("تعديل الهدف")) {
                            Stepper("الهدف: \(editZekrTarget)", value: $editZekrTarget, in: 1...10000)
                            
                            HStack(spacing: 12) {
                                Button("33") { editZekrTarget = 33 }.buttonStyle(.bordered)
                                Button("100") { editZekrTarget = 100 }.buttonStyle(.bordered)
                                Button("300") { editZekrTarget = 300 }.buttonStyle(.bordered)
                                Button("1000") { editZekrTarget = 1000 }.buttonStyle(.bordered)
                            }
                        }
                    }
                    .navigationTitle("تعديل الذكر")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("إلغاء") { editingItem = nil }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("حفظ") {
                                sync.updateZekr(item: item, newTitle: editZekrTitle, newTarget: editZekrTarget)
                                editingItem = nil
                            }
                            .disabled(editZekrTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                }
                .presentationDetents([.medium])
            }
            .confirmationDialog("حذف الأذكار المحددة وعداداتها؟", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
                Button("حذف", role: .destructive) {
                    for item in pendingDeletion { sync.deleteZekr(item: item) }
                    pendingDeletion = []
                }
                Button("إلغاء", role: .cancel) { pendingDeletion = [] }
            }
            .alert("استعادة الأذكار الافتراضية", isPresented: $showResetAlert) {
                Button("إلغاء", role: .cancel) {}
                Button("استعادة", role: .destructive) {
                    Task {
                        switch await BiometricStatisticsDeletionAuthorizer.authorize(
                            reason: "تأكيد استعادة الأذكار الافتراضية",
                            failureMessage: "لم يتم تأكيد البصمة، لذلك لم تُستعد الأذكار."
                        ) {
                        case .success:
                            sync.resetToDefaultAzkar()
                        case .failure(let failure):
                            azkarRestoreErrorMessage = failure.message
                        }
                    }
                }
            } message: {
                Text("هل تريد بالتأكيد استعادة قائمة الأذكار المدمجة الأصلية وحذف الأذكار المخصصة؟")
            }
            .alert("لم تتم الاستعادة", isPresented: Binding(get: { azkarRestoreErrorMessage != nil }, set: { if !$0 { azkarRestoreErrorMessage = nil } })) {
                Button("حسناً", role: .cancel) {}
            } message: {
                Text(azkarRestoreErrorMessage ?? "")
            }
        }
    }
    
    // MARK: - Settings
    private var settingsTabView: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("فَاذْكُرُونِي").font(.caption).foregroundStyle(.green)
                        Text("تجربتك، كما تحبّها").font(.subheadline).foregroundStyle(.secondary)
                    }
                    .listRowBackground(Color.clear)
                }
                Section {
                    Label("عدد الذكر على أيقونة التطبيق", systemImage: "app.badge")
                    Text("تعرض الشارة آخر عدد محفوظ للذكر الحالي، وتختفي عند الصفر. اسمح بالإشعارات والشارات من إعدادات الآيفون. يتحدث عدد الساعة عند وصول المزامنة إلى الآيفون.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("دليل الاستخدام") {
                    NavigationLink {
                        PhoneButtonsGuideView { }
                    } label: {
                        settingsLabel("دليل استخدام الأزرار", subtitle: "شرح لكل زر وطريقة ضغطه واستخدامه", icon: "questionmark.circle.fill")
                    }
                }
                Section("على الآيفون") {
                    HStack(spacing: 12) {
                        Image(systemName: "hand.raised.fill")
                            .foregroundStyle(.green)
                            .frame(width: 28, height: 28)
                            .background(.green.opacity(0.12), in: Circle())
                        VStack(alignment: .leading, spacing: 2) {
                            Text("وضع أمان")
                                .font(.body.weight(.medium))
                            Text(sync.isDrivingLocked
                                 ? "التطبيق والساعة متوقفان أثناء القيادة"
                                 : "يتوقف التسبيح على الآيفون والساعة تلقائياً أثناء القيادة، ويعود بعد انخفاض السرعة.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(.green)
                            .accessibilityLabel("وضع الأمان مفعّل")
                    }
                    Toggle(isOn: $isTapSoundEnabled) {
                        settingsLabel("صوت الضغطات", subtitle: "نقرة خفيفة", icon: "speaker.wave.2")
                    }
                    .tint(.green)
                    .onChange(of: isTapSoundEnabled) { _, enabled in
                        if enabled {
                            UserDefaults.standard.set(TapFeedbackMode.sound.rawValue, forKey: TapFeedbackPreference.storageKey)
                            TapFeedback.shared.prepare()
                        }
                        else { TapFeedback.shared.stop() }
                    }
                    NavigationLink { TapFeedbackSettingsView() } label: {
                        settingsLabel("تنبيه الضغطات", subtitle: "الصوت والاهتزاز", icon: "hand.tap")
                    }
                    NavigationLink {
                        Form { phoneTargetSoundSettings }
                            .navigationTitle("تنبيهات الأهداف")
                    } label: {
                        settingsLabel("تنبيهات الأهداف", subtitle: "تنبيه إكمال الذكر على الآيفون", icon: "bell.badge")
                    }
                }
                Section("مواقيت الصلاة") {
                    NavigationLink { PrayerTimeAdjustmentsView() } label: {
                        settingsLabel("التعديلات اليدوية", subtitle: "تقديم أو تأخير مواقيت الصلاة بالدقائق", icon: "clock.arrow.circlepath")
                    }
                    NavigationLink { PrayerAdhanSettingsView() } label: {
                        settingsLabel("نغمة كل صلاة", subtitle: "اختر نغمة التنبيه لكل وقت", icon: "bell.and.waves.left.and.right.fill")
                    }
                }
                Section {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 10) {
                            Image(systemName: "applewatch")
                                .font(.title2).foregroundStyle(.green)
                                .frame(width: 42, height: 42)
                                .background(.green.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                            Text("إدارة الساعة").font(.title3.weight(.semibold))
                            Spacer()
                            Label(watchAccess.isPurchased ? "مفعّل" : "مقفل",
                                  systemImage: watchAccess.isPurchased ? "checkmark.seal.fill" : "lock.fill")
                                .font(.caption).foregroundStyle(.green)
                        }
                        if watchAccess.isChecking {
                            ProgressView("التحقق من شراء نسخة الساعة…")
                        } else if watchAccess.isPurchased {
                            Text("نسخة الساعة مفعّلة. جميع خياراتها متاحة.")
                                .font(.caption).foregroundStyle(.secondary)
                        } else {
                            Text("أذكارك وأهدافك على معصمك. تُفتح جميع خيارات الساعة بعد شراء نسختها.")
                                .font(.caption).foregroundStyle(.secondary)
                            NavigationLink { WatchPurchaseView() } label: {
                                Text("فتح نسخة الساعة").frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent).tint(.green)
                            Button("استعادة الشراء") { Task { await watchAccess.restore() } }
                                .frame(maxWidth: .infinity)
                                .disabled(watchAccess.isBusy)
                            if let message = watchAccess.message {
                                Text(message).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }.padding(.vertical, 8)
                    watchSettingsLink("الأذكار والأهداف", subtitle: "الذكر المعروض، الهدف وتصفير العدّاد", icon: "list.bullet") {
                        Form { watchAzkarSettings }.navigationTitle("الأذكار والأهداف")
                    }
                    Toggle("زر إنقاص العداد", isOn: Binding(
                        get: { sync.showsDecrementButton },
                        set: { sync.setShowsDecrementButton($0) }
                    ))
                    .tint(.green)
                    Toggle("زر تصفير العداد", isOn: Binding(
                        get: { sync.showsResetButton },
                        set: { sync.setShowsResetButton($0) }
                    ))
                    .tint(.green)
                    watchSettingsLink("طرق العدّ والإيماءات", subtitle: "اللمس والنقر المزدوج", icon: "hand.tap") {
                        Form { watchGestureSettings }.navigationTitle("طرق العدّ والإيماءات")
                    }
                    watchSettingsLink("صوت الساعة واهتزازها", icon: "waveform") {
                        Form {
                            Section("على الساعة") {
                                Label("تنبيه الضغطات", systemImage: "speaker.wave.2")
                                Text("افتح إعدادات تنبيه الضغطات داخل تطبيق الساعة لاختيار النقرة الخفيفة أو الاهتزاز أو كتم التنبيه. يُحفظ اختيار الساعة بصورة مستقلة عن الآيفون.")
                                    .foregroundStyle(.secondary)
                            }
                        }.navigationTitle("صوت الساعة واهتزازها")
                    }
                    watchSettingsLink("الاتصال والمزامنة", icon: "arrow.triangle.2.circlepath") {
                        Form { watchSyncSettings }.navigationTitle("الاتصال والمزامنة")
                    }
                    watchSettingsLink("دليل الساعة", icon: "book") { WatchGuideView() }
                } header: {
                    Text("تجربة الساعة")
                } footer: {
                    Text("جميع ميزات الآيفون مجانية. نسخة الساعة تُفتح بشراء دائم لمرة واحدة، دون تجديد تلقائي.")
                }
                Section("الحساب والمساعدة") {
                    Button {
                        requestAppReview()
                    } label: {
                        settingsLabel("قيّم التطبيق", subtitle: "شاركنا رأيك في متجر App Store", icon: "star.bubble.fill")
                    }
                    .buttonStyle(.plain)
                    NavigationLink { SubscriptionView() } label: {
                        settingsLabel("ميزات الآيفون", subtitle: "مجانية بالكامل، دون اشتراك", icon: "sparkles")
                    }
                    NavigationLink {
                        Form {
                            Section("الدعم والمساعدة") { SupportLink() }
                            Section("الخصوصية") {
                                NavigationLink("سياسة الخصوصية") { PrivacyPolicyView() }
                                NavigationLink("تراخيص أصوات الأذان") { AdhanAttributionsView() }
                            }
                            aboutSettings
                        }.navigationTitle("الدعم والخصوصية")
                    } label: {
                        settingsLabel("الدعم والخصوصية", subtitle: "المساعدة وحول التطبيق", icon: "checkmark.shield")
                    }
                }
            }
            .navigationTitle("الإعدادات")
            .tint(.green)
            .task { await watchAccess.refresh() }
        }
    }

    private func settingsLabel(_ title: String, subtitle: String? = nil, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundStyle(.green)
                .frame(width: 32, height: 32)
                .background(.green.opacity(0.1), in: RoundedRectangle(cornerRadius: 9))
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                if let subtitle { Text(subtitle).font(.caption).foregroundStyle(.secondary) }
            }
        }.padding(.vertical, 2)
    }

    /// يظهر طلب تقييم Apple الرسمي عند نشر التطبيق في App Store.
    /// قد لا يظهر في كل ضغطة؛ Apple تتحكم بعدد مرات عرضه للمستخدم.
    private func requestAppReview() {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive })
        else { return }
        SKStoreReviewController.requestReview(in: scene)
    }

    private func watchSettingsLink<Destination: View>(_ title: String, subtitle: String? = nil,
                                                    icon: String, @ViewBuilder destination: () -> Destination) -> some View {
        NavigationLink {
            PurchasedWatchSettingsGate { destination() }
        } label: {
            HStack {
                settingsLabel(title, subtitle: subtitle, icon: icon)
                Spacer(minLength: 4)
                if !watchAccess.isPurchased {
                    Image(systemName: "lock.fill").font(.caption).foregroundStyle(.secondary)
                        .accessibilityLabel("يتطلب شراء نسخة الساعة")
                }
            }
        }
    }

    private var watchAzkarSettings: some View {
                Section(header: Text("إعدادات ساعة آبل (Apple Watch)")) {
                    // اختيار نوع الذكر للساعة
                    Picker("الذكر المعروض على الساعة", selection: Binding(
                        get: { sync.currentZekr },
                        set: { newTitle in
                            if let item = sync.azkarList.first(where: { $0.title == newTitle }) {
                                sync.selectZekr(item)
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            }
                        }
                    )) {
                        ForEach(sync.azkarList) { item in
                            Text(item.title).tag(item.title)
                        }
                    }
                    .pickerStyle(.navigationLink)
                    
                    // تعديل هدف الساعة
                    VStack(alignment: .leading, spacing: 8) {
                        Stepper("هدف تسبيح الساعة: \(sync.target)", value: Binding(
                            get: { sync.target },
                            set: { newTarget in
                                sync.sendSyncPayload(count: sync.currentCount, zekr: sync.currentZekr, target: newTarget)
                            }
                        ), in: 1...10000, step: 10)
                        
                        // أزرار أهداف سريعة
                        HStack(spacing: 8) {
                            Text("أهداف سريعة:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            ForEach([33, 100, 300, 1000], id: \.self) { val in
                                Button("\(val)") {
                                    sync.sendSyncPayload(count: sync.currentCount, zekr: sync.currentZekr, target: val)
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                }
                                .buttonStyle(.bordered)
                                .tint(sync.target == val ? .green : .secondary)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                    
                    // العداد الحالي للساعة وزر تصفيره
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("العدد المحفوظ للذكر الحالي")
                            Text("(\(sync.currentZekr))")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Text("\(sync.currentCount)")
                            .font(.title3.bold())
                            .foregroundColor(.green)
                    }
                    
                    Button(role: .destructive) {
                        resetPhoneCount()
                    } label: {
                        Label("تصفير عدّاد الذكر الحالي فقط", systemImage: "arrow.counterclockwise")
                    }
                }
                
    }
    @ViewBuilder
    private var phoneTargetSoundSettings: some View {
                    Section(header: Text("تنبيهات أهداف الآيفون"), footer: Text("أثناء فتح التطبيق تُشغّل النغمة المختارة. في الخلفية يصدر إشعار عند وصول المزامنة، وفق أذونات الإشعارات ووضع الصامت والتركيز. قد يتأخر وصوله.")) {
                        Toggle(isOn: $isTargetSoundEnabled) {
                            HStack(spacing: 12) {
                                Image(systemName: isTargetSoundEnabled ? "bell.badge.fill" : "bell.slash.fill")
                                    .font(.title3)
                                    .foregroundColor(isTargetSoundEnabled ? .green : .secondary)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("تفعيل صوت إكمال الهدف")
                                        .fontWeight(.medium)
                                    Text("نغمة إكمال الهدف على الآيفون")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .tint(.green)
                        
                        if isTargetSoundEnabled {
                            Picker("نغمة التنبيه", selection: $selectedTargetSoundId) {
                                ForEach(TargetSoundItem.defaultSounds) { sound in
                                    HStack {
                                        Image(systemName: sound.icon)
                                        Text(sound.name)
                                    }
                                    .tag(sound.id)
                                }
                            }
                            .pickerStyle(.navigationLink)
                            .onChange(of: selectedTargetSoundId) { _, newId in
                                TargetSoundItem.play(soundId: newId)
                            }

                            Button(action: {
                                TargetSoundItem.play(soundId: selectedTargetSoundId)
                            }) {
                                HStack {
                                    Label("استماع وتجربة النغمة المحددة", systemImage: "play.circle.fill")
                                        .foregroundColor(.green)
                                        .fontWeight(.medium)
                                    Spacer()
                                    Image(systemName: "speaker.wave.2.fill")
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }

    }
    private var watchGestureSettings: some View {
                Section(header: Text("إيماءات ساعة آبل (Apple Watch Gestures)")) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Image(systemName: "hand.tap.fill")
                                .foregroundColor(.green)
                            Text("إيماءة النقر المزدوج (Double Tap)")
                                .fontWeight(.semibold)
                        }
                        Text("انقر بإصبعي السبابة والإبهام معاً مرتين للتسبيح التلقائي على الساعة دون لمس الشاشة نهائياً (لساعات Apple Watch Series 9، 10، Ultra 2).")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Label("ميزة تجريبية: قد تختلف الاستجابة حسب طراز الساعة وإعدادات النقر المزدوج.", systemImage: "flask.fill")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    .padding(.vertical, 4)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Image(systemName: "hand.point.up.left.fill")
                                .foregroundColor(.blue)
                            Text("النقر على شاشة الساعة")
                                .fontWeight(.semibold)
                        }
                        Text("تم جعل شاشة الساعة نقية وبسيطة جداً: المس أي مكان في الشاشة للعدّ المباشر مع اهتزاز Taptic Engine.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                
    }
    private var watchSyncSettings: some View {
                Section(header: Text("حالة المزامنة مع الساعة")) {
                    HStack {
                        Text("حالة الاتصال")
                        Spacer()
                        HStack(spacing: 6) {
                            Circle()
                                .fill(WCSession.isSupported() && WCSession.default.isReachable ? Color.green : Color.orange)
                                .frame(width: 8, height: 8)
                            Text(WCSession.isSupported() && WCSession.default.isReachable ? "متاحة الآن" : "تتم المزامنة عند توفر الاتصال")
                                .foregroundColor(.green)
                                .font(.subheadline)
                        }
                    }
                }
                
    }
    private var aboutSettings: some View {
                Section(header: Text("حول التطبيق")) {
                    HStack {
                        Text("اسم البرنامج")
                        Spacer()
                        Text("فَاذْكُرُونِي")
                            .foregroundColor(.gray)
                    }
                    
                    HStack {
                        Text("الإصدار")
                        Spacer()
                        Text("2.8")
                            .foregroundColor(.gray)
                    }
                    
                    HStack {
                        Text("المطور")
                        Spacer()
                        Text("عبدالله عجمي")
                            .foregroundColor(.gray)
                    }
                }
    }
}

enum PrayerTimeAdjustmentStore {
    private static let prefix = "fadhkuruni_prayer_adjustment_"

    static func offset(for identifier: String) -> Int {
        UserDefaults.standard.integer(forKey: prefix + identifier)
    }

    static func display(_ minutes: Int) -> String {
        guard minutes != 0 else { return "0 دقيقة" }
        let direction = minutes > 0 ? "تأخير" : "تقديم"
        return "\(direction) \(abs(minutes)) دقيقة"
    }
}

private struct UpcomingPrayerInfo {
    let prayer: PrayerTime
    let following: [PrayerTime]
    let progress: TimeInterval
    let remainingText: String
}

private struct PrayerTimeAdjustmentsView: View {
    @AppStorage("fadhkuruni_prayer_adjustment_fajr") private var fajr = 0
    @AppStorage("fadhkuruni_prayer_adjustment_sunrise") private var sunrise = 0
    @AppStorage("fadhkuruni_prayer_sunrise_duration") private var sunriseDuration = 10
    @AppStorage("fadhkuruni_prayer_adjustment_dhuhr") private var dhuhr = 0
    @AppStorage("fadhkuruni_prayer_adjustment_asr") private var asr = 0
    @AppStorage("fadhkuruni_prayer_adjustment_maghrib") private var maghrib = 0
    @AppStorage("fadhkuruni_prayer_adjustment_isha") private var isha = 0

    var body: some View {
        List {
            Section {
                adjustmentLink("تعديل الفجر", value: $fajr)
                adjustmentLink("تعديل الشروق", value: $sunrise)
                NavigationLink {
                    SunriseDurationEditor(duration: $sunriseDuration)
                } label: {
                    adjustmentRow(title: "مدة شروق الشمس", detail: "(sunriseDuration) دقيقة")
                }
                adjustmentLink("تعديل الظهر", value: $dhuhr)
                adjustmentLink("تعديل العصر", value: $asr)
                adjustmentLink("تعديل المغرب", value: $maghrib)
                adjustmentLink("تعديل العشاء", value: $isha)
            } footer: {
                Text("التقديم يجعل الموعد أبكر، والتأخير يجعله لاحقاً. تُحفظ اختياراتك على هذا الآيفون وتُستخدم أيضاً عند جدولة تنبيهات الصلاة.")
            }
        }
        .navigationTitle("التعديلات اليدوية")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func adjustmentLink(_ title: String, value: Binding<Int>) -> some View {
        NavigationLink {
            PrayerTimeOffsetEditor(title: title, minutes: value)
        } label: {
            adjustmentRow(title: title, detail: PrayerTimeAdjustmentStore.display(value.wrappedValue))
        }
    }

    private func adjustmentRow(title: String, detail: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.body.weight(.semibold))
                Text(detail).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 7)
    }
}

private struct PrayerTimeOffsetEditor: View {
    let title: String
    @Binding var minutes: Int

    var body: some View {
        Form {
            Section {
                Stepper(value: $minutes, in: -60...60) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(PrayerTimeAdjustmentStore.display(minutes)).font(.title3.weight(.semibold))
                        Text("اختر التقديم أو التأخير بالدقائق").font(.caption).foregroundStyle(.secondary)
                    }
                }
            } footer: {
                Text("يمكنك التعديل حتى ساعة قبل أو بعد الوقت المحسوب.")
            }
            Section {
                Button("إلغاء التعديل", role: .destructive) { minutes = 0 }
                    .disabled(minutes == 0)
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: minutes) { _, _ in
            PrayerTimesManager.shared.applyManualAdjustments()
            DhikrSummaryNotificationScheduler.shared.refreshPrayerReminders()
            DhikrSummaryNotificationScheduler.shared.refreshDailySummaryReminder()
        }
    }
}

private struct SunriseDurationEditor: View {
    @Binding var duration: Int

    var body: some View {
        Form {
            Section {
                Stepper(value: $duration, in: 0...30) {
                    Text("مدة الشروق: (duration) دقيقة").font(.title3.weight(.semibold))
                }
            } footer: {
                Text("هذه المدة تُظهر فترة الشروق داخل شاشة المواقيت.")
            }
        }
        .navigationTitle("مدة شروق الشمس")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct PrayerAdhanSettingsView: View {
    @ObservedObject private var recorder = PrayerAdhanRecorder.shared

    private let prayers: [(id: String, title: String, symbol: String)] = [
        ("fajr", "الفجر", "moon.stars.fill"),
        ("dhuhr", "الظهر", "sun.max.fill"),
        ("asr", "العصر", "sun.haze.fill"),
        ("maghrib", "المغرب", "sunset.fill"),
        ("isha", "العشاء", "moon.fill")
    ]

    var body: some View {
        List {
            Section {
                ForEach(prayers, id: \.id) { prayer in
                    NavigationLink {
                        PrayerAlertDetailView(prayerID: prayer.id, title: prayer.title, symbol: prayer.symbol)
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: prayer.symbol)
                                .foregroundStyle(.green)
                                .frame(width: 29, height: 29)
                                .background(Color.green.opacity(0.10), in: Circle())
                            Text("تنبيه \(prayer.title)").font(.body.weight(.semibold))
                            Spacer()
                            Label(
                                PrayerAlertPreference.mode(for: prayer.id).title,
                                systemImage: "bell.fill"
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 5)
                }
            } footer: {
                    Text("اضغط على الصلاة لاختيار نغمة إشعارها.")
            }
        }
        .navigationTitle("نغمة كل صلاة")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct PrayerAlertDetailView: View {
    let prayerID: String
    let title: String
    let symbol: String
    @ObservedObject private var recorder = PrayerAdhanRecorder.shared
    @State private var mode: PrayerAlertMode
    @State private var selectedBuiltInAdhanID: String

    init(prayerID: String, title: String, symbol: String) {
        self.prayerID = prayerID
        self.title = title
        self.symbol = symbol
        _mode = State(initialValue: PrayerAlertPreference.mode(for: prayerID))
        _selectedBuiltInAdhanID = State(initialValue: BuiltInAdhan.selected(for: prayerID).id)
    }

    var body: some View {
        List {
            Section {
                HStack(spacing: 10) {
                    Image(systemName: symbol).font(.title3).foregroundStyle(.green)
                    VStack(alignment: .leading, spacing: 3) {
                    Text("إشعار: \(title)").font(.title3.weight(.semibold))
                    Text("اختر نغمة التنبيه عند دخول الوقت").font(.caption).foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 6)
            }

            Section("التنبيه") {
                Picker("نوع التنبيه", selection: $mode) {
                    Text("بدون إشعار").tag(PrayerAlertMode.none)
                    Text("صامت").tag(PrayerAlertMode.silent)
                    Text("افتراضي").tag(PrayerAlertMode.system)
                    Text("نغمة مختارة").tag(PrayerAlertMode.builtIn)
                }
                .pickerStyle(.segmented)
            }

            Section("خيارات التنبيه") {
                modeRow(.none, icon: "nosign")
                modeRow(.silent, icon: "bell.slash")
                modeRow(.system, icon: "bell.badge")
                modeRow(.builtIn, icon: "bell.and.waves.left.and.right")
            }

            Section {
                ForEach(BuiltInAdhan.all) { adhan in
                    HStack(spacing: 12) {
                        Button {
                            BuiltInAdhan.select(adhan, for: prayerID)
                            selectedBuiltInAdhanID = adhan.id
                            mode = .builtIn
                            DhikrSummaryNotificationScheduler.shared.refreshPrayerReminders()
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "waveform.circle.fill")
                                    .foregroundStyle(.green)
                                    .font(.title3)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(adhan.title).foregroundStyle(.primary)
                                    Text(adhan.subtitle).font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                if selectedBuiltInAdhanID == adhan.id {
                                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                                }
                            }
                        }
                        .buttonStyle(.plain)

                        Button {
                            if recorder.playingBuiltInAdhanID == adhan.id { recorder.stopPlayback() }
                            else { recorder.playBuiltInAdhan(adhan) }
                        } label: {
                            Image(systemName: recorder.playingBuiltInAdhanID == adhan.id ? "stop.circle.fill" : "play.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.green)
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel(recorder.playingBuiltInAdhanID == adhan.id ? "إيقاف المعاينة" : "معاينة النغمة")
                    }
                }
            } header: {
                Text("اختر النغمة")
            } footer: {
                Text("تعمل النغمة المختارة مع إشعار شاشة القفل.")
            }
            Section {
                Button {
                    recorder.scheduleTestNotification(for: prayerID, title: title)
                } label: {
                    Label("تجربة الإشعار الآن (يصلك بعد 5 ثوانٍ)", systemImage: "bell.badge.fill")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.green)
                }
            } footer: {
                Text("اضغط للتجربة ثم يمكنك قفل شاشة الآيفون لمشاهدة التنبيه وسماع الصوت المختار.")
            }
        }
        .navigationTitle("إشعار: \(title)")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: mode) { _, value in
            PrayerAlertPreference.set(value, for: prayerID)
            DhikrSummaryNotificationScheduler.shared.refreshPrayerReminders()
        }
        .alert("أذان \(title)", isPresented: Binding(get: { recorder.message != nil }, set: { if !$0 { recorder.clearMessage() } })) {
            Button("حسناً", role: .cancel) { recorder.clearMessage() }
        } message: { Text(recorder.message ?? "") }
        .onDisappear { recorder.stopPlayback() }
    }

    private func modeRow(_ value: PrayerAlertMode, icon: String) -> some View {
        Button {
            mode = value
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon).foregroundStyle(value == mode ? .green : .secondary).frame(width: 24)
                Text(value.title).foregroundStyle(.primary)
                Spacer()
                if value == mode { Image(systemName: "checkmark").foregroundStyle(.green) }
            }
        }
    }

}

/// Observe the verified entitlement here as well so a pushed screen closes access
/// immediately after a revocation or an unsuccessful entitlement refresh.
private struct PurchasedWatchSettingsGate<Content: View>: View {
    @ObservedObject private var access = WatchPurchaseAccess.shared
    private let content: Content

    init(@ViewBuilder content: () -> Content) { self.content = content() }

    var body: some View {
        Group {
            if access.isChecking {
                ProgressView("التحقق من شراء نسخة الساعة…")
            } else if access.isPurchased {
                content
            } else {
                WatchPurchaseView()
            }
        }
    }
}


private struct PhoneLockedCounterCover: View {
    let date: Date
    let photoData: Data?

    private var calendar: Calendar { Calendar.current }
    private var hourAngle: Double {
        let parts = calendar.dateComponents([.hour, .minute, .second], from: date)
        let hour = Double((parts.hour ?? 0) % 12)
        let minute = Double(parts.minute ?? 0)
        let second = Double(parts.second ?? 0)
        return hour * 30 + minute * 0.5 + second / 120
    }
    private var minuteAngle: Double {
        let parts = calendar.dateComponents([.minute, .second], from: date)
        return Double(parts.minute ?? 0) * 6 + Double(parts.second ?? 0) * 0.1
    }
    private var secondAngle: Double {
        Double(calendar.component(.second, from: date)) * 6
    }

    var body: some View {
        ZStack {
            if let photoData, let image = UIImage(data: photoData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    // Keep the chosen photo large and square, inside a frosted
                    // crystal frame that fits the counter's existing circle.
                    .frame(width: 118, height: 118)
                    .clipShape(RoundedRectangle(cornerRadius: 27, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 27, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .opacity(0.18)
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 27, style: .continuous)
                            .strokeBorder(
                                LinearGradient(colors: [.white.opacity(0.92), .mint.opacity(0.45), .white.opacity(0.30)], startPoint: .topLeading, endPoint: .bottomTrailing),
                                lineWidth: 1.4
                            )
                    }
                    .shadow(color: .mint.opacity(0.36), radius: 9, y: 3)
            } else {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.white.opacity(0.92), .mint.opacity(0.70), .green.opacity(0.52), Color(red: 0.01, green: 0.22, blue: 0.12)],
                            center: .topLeading,
                            startRadius: 3,
                            endRadius: 106
                        )
                    )
            }
            Circle()
                .strokeBorder(.white.opacity(0.72), lineWidth: 1.2)
                .shadow(color: .mint.opacity(0.38), radius: 12)
            Circle()
                .strokeBorder(.white.opacity(0.22), lineWidth: 1)
                .padding(11)
            Circle()
                .strokeBorder(
                    AngularGradient(
                        colors: [.clear, .white.opacity(0.86), .mint.opacity(0.65), .clear, .white.opacity(0.50), .clear],
                        center: .center
                    ),
                    lineWidth: 2
                )
                .padding(5)
            RoundedRectangle(cornerRadius: 25, style: .continuous)
                .fill(.white.opacity(photoData == nil ? 0.23 : 0.16))
                .frame(width: 83, height: 20)
                .rotationEffect(.degrees(-31))
                .offset(x: -20, y: -40)
                .blur(radius: 2)
            Circle()
                .fill(.black.opacity(0.13))
                .frame(width: 98, height: 98)
                .offset(x: 26, y: 33)
                .blur(radius: 14)
            Image(systemName: "sparkle")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(.white.opacity(0.94))
                .shadow(color: .mint.opacity(0.9), radius: 5)
                .offset(x: -39, y: -37)
            Image(systemName: "sparkle")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.78))
                .shadow(color: .mint.opacity(0.8), radius: 4)
                .offset(x: 42, y: 22)
            ForEach(0..<12, id: \.self) { tick in
                Capsule()
                    .fill(.white.opacity(tick % 3 == 0 ? 0.92 : 0.48))
                    .frame(width: tick % 3 == 0 ? 2.5 : 1, height: tick % 3 == 0 ? 10 : 5)
                    .offset(y: -51)
                    .rotationEffect(.degrees(Double(tick) * 30))
            }

            clockHand(length: 31, width: 5, color: .white, angle: hourAngle)
            clockHand(length: 43, width: 3, color: .white.opacity(0.92), angle: minuteAngle)
            clockHand(length: 47, width: 1.25, color: .mint.opacity(0.96), angle: secondAngle)

            Circle()
                .fill(.mint)
                .frame(width: 9, height: 9)
                .overlay(Circle().stroke(.white.opacity(0.9), lineWidth: 1))
                .shadow(color: .mint.opacity(0.9), radius: 5)
        }
        .environment(\.layoutDirection, .leftToRight)
        .frame(width: 136, height: 136)
        .clipShape(Circle())
    }

    private func clockHand(length: CGFloat, width: CGFloat, color: Color, angle: Double) -> some View {
        Capsule()
            .fill(color)
            .frame(width: width, height: length)
            .offset(y: -length / 2)
            .rotationEffect(.degrees(angle))
            .shadow(color: .black.opacity(0.28), radius: 1.5, y: 1)
    }
}
