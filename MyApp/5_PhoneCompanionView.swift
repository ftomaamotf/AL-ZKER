import WatchConnectivity
//
//  PhoneCompanionView.swift
//  Fadhkuruni (iPhone Companion App View)
//

import SwiftUI
import AVFoundation
import AudioToolbox

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
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in
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
        completionHandler([.banner, .list])
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
    @State private var showQiblaSheet = false
    
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
    @State private var showCounterResetConfirmation = false
    @State private var pendingCounterReset: ZekrItem?
    @AppStorage("fadhkuruni_buttons_locked") private var isButtonsLocked = false
    
    // صوت التنبيه عند وصول الهدف
    @AppStorage("fadhkuruni_target_sound_id") private var selectedTargetSoundId: Int = 1
    @AppStorage("fadhkuruni_target_sound_enabled") private var isTargetSoundEnabled: Bool = true
    @State private var hasAlertedForCurrentTarget: Bool = false
    // A single physical touch can occasionally reach overlapping SwiftUI gesture layers.
    // Keep rapid intentional tasbih responsive while ignoring a duplicate callback.
    @State private var lastPhoneIncrementTime: Date = .distantPast
    @Environment(\.scenePhase) private var scenePhase
    
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

            }
        }
        .onDisappear {
            // إعادة ضبط مؤقت القفل التلقائي عند الخروج من التطبيق
            UIApplication.shared.isIdleTimerDisabled = false
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
    }
    
    // MARK: - Counter Tab
    private var counterTabView: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                // 1. كامل مساحة شاشة الآيفون: تصبح كلها مساحة تسبيح تفاعلية ومؤمّنة 100%
                VStack(spacing: 0) {
                    Spacer(minLength: 16)
                    
                    // نوع الذكر الحالي
                    VStack(spacing: 6) {
                        Text("الذكر الحالي")
                            .font(.subheadline)
                            .foregroundColor(isButtonsLocked ? Color.black.opacity(0.5) : .secondary)
                        
                        Text(sync.currentZekr)
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(isButtonsLocked ? .black : .primary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    
                    Spacer(minLength: 12)
                    
                    // بطاقة العداد الكبيرة والهدف
                    counterCardView
                    
                    Spacer(minLength: 12)
                    
                    // إرشاد النقر على الشاشة
                    HStack(spacing: 6) {
                        Image(systemName: isButtonsLocked ? "hand.tap.fill" : "hand.tap.fill")
                            .font(.footnote)
                        Text(isButtonsLocked ? "المس في أي مكان بالشاشة للتسبيح" : "المس في أي مكان بالشاشة للتسبيح")
                            .font(.subheadline)
                    }
                    .foregroundColor(isButtonsLocked ? Color.black.opacity(0.6) : .secondary)
                    
                    Spacer(minLength: 84)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                // إيماءة تغطي كامل شاشة الآيفون من الحافة للحافة
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onEnded { value in
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
                
                // يبقى زر القفل في موضعه؛ تُخفى أدوات العد الأخرى وتتعطل عند القفل.
                bottomControlBar
                    .padding(.horizontal, 16)
                    .padding(.bottom, 6)
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
                ToolbarItem(placement: .navigationBarLeading) {
                    NavigationLink { PurchasedWatchSettingsGate { WatchGuideView() } } label: {
                        Image(systemName: "applewatch")
                            .accessibilityLabel("فاذكروني على الساعة — صور وطريقة الاستخدام")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showQiblaSheet = true
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color.green.opacity(0.14))
                                .frame(width: 34, height: 34)
                                .overlay(
                                    Circle()
                                        .strokeBorder(Color.green.opacity(0.35), lineWidth: 0.8)
                                )
                            Image(systemName: "safari.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.green)
                        }
                        .accessibilityLabel("اتجاه القبلة")
                    }
                }
            }
            .sheet(isPresented: $showQiblaSheet) {
                PhoneQiblaView()
            }
        }
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
        VStack(spacing: 8) {
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
            Text("\(max(0, sync.target - sync.currentCount).formatted()) مرات لإكمال الهدف")
                .font(.caption)
                .foregroundStyle(isButtonsLocked ? Color.black.opacity(0.6) : .secondary)
                .padding(.top, 8)

            // مؤشر قفل الأخطاء
            HStack(spacing: 6) {
                Image(systemName: "lock.shield.fill")
                    .font(.caption2)
                Text("قفل العدّاد مفعّل: المس أي مكان للعدّ")
                    .font(.caption.bold())
            }
                .foregroundColor(.red)
                .padding(.horizontal, 14)
                .padding(.vertical, 5)
                .background(Color.red.opacity(0.12))
                .clipShape(Capsule())
                .padding(.top, 4)
                .opacity(isButtonsLocked ? 1 : 0)
                .accessibilityHidden(!isButtonsLocked)
        }
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity)
        .background(counterCardBackground)
        .padding(.horizontal, 16)
    }
    
    // MARK: - الشريط السفلي لخيارات التحكم وقفل الأخطاء
    private var bottomControlBar: some View {
        HStack(spacing: 14) {
            Group {
                Button { incrementPhoneCount() } label: {
                    counterControlLabel(title: "زيادة", symbol: "plus", tint: .green, isPrimary: true)
                }
                .frame(maxWidth: .infinity)

                Button {
                    if sync.currentCount > 0 {
                        sync.sendSyncPayload(count: sync.currentCount - 1, zekr: sync.currentZekr, target: sync.target)
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
                } label: {
                    counterControlLabel(title: "إنقاص", symbol: "minus", tint: .red)
                }
                .frame(maxWidth: .infinity)

                Button { resetPhoneCount() } label: {
                    counterControlLabel(title: "تصفير", symbol: "arrow.counterclockwise", tint: .orange)
                }
                .frame(maxWidth: .infinity)
            }
            .opacity(isButtonsLocked ? 0 : 1)
            .allowsHitTesting(!isButtonsLocked)
            .accessibilityHidden(isButtonsLocked)

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isButtonsLocked.toggle()
                }
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            } label: {
                counterControlLabel(title: isButtonsLocked ? "فتح قفل العدّاد" : "قفل العدّاد",
                                    symbol: isButtonsLocked ? "lock.open.fill" : "lock.shield.fill",
                                    tint: .red)
            }
            .frame(maxWidth: .infinity)
            .accessibilityLabel(isButtonsLocked ? "فتح قفل العدّاد" : "قفل العدّاد")
            .accessibilityHint(isButtonsLocked ? "إظهار أدوات التحكم" : "إخفاء أدوات التحكم مع إبقاء زر فتح قفل العدّاد في مكانه")
        }
        .buttonStyle(.plain)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background {
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(UIColor.secondarySystemBackground))
                .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
                .opacity(isButtonsLocked ? 0 : 1)
        }
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

    // MARK: - شريط التبويبات السفلي (العداد - الأذكار والأهداف - إعدادات الساعة)
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
            
            // 3. زر الإعدادات
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
                    sync.resetToDefaultAzkar()
                }
            } message: {
                Text("هل تريد بالتأكيد استعادة قائمة الأذكار المدمجة الأصلية وحذف الأذكار المخصصة؟")
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
                                 ? "التطبيق والساعة متوقفان حتى تتوقف السيارة"
                                 : "عند تحرّك السيارة، يتوقف التطبيق على الآيفون والساعة تلقائياً، وعند توقفها يعودان إلى العمل.")
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
                    NavigationLink { DhikrRemindersView() } label: {
                        settingsLabel("التذكيرات", subtitle: "ملخصات الذكر وأوقات التذكير", icon: "bell.badge")
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
                    NavigationLink { SubscriptionView() } label: {
                        settingsLabel("ميزات الآيفون", subtitle: "مجانية بالكامل، دون اشتراك", icon: "sparkles")
                    }
                    NavigationLink {
                        Form {
                            Section("الدعم والمساعدة") { SupportLink() }
                            Section("الخصوصية") {
                                NavigationLink("سياسة الخصوصية") { PrivacyPolicyView() }
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
                    
                    HStack {
                        Text("الأذكار المسجلة للساعة")
                        Spacer()
                        Text("\(sync.azkarList.count)")
                            .foregroundColor(.secondary)
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
