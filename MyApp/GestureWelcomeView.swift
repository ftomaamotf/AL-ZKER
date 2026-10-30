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

private struct GestureWelcomeView: View {
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
