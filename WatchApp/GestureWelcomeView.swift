import SwiftUI

/// بوابة أول تشغيل على ساعة آبل: تعرض دليل الأزرار والإيماءات لمرة واحدة بعد التثبيت
struct GestureWelcomeGate<Content: View>: View {
    @AppStorage private var hasSeenWelcome: Bool
    private let content: () -> Content

    init(storageKey: String = "fadhkuruni_watch_buttons_guide_completed_v1",
         @ViewBuilder content: @escaping () -> Content) {
        _hasSeenWelcome = AppStorage(wrappedValue: false, storageKey)
        self.content = content
    }

    var body: some View {
        if hasSeenWelcome {
            content()
        } else {
            WatchButtonsGuideView {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                    hasSeenWelcome = true
                }
            }
        }
    }
}

/// دليل الأزرار التفاعلي لأول تشغيل على ساعة آبل
struct WatchButtonsGuideView: View {
    let onContinue: () -> Void
    @State private var currentStep = 0

    private struct WatchStep: Identifiable {
        let id: Int
        let title: String
        let location: String
        let gestureType: String
        let icon: String
        let tint: Color
        let howToPress: String
        let result: String
    }

    private let steps: [WatchStep] = [
        WatchStep(
            id: 1,
            title: "دائرة العداد والتمويه",
            location: "منتصف شاشة الساعة",
            gestureType: "نقرة سريعة • ضغط مطول",
            icon: "circle.circle.fill",
            tint: .green,
            howToPress: "انقر نقرة سريعة للعد، أو اضغط مطولاً لنصف ثانية.",
            result: "النقرة تزيد العداد، والضغط المطول يُخفي أو يُظهر وجه الساعة الزمردية لحجب رقم العداد للخصوصية."
        ),
        WatchStep(
            id: 2,
            title: "زر القبلة والكعبة الشريفة",
            location: "أعلى يمين شاشة الساعة",
            gestureType: "نقرة واحدة (Tap)",
            icon: "safari.fill",
            tint: .yellow,
            howToPress: "اضغط الزر الدائري أعلى يمين الشاشة.",
            result: "يفتح بوصلة القبلة داخل دائرة الساعة، وعند التوجه الصحيح تظهر الكعبة المشرفة داخل قبة كريستالية."
        ),
        WatchStep(
            id: 3,
            title: "تدوير التاج الرقمي",
            location: "زر التاج على جانب الساعة",
            gestureType: "تدوير للأعلى أو الأسفل",
            icon: "digitalcrown.horizontal.arrow.clockwise",
            tint: .mint,
            howToPress: "من شاشة التسبيح، حرّك التاج الجانبي للأعلى أو الأسفل.",
            result: "تفتح قائمة الخيارات لتغيير الذكر وتحديد الهدف وتشغيل/إيقاف أدوات العداد."
        ),
        WatchStep(
            id: 4,
            title: "أزرار الإنقاص والتصفير",
            location: "أسفل دائرة العداد",
            gestureType: "نقرة مباشرة مع تأكيد",
            icon: "arrow.counterclockwise",
            tint: .white,
            howToPress: "اضغط (-) للتراجع خطوة، أو (↺) لتصفير الورد الحالي.",
            result: "تصحيح دقيق للعد عند الخطأ، وتصفير آمن للورد الحالي مع نافذة تأكيد تحميك من الخطأ."
        ),
        WatchStep(
            id: 5,
            title: "إيماءة النقر المزدوج",
            location: "مستشعرات حركة المعصم",
            gestureType: "نقر السبابة بالإبهام مرتين",
            icon: "hand.tap.fill",
            tint: .green,
            howToPress: "انقر السبابة بالإبهام مرتين متتاليتين في الهواء.",
            result: "تسبيح فوري وسري دون لمس الشاشة نهائياً (على الساعات المدعومة مثل Series 9/10 و Ultra 2)."
        )
    ]

    var body: some View {
        TabView(selection: $currentStep) {
            ForEach(0..<steps.count, id: \.self) { index in
                stepPageView(steps[index])
                    .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .environment(\.layoutDirection, .rightToLeft)
    }

    @ViewBuilder
    private func stepPageView(_ step: WatchStep) -> some View {
        ScrollView {
            VStack(spacing: 8) {
                // شارة رقم الخطوة والأيقونة
                HStack(spacing: 6) {
                    Text("\(step.id) من \(steps.count)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.yellow, in: Capsule())

                    Spacer()

                    Text(step.gestureType)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(step.tint)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(step.tint.opacity(0.18), in: Capsule())
                }
                .padding(.top, 2)

                Image(systemName: step.icon)
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(step.tint)
                    .frame(width: 48, height: 48)
                    .background(step.tint.opacity(0.15), in: Circle())

                Text(step.title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text(step.location)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 6) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("🔘 كيف تضغط أو تستخدم:")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color.green)
                        Text(step.howToPress)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.white.opacity(0.9))
                    }

                    Divider().overlay(.white.opacity(0.1))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("✨ ماذا يفعل الزر:")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color.yellow)
                        Text(step.result)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.white.opacity(0.85))
                    }
                }
                .padding(8)
                .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))

                // زر الانتقال أو الإنهاء
                if currentStep == steps.count - 1 {
                    Button {
                        WKInterfaceDevice.current().play(.success)
                        onContinue()
                    } label: {
                        Text("فهمت، ابدأ التسبيح")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Color.green, in: RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)
                } else {
                    Button {
                        withAnimation { currentStep += 1 }
                        WKInterfaceDevice.current().play(.click)
                    } label: {
                        Text("التالي →")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 7)
                            .background(.white.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 2)
                }
            }
            .padding(.horizontal, 6)
            .padding(.bottom, 12)
        }
    }
}
