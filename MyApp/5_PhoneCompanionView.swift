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
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }
    
    public func triggerTargetNotification(zekr: String, count: Int) {
        let isEnabled = UserDefaults.standard.object(forKey: "fadhkuruni_target_sound_enabled") as? Bool ?? true
        guard isEnabled else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "فَاذْكُرُونِي - ما شاء الله! اكتمل الهدف 🎉"
        content.body = "تم بحمد الله إتمام \(count) مرة من: \(zekr)"
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: "fadhkuruni_target_\(UUID().uuidString)",
            content: content,
            trigger: nil // يطلق فوراً ليضيء شاشة القفل ويصدر التنبيه
        )
        
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }
    
    public func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .list])
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
    @ObservedObject private var sync = WatchSyncService.shared
    @State private var selectedTab = 0
    
    // Add/Edit State
    @State private var showAddSheet = false
    @State private var newZekrTitle = ""
    @State private var newZekrTarget = 33
    
    @State private var editingItem: ZekrItem? = nil
    @State private var editZekrTitle = ""
    @State private var editZekrTarget = 33
    
    @State private var showResetAlert = false
    @AppStorage("fadhkuruni_buttons_locked") private var isButtonsLocked = false
    
    // صوت التنبيه عند وصول الهدف
    @AppStorage("fadhkuruni_target_sound_id") private var selectedTargetSoundId: Int = 1
    @AppStorage("fadhkuruni_target_sound_enabled") private var isTargetSoundEnabled: Bool = true
    @State private var hasAlertedForCurrentTarget: Bool = false
    
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
            
            // شريط التبويبات السفلي المخصص (يختفي بالكامل عند تفعيل القفل لتصبح الشاشة بيضاء ونقية للتسبيح)
            if !isButtonsLocked {
                customBottomTabBar
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .preferredColorScheme(isButtonsLocked ? .light : nil)
        .background(
            (isButtonsLocked ? Color.white : Color(UIColor.systemBackground))
                .ignoresSafeArea()
        )
        .tint(.green)
        .ignoresSafeArea(.keyboard)
        .onAppear {
            if selectedTargetSoundId > 7 {
                selectedTargetSoundId = 1
            }
            if sync.currentCount >= sync.target && sync.target > 0 {
                hasAlertedForCurrentTarget = true
            }
            
            // إبقاء شاشة الآيفون مضاءة طالما التطبيق مفتوح لمنع الخفوت والقفل التلقائي
            UIApplication.shared.isIdleTimerDisabled = true
            
            // تهيئة الصوت والإشعارات بشكل غير تزامني لتفادي أي تجميد للشاشة عند بدء التشغيل
            DispatchQueue.global(qos: .userInitiated).async {
                SoundManager.shared.configureAudioSession()
                NotificationManager.shared.requestAuthorization()
            }
            
            // إرسال المزامنة بعد اكتمال تحميل الواجهة بسلاسة لتفادي أي تعارض في الخيوط
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                sync.sendSyncPayload(count: sync.currentCount, zekr: sync.currentZekr, target: sync.target)
                sync.syncAzkarListToPeer()
            }
        }
        .onDisappear {
            // إعادة ضبط مؤقت القفل التلقائي عند الخروج من التطبيق
            UIApplication.shared.isIdleTimerDisabled = false
        }
        .onChange(of: sync.currentCount) { newCount in
            handleCountChange(newCount: newCount)
        }
        .onChange(of: sync.target) { newTarget in
            if sync.currentCount < newTarget {
                hasAlertedForCurrentTarget = false
            }
        }
        .onChange(of: sync.currentZekr) { _ in
            hasAlertedForCurrentTarget = (sync.currentCount >= sync.target && sync.target > 0)
        }
    }
    
    // MARK: - Counter Tab
    private var counterTabView: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                // 1. كامل مساحة شاشة الآيفون: تصبح كلها مساحة تسبيح تفاعلية ومؤمّنة 100%
                VStack(spacing: 0) {
                    Spacer(minLength: isButtonsLocked ? 20 : 16)
                    
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
                    
                    Spacer(minLength: isButtonsLocked ? 40 : 84)
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
                
                // 2. الشريط السفلي: خيارات التحكم وقفل الأخطاء (يختفي تماماً عند تفعيل القفل)
                if !isButtonsLocked {
                    bottomControlBar
                        .padding(.horizontal, 16)
                        .padding(.bottom, 6)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
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
                if isButtonsLocked {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                isButtonsLocked = false
                            }
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        }) {
                            HStack(spacing: 5) {
                                Image(systemName: "lock.open.fill")
                                Text("فتح القفل")
                            }
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.red)
                            .clipShape(Capsule())
                            .shadow(color: Color.red.opacity(0.3), radius: 4, y: 2)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - بطاقة العداد والهدف وخلفيتها
    private var counterCardBackground: some View {
        RoundedRectangle(cornerRadius: 32)
            .fill(isButtonsLocked ? Color.white : Color.green.opacity(0.08))
            .overlay(
                RoundedRectangle(cornerRadius: 32)
                    .stroke(isButtonsLocked ? Color.gray.opacity(0.2) : Color.green.opacity(0.2), lineWidth: 1)
            )
            .shadow(color: isButtonsLocked ? Color.black.opacity(0.05) : Color.clear, radius: 10, y: 4)
    }
    
    private var counterCardView: some View {
        VStack(spacing: 8) {
            Text("\(sync.currentCount)")
                .font(.system(size: 104, weight: .heavy, design: .rounded))
                .foregroundColor(.green)
                .contentTransition(.numericText())
            
            Text("الهدف: \(sync.target)")
                .font(.title3.weight(.medium))
                .foregroundColor(isButtonsLocked ? Color.black.opacity(0.6) : .secondary)
            
            // مؤشر اكتمال الهدف
            if sync.currentCount >= sync.target && sync.target > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.seal.fill")
                    Text("ما شاء الله! اكتمل الهدف")
                        .font(.caption.bold())
                }
                .foregroundColor(.green)
                .padding(.horizontal, 14)
                .padding(.vertical, 5)
                .background(Color.green.opacity(0.15))
                .clipShape(Capsule())
                .padding(.top, 2)
            }
            
            // مؤشر قفل الأخطاء
            if isButtonsLocked {
                HStack(spacing: 6) {
                    Image(systemName: "lock.shield.fill")
                        .font(.caption2)
                    Text("قفل الأخطاء مفعّل: المس أي مكان للعد")
                        .font(.caption.bold())
                }
                .foregroundColor(.red)
                .padding(.horizontal, 14)
                .padding(.vertical, 5)
                .background(Color.red.opacity(0.12))
                .clipShape(Capsule())
                .padding(.top, 4)
            }
        }
        .padding(.vertical, isButtonsLocked ? 36 : 24)
        .frame(maxWidth: .infinity)
        .background(counterCardBackground)
        .padding(.horizontal, 16)
    }
    
    // MARK: - الشريط السفلي لخيارات التحكم وقفل الأخطاء
    private var bottomControlBar: some View {
        HStack(spacing: 14) {
            // 1. زر الزائد (+)
            Button(action: {
                incrementPhoneCount()
            }) {
                VStack(spacing: 4) {
                    Image(systemName: "plus")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 52, height: 52)
                        .background(Color.green)
                        .clipShape(Circle())
                    
                    Text("زيادة")
                        .font(.caption2.bold())
                        .foregroundColor(.green)
                }
            }
            
            // 2. زر الناقص (-)
            Button(action: {
                if sync.currentCount > 0 {
                    sync.sendSyncPayload(count: sync.currentCount - 1, zekr: sync.currentZekr, target: sync.target)
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
            }) {
                VStack(spacing: 4) {
                    Image(systemName: "minus")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.red)
                        .frame(width: 52, height: 52)
                        .background(Color.red.opacity(0.12))
                        .clipShape(Circle())
                    
                    Text("ناقص")
                        .font(.caption2.bold())
                        .foregroundColor(.secondary)
                }
            }
            
            // 3. زر تصفير العداد (↺)
            Button(action: {
                resetPhoneCount()
            }) {
                VStack(spacing: 4) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.orange)
                        .frame(width: 52, height: 52)
                        .background(Color.orange.opacity(0.15))
                        .clipShape(Circle())
                    
                    Text("تصفير")
                        .font(.caption2.bold())
                        .foregroundColor(.orange)
                }
            }
            
            // 4. زر قفل الأخطاء (يخفي جميع الأزرار ويجعل الشاشة بيضاء نقية للتسبيح)
            Button(action: {
                withAnimation(.easeInOut(duration: 0.25)) {
                    isButtonsLocked = true
                }
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            }) {
                VStack(spacing: 4) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.red)
                        .frame(width: 52, height: 52)
                        .background(Color.red.opacity(0.14))
                        .clipShape(Circle())
                    
                    Text("قفل الأخطاء")
                        .font(.caption2.bold())
                        .foregroundColor(.red)
                }
            }
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(UIColor.secondarySystemBackground))
                .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
        )
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
                .foregroundColor(selectedTab == 1 ? .green : .secondary)
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            // 3. زر إعدادات الساعة
            Button {
                selectedTab = 2
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "applewatch")
                        .font(.system(size: 20, weight: selectedTab == 2 ? .bold : .regular))
                    Text("إعدادات الساعة")
                        .font(.system(size: 11, weight: selectedTab == 2 ? .bold : .medium))
                }
                .foregroundColor(selectedTab == 2 ? .green : .secondary)
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 8)
        .padding(.bottom, 6)
        .background(Color(UIColor.secondarySystemBackground))
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(Color(UIColor.separator)),
            alignment: .top
        )
    }
    
    private func incrementPhoneCount() {
        let next = sync.currentCount + 1
        sync.sendSyncPayload(count: next, zekr: sync.currentZekr, target: sync.target)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
    
    private func resetPhoneCount() {
        hasAlertedForCurrentTarget = false
        sync.resetCurrentZekrCount()
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }
    
    // فحص اكتمال الهدف وإطلاق التنبيه الصوتي والاهتزاز
    private func handleCountChange(newCount: Int) {
        if newCount < sync.target || newCount == 0 {
            hasAlertedForCurrentTarget = false
        } else if newCount == sync.target && !hasAlertedForCurrentTarget {
            hasAlertedForCurrentTarget = true
            playTargetAlert()
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
                
                Section(header: Text("قائمة الأذكار (اضغط للاختيار، أو اسحب للحذف)")) {
                    ForEach(sync.azkarList) { item in
                        HStack(spacing: 12) {
                            if sync.currentZekr == item.title {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.title3)
                            } else {
                                Image(systemName: "circle")
                                    .foregroundColor(.gray.opacity(0.4))
                                    .font(.title3)
                            }
                            
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
                        .contentShape(Rectangle())
                        .onTapGesture {
                            sync.selectZekr(item)
                        }
                    }
                    .onDelete { offsets in
                        sync.deleteZekr(at: offsets)
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
    
    // MARK: - Settings Tab (إعدادات ساعة آبل ونقل الخيارات إليها)
    private var settingsTabView: some View {
        NavigationStack {
            Form {
                // قسم إعدادات وخيارات ساعة آبل
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
                        hasAlertedForCurrentTarget = false
                        sync.resetCurrentZekrCount()
                        UINotificationFeedbackGenerator().notificationOccurred(.warning)
                    } label: {
                        Label("تصفير عدّاد الذكر الحالي فقط", systemImage: "arrow.counterclockwise")
                    }
                }
                
                // قسم صوت التنبيه عند اكتمال الهدف في الذكر
                Section(header: Text("صوت التنبيه عند وصول الهدف"), footer: Text("تعمل النغمة حتى لو كان الآيفون في الوضع الصامت (Silent Mode). تأكد فقط من رفع مستوى صوت الوسائط.")) {
                    Toggle(isOn: $isTargetSoundEnabled) {
                        HStack(spacing: 12) {
                            Image(systemName: isTargetSoundEnabled ? "bell.badge.fill" : "bell.slash.fill")
                                .font(.title3)
                                .foregroundColor(isTargetSoundEnabled ? .green : .secondary)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("تفعيل صوت إكمال الهدف")
                                    .fontWeight(.medium)
                                Text("يصدر الآيفون صوتاً عند وصولك للهدف سواءً سبحت من الساعة أو الآيفون")
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
                        .onChange(of: selectedTargetSoundId) { newId in
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
                
                // إيماءات ساعة آبل
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
                
                // حالة المزامنة
                Section(header: Text("حالة المزامنة مع الساعة")) {
                    HStack {
                        Text("حالة الاتصال")
                        Spacer()
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 8, height: 8)
                            Text("متصلة ومتزامنة لحظياً")
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
                
                // حول التطبيق
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
            .navigationTitle("إعدادات الساعة")
        }
    }
}
