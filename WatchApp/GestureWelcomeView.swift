import SwiftUI

/// The phone and watch each remember their own first-launch acknowledgement.
struct GestureWelcomeGate<Content: View>: View {
    @AppStorage private var hasSeenWelcome: Bool
    private let content: () -> Content

    init(storageKey: String = "fadhkuruni_gesture_welcome_completed_v1",
         @ViewBuilder content: @escaping () -> Content) {
        _hasSeenWelcome = AppStorage(wrappedValue: false, storageKey)
        self.content = content
    }

    var body: some View {
        if hasSeenWelcome {
            content()
        } else {
            GestureWelcomeView { hasSeenWelcome = true }
        }
    }
}

private struct GestureInstructionsView: View {
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            ScrollView {
                VStack(spacing: 14) {
                    Image(systemName: "hand.tap.fill")
                        .font(.largeTitle)
                        .foregroundStyle(.green)
                        .accessibilityHidden(true)
                    Text("سبّح بالإيماءة دون لمس الساعة")
                        .font(.headline)
                        .multilineTextAlignment(.center)
                    Text("يتوفر في التطبيق التسبيح بالإيماءة والنقر المزدوج دون لمس شاشة الساعة، على ساعات Apple Watch المتوافقة.")
                    Text("لزيادة عدّاد الذكر، المس السبابة بالإبهام مرتين متتاليتين بينما يظهر زر الزيادة (+) على الساعة.")
                    Text("تعمل الإيماءة على Apple Watch Series 9 وما بعدها، وUltra 2 وما بعدها، وSE 3. يلزم دعم Double Tap وتفعيلها من إعدادات الساعة، مع watchOS 11 أو أحدث.")
                        .foregroundStyle(.secondary)
                    Text("ويمكنك دائمًا التسبيح بلمس الشاشة على الآيفون والساعة.")
                        .foregroundStyle(.green)
                }
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .padding(.top, 8)
            }
            #if os(watchOS)
            .font(.footnote)
            #endif
            Button("فهمت، ابدأ التسبيح", action: onContinue)
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .padding(.horizontal)
                .padding(.bottom, 8)
        }
        .environment(\.layoutDirection, .rightToLeft)
    }
}

// First-launch introduction to the Crown, followed by the existing gesture guide.
struct GestureWelcomeView: View {
    let onContinue: () -> Void
    @State private var showGestures = false
    var body: some View {
        if showGestures {
            GestureInstructionsView(onContinue: onContinue)
        } else {
            VStack(spacing: 8) {
                ScrollView {
                    VStack(spacing: 10) {
                        Image(systemName: "digitalcrown.horizontal.arrow.clockwise")
                            .font(.system(size: 34, weight: .light))
                            .foregroundStyle(.mint)
                            .frame(width: 66, height: 60)
                            .fadhkuruniGlass(tint: .teal, radius: 20)
                            .accessibilityHidden(true)
                        Text("خياراتك في التاج")
                            .font(.system(size: 18, weight: .semibold))
                        Text("دوّر التاج الجانبي لفتح الخيارات")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.mint)
                        Text("من شاشة العدّاد، حرّك التاج للأعلى أو للأسفل لتظهر قائمة الخيارات.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 9) {
                            Label("اختيار ذكر أو إضافة ذكر", systemImage: "list.bullet")
                            Label("تحديد هدف التسبيح", systemImage: "target")
                            Label("القبلة وإعدادات الأزرار", systemImage: "location.north")
                        }
                        .font(.caption2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 14))
                    }
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 8)
                    .padding(.top, 4)
                }
                Button { showGestures = true } label: {
                    Text("التالي")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(maxWidth: .infinity, minHeight: 42)
                        .fadhkuruniGlass(tint: .green, radius: 15)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 8)
                .padding(.bottom, 4)
            }
            .environment(\.layoutDirection, .rightToLeft)
        }
    }
}
