import SwiftUI

// Simulator-only UI demonstration; this does not detect vehicle motion.
struct DrivingModePreviewGate<Content: View>: View {
    @ViewBuilder var content: () -> Content
    var body: some View {
        #if DEBUG && targetEnvironment(simulator)
        if ProcessInfo.processInfo.arguments.contains("--preview-driving-mode") {
            DrivingModePreview()
        } else { content() }
        #else
        content()
        #endif
    }
}

/// The real movement safety lock.
struct DrivingModeGate<Content: View>: View {
    @ObservedObject private var sync = WatchSyncService.shared
    @ViewBuilder var content: () -> Content

    var body: some View {
        if sync.isDrivingLocked {
            DrivingModePreview(isPreview: false)
        } else {
            content()
        }
    }
}

struct DrivingModePreview: View {
    var isPreview = true
    @ObservedObject private var sync = WatchSyncService.shared

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.ignoresSafeArea()
                RadialGradient(
                    colors: [Color.teal.opacity(0.2), Color.green.opacity(0.08), Color.clear],
                    center: .center,
                    startRadius: 0,
                    endRadius: geometry.size.height * 0.7
                )
                .ignoresSafeArea()

                VStack(spacing: 22) {
                    // 1. Top Header
                    Text(L10n.tr("فَاذْكُرُونِي"))
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    
                    HStack(spacing: 8) {
                        Circle().fill(Color.orange).frame(width: 8, height: 8)
                        Text(L10n.isEnglish ? "Safety Mode Active" : "وضع الأمان مفعّل")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.orange)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay(Capsule().strokeBorder(Color.orange.opacity(0.35), lineWidth: 0.8))

                    Spacer(minLength: 16)

                    // 2. Movement safety glass card
                    VStack(spacing: 16) {
                        Image(systemName: "hand.raised.fill")
                            .font(.system(size: 52, weight: .light))
                            .foregroundStyle(LinearGradient(colors: [.white, .teal.opacity(0.9)], startPoint: .top, endPoint: .bottom))
                            .frame(width: 118, height: 118)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 30))
                            .overlay {
                                RoundedRectangle(cornerRadius: 30)
                                    .strokeBorder(
                                        LinearGradient(
                                            colors: [.white.opacity(0.5), .teal.opacity(0.6), .white.opacity(0.1)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1
                                    )
                            }
                            .shadow(color: .teal.opacity(0.35), radius: 18)

                        Text(L10n.isEnglish ? "App Paused" : "التطبيق متوقف")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(.white)

                        Text(L10n.isEnglish ? "Temporarily while driving for your safety" : "مؤقتاً أثناء القيادة")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.75))
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                            .padding(.horizontal, 24)
                    }

                    Spacer(minLength: 16)

                    // 3. Bottom status & confirm stop button
                    VStack(spacing: 14) {
                        HStack(spacing: 6) {
                            Circle().fill(Color.green).frame(width: 7, height: 7)
                            Text(L10n.isEnglish ? "Count saved (\(sync.currentCount))" : "العدد محفوظ (\(sync.currentCount))")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.white.opacity(0.9))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 7)
                        .background(.ultraThinMaterial, in: Capsule())
                        .overlay(Capsule().strokeBorder(Color.teal.opacity(0.3), lineWidth: 0.5))

                        // زر تأكيد الوقوف
                        Button {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                                DrivingModeManager.shared.confirmStopped()
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 18, weight: .bold))
                                Text(L10n.isEnglish ? "Confirm Stopped & Resume" : "تأكيد الوقوف والعودة للعدّ")
                                    .font(.system(size: 16, weight: .bold))
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                LinearGradient(
                                    colors: [Color.green, Color.mint],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                            )
                            .shadow(color: Color.green.opacity(0.35), radius: 10, y: 3)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 20)

                        Text(L10n.isEnglish ? "Counting resumes automatically when stationary, or tap above" : "يعود العداد للعمل تلقائياً عند توقف السيارة، أو اضغط للتأكيد يدوياً")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 28)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .environment(\.layoutDirection, AppLanguage.shared.layoutDirection)
        .preferredColorScheme(.dark)
    }
}
