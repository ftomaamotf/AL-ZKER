import SwiftUI

// Simulator-only UI demonstration; this does not detect vehicle motion.
struct DrivingModePreviewGate<Content: View>: View {
    @ViewBuilder var content: () -> Content
    var body: some View {
        #if DEBUG && targetEnvironment(simulator)
        if ProcessInfo.processInfo.arguments.contains("--preview-watch-welcome") {
            GestureWelcomeView(onContinue: {})
        } else if ProcessInfo.processInfo.arguments.contains("--preview-driving-mode") {
            DrivingModePreview()
        } else { content() }
        #else
        content()
        #endif
    }
}

/// The real movement safety lock on Apple Watch.
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
                    colors: [Color.teal.opacity(0.18), Color.green.opacity(0.06), Color.clear],
                    center: .center,
                    startRadius: 0,
                    endRadius: geometry.size.height * 0.7
                )
                .ignoresSafeArea()

                VStack(spacing: 5) {
                    // 1. Top Mini Badge
                    HStack(spacing: 4) {
                        Circle().fill(Color.orange).frame(width: 5, height: 5)
                        Text("وضع الأمان مفعّل")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.orange)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay(Capsule().strokeBorder(Color.orange.opacity(0.3), lineWidth: 0.6))

                    Spacer(minLength: 2)

                    // 2. Movement safety icon in glass card
                    VStack(spacing: 3) {
                        Image(systemName: "hand.raised.fill")
                            .font(.system(size: 26, weight: .light))
                            .foregroundStyle(LinearGradient(colors: [.white, .teal.opacity(0.9)], startPoint: .top, endPoint: .bottom))
                            .frame(width: 54, height: 54)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
                            .overlay {
                                RoundedRectangle(cornerRadius: 18)
                                    .strokeBorder(
                                        LinearGradient(
                                            colors: [.white.opacity(0.4), .teal.opacity(0.6), .white.opacity(0.1)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 0.8
                                    )
                            }
                            .shadow(color: .teal.opacity(0.3), radius: 8)

                        Text("التطبيق متوقف")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)

                        Text("التسبيح متوقف أثناء الحركة")
                            .font(.system(size: 9))
                            .foregroundStyle(.white.opacity(0.75))
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .padding(.horizontal, 4)
                    }

                    Spacer(minLength: 2)

                    // 3. Status badge. The safety lock has no bypass.
                    VStack(spacing: 3) {
                        HStack(spacing: 4) {
                            Circle().fill(Color.green).frame(width: 5, height: 5)
                            Text("العدد محفوظ (\(sync.currentCount))")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(.white.opacity(0.9))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(.ultraThinMaterial, in: Capsule())
                        .overlay(Capsule().strokeBorder(Color.teal.opacity(0.3), lineWidth: 0.5))

                    }
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
        .preferredColorScheme(.dark)
    }
}
