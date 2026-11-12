import Foundation
import SwiftUI
import Combine
import AVFAudio
#if os(watchOS)
import WatchKit
#elseif os(iOS)
import UIKit
#endif

enum TapFeedbackMode: String, CaseIterable, Identifiable, Sendable {
    case sound, haptic, silent
    var id: String { rawValue }
    var title: String {
        switch self {
        case .sound: return "نقرة خفيفة"
        case .haptic: return "اهتزاز"
        case .silent: return "بدون تنبيه"
        }
    }
}

enum TapFeedbackPreference {
    nonisolated static let storageKey = "fadhkuruni_per_tap_feedback_v1"
    nonisolated static let soundEnabledKey = "fadhkuruni_per_tap_sound_enabled_v1"
    static var soundEnabled: Bool {
        UserDefaults.standard.object(forKey: soundEnabledKey) as? Bool ?? true
    }
    static var current: TapFeedbackMode {
        TapFeedbackMode(rawValue: UserDefaults.standard.string(forKey: storageKey) ?? "sound") ?? .sound
    }
}

@MainActor
final class TapFeedback: ObservableObject {
    @Published private(set) var soundError: String?
    static let shared = TapFeedback()
    private var player: AVAudioPlayer?

    // Configure once before counting; reuse one player and never queue taps.
    func prepare() {
        guard TapFeedbackPreference.soundEnabled,
              TapFeedbackPreference.current == .sound, player == nil else { return }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: .mixWithOthers)
            try session.setActive(true)
            guard let url = Bundle.main.url(forResource: "PerDhikrTap", withExtension: "wav") else {
                soundError = "تعذر العثور على ملف النغمة."
                return
            }
            let prepared = try AVAudioPlayer(contentsOf: url)
            prepared.volume = 0.85
            prepared.prepareToPlay()
            player = prepared
            soundError = nil
        } catch {
            soundError = "تعذر تشغيل النغمة. تحقق من مستوى الصوت ومخرج الصوت المتصل."
        }
    }

    func stop() {
        player?.stop()
    }

    func play(goalReached: Bool = false) {
        switch TapFeedbackPreference.current {
        case .silent: break
        case .haptic: playHaptic(goalReached: goalReached)
        case .sound:
            guard TapFeedbackPreference.soundEnabled else { return }
            // No session setup, file loading, or asynchronous backlog on a tap.
            guard let player else { return }
            player.stop()
            player.currentTime = 0
            if !player.play() {
                soundError = "تعذر تشغيل النغمة. تحقق من مستوى الصوت ومخرج الصوت المتصل."
            }
        }
    }

    private func playHaptic(goalReached: Bool) {
        #if os(watchOS)
        WKInterfaceDevice.current().play(goalReached ? .success : .click)
        #elseif os(iOS)
        if goalReached { UINotificationFeedbackGenerator().notificationOccurred(.success) }
        else { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
        #endif
    }
}

struct TapFeedbackSettingsView: View {
    @ObservedObject private var feedback = TapFeedback.shared
    @AppStorage(TapFeedbackPreference.storageKey) private var selection = TapFeedbackMode.sound.rawValue
    @AppStorage(TapFeedbackPreference.soundEnabledKey) private var soundEnabled = true
    var body: some View {
        Form {
            Section("تنبيه كل ضغطة على هذا الجهاز") {
                Toggle("صوت نقرة خفيفة", isOn: $soundEnabled)
                Picker("نوع التنبيه", selection: $selection) {
                    ForEach(TapFeedbackMode.allCases) { mode in
                        Text(mode.title).tag(mode.rawValue)
                    }
                }
                Button("تجربة التنبيه") { feedback.play() }
                if selection == TapFeedbackMode.sound.rawValue, let error = feedback.soundError {
                    Text(error).font(.caption).foregroundStyle(.orange)
                }
            }
            Section {
                Label("تصفير تلقائي عند الهدف", systemImage: "arrow.counterclockwise")
                    .foregroundStyle(.green)
                Text("عند إكمال الهدف يبدأ عدّاد الذكر دورة جديدة من الصفر. تبقى الأذكار محفوظة وتستمر المزامنة بين الجهازين.")
                Text("اختيار التنبيه يخص هذا الجهاز. ارفع مستوى صوت الجهاز لسماع النغمة؛ في الآيفون تعمل حتى مع الوضع الصامت. تخضع الساعة لإعدادات الصوت ومخرج الصوت المتاح؛ عند تعذر تشغيل النغمة يُستخدم الاهتزاز إن كان مدعوماً. تنبيه إكمال الهدف منفصل عن تنبيه الضغطات.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .onAppear { feedback.prepare() }
        .onChange(of: soundEnabled) { _, enabled in
            if enabled { feedback.prepare() } else { feedback.stop() }
        }
        .onChange(of: selection) { _, _ in
            feedback.stop()
            feedback.prepare()
        }
        .navigationTitle(L10n.tr("تنبيه الضغطات"))
        .environment(\.layoutDirection, AppLanguage.shared.layoutDirection)
    }
}
