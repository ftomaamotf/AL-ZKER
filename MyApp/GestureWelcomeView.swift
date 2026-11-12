import SwiftUI

/// بوابة أول تشغيل على الآيفون: تعرض دليل أزرار التطبيق وطريقة استخدامها لمرة واحدة بعد التثبيت
struct GestureWelcomeGate<Content: View>: View {
    @AppStorage private var hasSeenWelcome: Bool
    private let content: () -> Content

    init(storageKey: String = "fadhkuruni_first_launch_buttons_guide_v1",
         @ViewBuilder content: @escaping () -> Content) {
        _hasSeenWelcome = AppStorage(wrappedValue: false, storageKey)
        self.content = content
    }

    var body: some View {
        if hasSeenWelcome {
            content()
        } else {
            PhoneButtonsGuideView {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                    hasSeenWelcome = true
                }
            }
        }
    }
}

/// دليل الأزرار التفاعلي لأول تشغيل على الآيفون
struct PhoneButtonsGuideView: View {
    let onContinue: () -> Void
    @State private var currentStep = 0

    private struct GuideStep: Identifiable {
        let id: Int
        let title: String
        let location: String
        let gestureType: String
        let icon: String
        let iconColor: Color
        let howToPress: String
        let actionResult: String
        let detailedDescription: String
    }

    private let steps: [GuideStep] = [
        GuideStep(
            id: 1,
            title: "زر اتجاه القبلة الشريفة",
            location: "أعلى يسار شاشة الآيفون",
            gestureType: "نقرة واحدة (Tap)",
            icon: "safari.fill",
            iconColor: .green,
            howToPress: "اضغط نقرة خفيفة لفتح القبلة، واضغط «العودة لعدّاد التسبيح» للرجوع.",
            actionResult: "تتحول دائرة العداد لبوصلة القبلة، وعند التوجه الصحيح تظهر الكعبة الشريفة المضيئة داخل قبة كريستالية.",
            detailedDescription: "معرفة اتجاه الصلاة أينما كنت فوراً وبدقة عالية دون مغادرة الشاشة أو فتح تطبيق خارجي."
        ),
        GuideStep(
            id: 2,
            title: "زر حجب وتمويه شاشة الساعة",
            location: "الشريط العلوي — رمز الجوهرة",
            gestureType: "نقرة سريعة • ضغط مطول",
            icon: "diamond.fill",
            iconColor: .mint,
            howToPress: "نقرة سريعة = تفعيل/إلغاء حجب الساعة • ضغط مطول = اختيار صورة لميناء الساعة.",
            actionResult: "تتحول شاشة ساعة آبل إلى ساعة زمردية فاخرة أو صورتك الخاصة، لتحجب رقم العداد والهدف تماماً.",
            detailedDescription: "خصوصية كاملة أثناء التسبيح في الأماكن العامة والاجتماعات، حيث تبدو ساعتك كساعة عادية أنيقة."
        ),
        GuideStep(
            id: 3,
            title: "دليل وشروحات ساعة آبل",
            location: "الشريط العلوي — رمز الساعة",
            gestureType: "نقرة واحدة (Tap)",
            icon: "applewatch",
            iconColor: .white,
            howToPress: "اضغط على أيقونة الساعة للاطلاع على الشروحات المصورة وإيماءات المعصم.",
            actionResult: "يفتح دليلاً مفصلاً لكافة ميزات الساعة وإيماءة النقر المزدوج وتدوير التاج.",
            detailedDescription: "فهم كامل لمزامنة الساعة وميزاتها المستقلة لضمان أفضل تجربة تسبيح من معصمك."
        ),
        GuideStep(
            id: 4,
            title: "دائرة العداد وبطاقة التسبيح",
            location: "المنطقة المركزية الكبرى",
            gestureType: "نقرة • سحب أفقياً • ضغط مطول",
            icon: "circle.circle.fill",
            iconColor: .green,
            howToPress: "المس الدائرة للعد • اسحب يميناً/يساراً للذكر التالي • اضغط مطولاً للحجب.",
            actionResult: "زيادة العداد بحساسية لمس فائقة مع اهتزاز وصوت، والانتقال السلس بين الأذكار.",
            detailedDescription: "قلب التطبيق التفاعلي؛ يمكنك التسبيح بلمس أي مكان داخل الشاشة مع حماية من تكرار اللمس الخطأ."
        ),
        GuideStep(
            id: 5,
            title: "زر قفل الأخطاء الذكي",
            location: "أسفل البطاقة / الشريط السفلي",
            gestureType: "نقرة واحدة للتبديل (Lock)",
            icon: "lock.shield.fill",
            iconColor: .yellow,
            howToPress: "اضغط زر القفل في الشريط السفلي لتأمين عدادك من أي لمسة خاطئة.",
            actionResult: "يقفل أزرار التصفير والإنقاص والتبويبات، لتصبح الشاشة كلها مساحة تسبيح آمنة.",
            detailedDescription: "حماية تامة لوردك اليومي من التصفير بالخطأ أثناء المشي، الرياضة، أو وضع الهاتف في الجيب."
        ),
        GuideStep(
            id: 6,
            title: "شريط التحكم (زيادة • إنقاص • تصفير)",
            location: "أسفل الشاشة الرئيسية",
            gestureType: "نقرات مباشرة ومحمية",
            icon: "plus.slash.minus",
            iconColor: .green,
            howToPress: "اضغط (+) للزيادة، (-) للإنقاص خطوة للخلف، و(↺) للتصفير مع نافذة تأكيد آمنة.",
            actionResult: "تحكم كامل وسهل في تتبع وإحصاء وضبط أورادك اليومية وأهدافك.",
            detailedDescription: "نافذة التصفير تتطلب تأكيداً لضمان عدم ضياع وردك، مع تراجع دقيق خطوة بخطوة عند السهو."
        )
    ]

    var body: some View {
        ZStack {
            // خلفية ليلية زمردية فاخرة
            LinearGradient(
                colors: [
                    Color(red: 0.01, green: 0.08, blue: 0.05),
                    Color(red: 0.02, green: 0.18, blue: 0.11),
                    Color.black
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // الشريط العلوي: شارة الترحيب وزر التخطي
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .foregroundStyle(Color.green)
                            .font(.subheadline)
                        Text("فَاذْكُرُونِي — دليل أول تشغيل")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    Spacer()
                    Button("تخطي") {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        onContinue()
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.white.opacity(0.08), in: Capsule())
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 12)

                // مؤشر الخطوات (Step Indicator Dots)
                HStack(spacing: 6) {
                    ForEach(0..<steps.count, id: \.self) { index in
                        Capsule()
                            .fill(index == currentStep ? Color.green : Color.white.opacity(0.20))
                            .frame(width: index == currentStep ? 24 : 7, height: 7)
                            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: currentStep)
                    }
                }
                .padding(.vertical, 10)

                // مساحة العرض الرئيسية للخطوة النشطة
                TabView(selection: $currentStep) {
                    ForEach(0..<steps.count, id: \.self) { index in
                        stepCard(steps[index])
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                // الشريط السفلي: أزرار التنقل (السابق / التالي / إنهاء)
                HStack(spacing: 14) {
                    if currentStep > 0 {
                        Button {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                currentStep -= 1
                            }
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.right")
                                Text("السابق")
                            }
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.85))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 16))
                        }
                    }

                    Button {
                        if currentStep < steps.count - 1 {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                currentStep += 1
                            }
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        } else {
                            UINotificationFeedbackGenerator().notificationOccurred(.success)
                            onContinue()
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Text(currentStep < steps.count - 1 ? (L10n.isEnglish ? "Next" : "التالي") : (L10n.isEnglish ? "Start Tasbih Now" : "ابدأ التسبيح الآن"))
                            Image(systemName: currentStep < steps.count - 1 ? (L10n.isRTL ? "arrow.left" : "arrow.right") : "checkmark.circle.fill")
                        }
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(colors: [Color.green, Color.mint], startPoint: .topLeading, endPoint: .bottomTrailing),
                            in: RoundedRectangle(cornerRadius: 16)
                        )
                        .shadow(color: Color.green.opacity(0.4), radius: 8, y: 3)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 24)
            }
        }
        .environment(\.layoutDirection, AppLanguage.shared.layoutDirection)
    }

    @ViewBuilder
    private func stepCard(_ step: GuideStep) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                // بطاقة الأيقونة البارزة
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [step.iconColor.opacity(0.35), step.iconColor.opacity(0.08), .clear],
                                center: .center,
                                startRadius: 10,
                                endRadius: 65
                            )
                        )
                        .frame(width: 120, height: 120)

                    Circle()
                        .strokeBorder(step.iconColor.opacity(0.4), lineWidth: 1.5)
                        .frame(width: 90, height: 90)
                        .background(Circle().fill(.ultraThinMaterial))

                    Image(systemName: step.icon)
                        .font(.system(size: 38, weight: .semibold))
                        .foregroundStyle(step.iconColor)
                        .shadow(color: step.iconColor.opacity(0.5), radius: 8)

                    // رقم الخطوة
                    Text("\(step.id)")
                        .font(.system(size: 12, weight: .black))
                        .foregroundStyle(.black)
                        .frame(width: 24, height: 24)
                        .background(Color.yellow, in: Circle())
                        .offset(x: 32, y: -32)
                        .shadow(radius: 3)
                }
                .padding(.top, 8)

                // العناوين
                VStack(spacing: 6) {
                    Text(step.title)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)

                    HStack(spacing: 8) {
                        Label(step.location, systemImage: "mappin.and.ellipse")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)

                        Text("•")
                            .foregroundStyle(.secondary)

                        Text(step.gestureType)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color.green)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.12), in: Capsule())
                    }
                }

                // بطاقة تفاصيل الضغط والنتيجة
                VStack(alignment: .leading, spacing: 14) {
                    detailRow(title: "طريقة الضغط أو الاستخدام", text: step.howToPress, icon: "hand.tap.fill", tint: .green)
                    Divider().overlay(Color.white.opacity(0.1))
                    detailRow(title: "ماذا يفعل الزر", text: step.actionResult, icon: "sparkles", tint: .yellow)
                    Divider().overlay(Color.white.opacity(0.1))
                    detailRow(title: "فائدته لوردك اليومي", text: step.detailedDescription, icon: "info.circle.fill", tint: .mint)
                }
                .padding(18)
                .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 24))
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                )
                .padding(.horizontal, 20)

                // ملحوظة إعادة الفتح
                Text("💡 يمكنك مراجعة هذا الدليل متى شئت من قائمة: الإعدادات ⚙️ ➔ دليل استخدام الأزرار.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.top, 4)
            }
            .padding(.bottom, 20)
        }
    }

    @ViewBuilder
    private func detailRow(title: String, text: String, icon: String, tint: Color) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 28, height: 28)
                .background(tint.opacity(0.15), in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                Text(text)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.80))
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(3)
            }
        }
    }
}
