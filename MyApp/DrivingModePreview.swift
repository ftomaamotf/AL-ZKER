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
                    Text("فَاذْكُرُونِي")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    
                    HStack(spacing: 8) {
                        Circle().fill(Color.orange).frame(width: 8, height: 8)
                        Text("وضع الأمان مفعّل")
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

                        Text("التطبيق متوقف")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(.white)

                        Text("مؤقتاً أثناء الحركة")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.75))
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                            .padding(.horizontal, 24)
                    }

                    Spacer(minLength: 16)

                    // 3. Bottom status. The safety lock has no bypass.
                    VStack(spacing: 12) {
                        HStack(spacing: 6) {
                            Circle().fill(Color.green).frame(width: 7, height: 7)
                            Text("العدد محفوظ (\(sync.currentCount))")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.white.opacity(0.9))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 7)
                        .background(.ultraThinMaterial, in: Capsule())
                        .overlay(Capsule().strokeBorder(Color.teal.opacity(0.3), lineWidth: 0.5))

                        Text("يعود العداد للعمل تلقائياً عند السكون")
                            .font(.caption2)
                            .foregroundStyle(.secondary)

                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 28)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
        .preferredColorScheme(.dark)
    }
}
