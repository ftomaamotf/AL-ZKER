import SwiftUI
#if canImport(WatchKit)
import WatchKit
#endif

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

                VStack(spacing: 4) {
                    // 1. Top Mini Badge
                    HStack(spacing: 4) {
                        Circle().fill(Color.orange).frame(width: 5, height: 5)
                        Text(L10n.isEnglish ? "Safety Mode" : "وضع الأمان مفعّل")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.orange)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay(Capsule().strokeBorder(Color.orange.opacity(0.3), lineWidth: 0.6))

                    Spacer(minLength: 1)

                    // 2. Movement safety icon in glass card
                    VStack(spacing: 2) {
                        Image(systemName: "hand.raised.fill")
                            .font(.system(size: 22, weight: .light))
                            .foregroundStyle(LinearGradient(colors: [.white, .teal.opacity(0.9)], startPoint: .top, endPoint: .bottom))
                            .frame(width: 44, height: 44)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
                            .overlay {
                                RoundedRectangle(cornerRadius: 14)
                                    .strokeBorder(
                                        LinearGradient(
                                            colors: [.white.opacity(0.4), .teal.opacity(0.6), .white.opacity(0.1)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 0.8
                                    )
                            }
                            .shadow(color: .teal.opacity(0.3), radius: 6)

                        Text(L10n.isEnglish ? "App Paused" : "التطبيق متوقف")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)

                        Text(L10n.isEnglish ? "Tasbih paused while driving" : "التسبيح متوقف أثناء القيادة")
                            .font(.system(size: 8.5))
                            .foregroundStyle(.white.opacity(0.75))
                            .multilineTextAlignment(.center)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 1)

                    // 3. Status badge & confirm stop button
                    VStack(spacing: 4) {
                        HStack(spacing: 4) {
                            Circle().fill(Color.green).frame(width: 5, height: 5)
                            Text(L10n.isEnglish ? "Count saved (\(sync.currentCount))" : "العدد محفوظ (\(sync.currentCount))")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(.white.opacity(0.9))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(.ultraThinMaterial, in: Capsule())
                        .overlay(Capsule().strokeBorder(Color.teal.opacity(0.3), lineWidth: 0.5))

                        if !isPreview {
                            Button {
                                #if os(watchOS)
                                WKInterfaceDevice.current().play(.click)
                                #endif
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                                    sync.confirmStopped()
                                }
                            } label: {
                                HStack(spacing: 5) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 11, weight: .bold))
                                    Text(L10n.isEnglish ? "Confirm Stopped" : "تأكيد الوقوف")
                                        .font(.system(size: 11, weight: .bold))
                                }
                                .foregroundStyle(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                                .background(
                                    LinearGradient(colors: [Color.green, Color.mint], startPoint: .leading, endPoint: .trailing),
                                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                                )
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 10)
                        }
                    }
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                #if os(watchOS)
                WKInterfaceDevice.current().play(.click)
                #endif
                sync.checkDrivingStatusFromPhone()
            }
        }
        .environment(\.layoutDirection, AppLanguage.shared.layoutDirection)
        .preferredColorScheme(.dark)
        .task {
            guard !isPreview else { return }
            sync.checkDrivingStatusFromPhone()
            while !Task.isCancelled && sync.isDrivingLocked {
                try? await Task.sleep(nanoseconds: 1_200_000_000)
                sync.checkDrivingStatusFromPhone()
            }
        }
    }
}
