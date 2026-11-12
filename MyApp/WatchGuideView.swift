import SwiftUI

private struct WatchGuideFeature: Identifiable {
    let id: String
    let title: String
    let symbol: String
    let summary: String
    let steps: [String]

    static let all: [Self] = [
        .init(id: "WatchGuideGestures", title: "سبّح باللمس أو الإيماءة", symbol: "hand.tap.fill",
              summary: "عدّ أذكارك من معصمك بلمسة، أو بالنقر المزدوج على الساعات المتوافقة.",
              steps: ["المس العداد أو زر (+) لإضافة تسبيحة.", "للإيماءة، أبقِ شاشة التسبيح ظاهرة والمس السبابة بالإبهام مرتين متتاليتين.", "ميزة الإيماءة تجريبية وقد تختلف استجابتها حسب طراز الساعة وإعدادات النقر المزدوج. تتطلب ساعة تدعم Double Tap مع watchOS 11 أو أحدث؛ ويبقى العدّ باللمس متاحاً دائماً."]),
        .init(id: "WatchGuideCrown", title: "كل خياراتك بتدوير التاج", symbol: "digitalcrown.horizontal.arrow.clockwise",
              summary: "دوّر التاج من شاشة التسبيح لفتح قائمة الخيارات، ثم مرّر للوصول إلى بقيتها.",
              steps: ["الأذكار، الهدف، إنقاص العدد، تصفير العداد، القبلة، تنبيه الضغطات، ثم الخصوصية.", "اختر البطاقة المطلوبة لفتحها. تظهر القبلة مباشرةً تحت تصفير العداد.", "اضغط (×) أعلى يسار القائمة للعودة إلى التسبيح."]),
        .init(id: "WatchGuideAzkar", title: "اختر ذكرك أو أضف ذكراً جديداً", symbol: "text.badge.plus",
              summary: "لكل ذكر عدّاده وهدفه المحفوظان، ويمكنك إضافة أذكارك من الساعة.",
              steps: ["من قائمة التاج افتح الأذكار، ثم اضغط الذكر الذي تريد استخدامه.", "لإضافة ذكر، اضغط «إضافة ذكر جديد»، وأدخل النص وحدد الهدف، ثم «حفظ واختيار».", "إذا كان الذكر موجوداً، يمكنك اختياره مع الاحتفاظ بعدّاده دون إنشاء نسخة مكررة."]),
        .init(id: "WatchGuideTargets", title: "حدد هدفك بطريقتك", symbol: "target",
              summary: "اختر هدفاً سريعاً، أو غيّر العدد بالتاج وأزرار الزيادة والنقصان.",
              steps: ["من قائمة التاج افتح الهدف.", "اختر ٣٣ أو ١٠٠ أو ٣٠٠ أو ١٠٠٠، أو اضبط العدد المطلوب بالتاج.", "اضغط «تأكيد وحفظ» لحفظ الهدف والعودة إلى التسبيح. عند بلوغه يبدأ العداد من الصفر لدورة جديدة."]),
        .init(id: "WatchGuideQibla", title: "اتجاه القبلة على معصمك", symbol: "location.north.circle.fill",
              summary: "افتح القبلة من قائمة التاج واستعن باتجاه المؤشر أثناء تدوير الساعة.",
              steps: ["اسمح بالوصول إلى الموقع عند طلبه لتحديد اتجاه القبلة.", "أبقِ الساعة أفقية واتبع توجيه الدوران حتى تتجه نحو القبلة.", "الزاوية الظاهرة في الصورة مثال توضيحي؛ يتغير الاتجاه الحقيقي حسب موقعك وقراءة حساسات جهازك."])
    ]
}

struct WatchGuideView: View {
    @State private var selectedImage: WatchGuideFeature?

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 22) {
                introduction
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                    Text(L10n.isEnglish ? "Apple Watch App is 100% Free" : "نسخة الساعة مجانية بالكامل للجميع")
                        .font(.subheadline.weight(.semibold))
                }
                .padding(.vertical, 4)

                NavigationLink {
                    WatchGettingStartedView()
                } label: {
                    Label(L10n.isEnglish ? "How to open app on Apple Watch?" : "كيف أفتح التطبيق على الساعة؟", systemImage: "applewatch")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)

                ForEach(WatchGuideFeature.all) { feature in
                    featureCard(feature)
                }

                counterTools
                Label(L10n.isEnglish ? "Azkar and counters save locally and sync between Watch and iPhone when connected." : "تُحفظ الأذكار والعدادات محلياً، وتصل المزامنة بين الساعة والآيفون عند توفر الاتصال.", systemImage: "arrow.triangle.2.circlepath")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text(L10n.isEnglish ? "Images are for illustration. Tap any image to enlarge." : "الصور توضيحية، وقد يختلف شكل الواجهة الفعلية باختلاف حجم الساعة وإصدار النظام. اضغط الصورة لتكبيرها.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                SupportLink()
            }
            .padding()
        }
        .navigationTitle(L10n.isEnglish ? "Fadhkuruni on Apple Watch" : "فاذكروني على الساعة")
        .navigationBarTitleDisplayMode(.inline)
        .environment(\.layoutDirection, AppLanguage.shared.layoutDirection)
        .sheet(item: $selectedImage) { feature in
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        guideImage(for: feature)
                            .accessibilityLabel(feature.title)
                        Text(feature.summary).font(.headline)
                        ForEach(feature.steps, id: \.self) { step in Text(step) }
                        Text("صورة توضيحية").font(.caption).foregroundStyle(.secondary)
                    }.padding()
                }
                .navigationTitle(feature.title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(L10n.tr("إغلاق")) { selectedImage = nil }
                    }
                }
            }
            .environment(\.layoutDirection, AppLanguage.shared.layoutDirection)
        }
    }

    private var introduction: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(L10n.isEnglish ? "Dhikr closer to you… on your wrist" : "أذكارك أقرب… على معصمك", systemImage: "applewatch")
                .font(.title2.bold())
            Label(L10n.isEnglish ? "100% Free for Everyone" : "مجانية بالكامل للجميع", systemImage: "checkmark.seal.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.green)
            Text(L10n.isEnglish ? "Tasbih, sync, crown options, and Qibla are free. Dhikr summaries, privacy cover, and Safety Mode are included in the advanced subscription after its free month." : "التسبيح والمزامنة وخيارات التاج والقبلة مجانية. أما ملخصات الذكر وحجب العداد ووضع الأمان فهي ضمن اشتراك الميزات المتقدمة بعد الشهر المجاني.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(L10n.isEnglish ? "Count by tap or gesture, select Dhikr, set targets, and view Qibla direction." : "سبّح باللمس أو الإيماءة، واختر ذكرك وحدد هدفك وافتح القبلة من قائمة التاج.")
                .font(.body)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Color.green.opacity(0.08), in: RoundedRectangle(cornerRadius: 22))
    }

    private func featureCard(_ feature: WatchGuideFeature) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Button { selectedImage = feature } label: {
                guideImage(for: feature)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("تكبير صورة: \(feature.title)")
            Label(feature.title, systemImage: feature.symbol)
                .font(.title3.bold())
            Text(feature.summary).foregroundStyle(.secondary)
            ForEach(Array(feature.steps.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .top, spacing: 10) {
                    Text((index + 1).formatted())
                        .font(.caption.bold())
                        .foregroundStyle(.green)
                        .frame(minWidth: 24, minHeight: 24)
                        .background(Color.green.opacity(0.1), in: Circle())
                        .accessibilityHidden(true)
                    Text(step).font(.subheadline)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(UIColor.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 24))
    }

    @ViewBuilder
    private func guideImage(for feature: WatchGuideFeature) -> some View {
        if feature.id == "WatchGuideGestures" {
            AnimatedGestureGuideImage()
        } else {
            Image(feature.id)
                .resizable()
                .scaledToFit()
        }
    }

    private var counterTools: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("بقية خيارات التاج").font(.title3.bold())
            Label("إنقاص العدد: تصحيح تسبيحة زائدة دون تصفير العداد.", systemImage: "minus.circle")
            Label("تصفير العداد: يبدأ عدّ الذكر الحالي من الصفر بعد تأكيدك، ويبقى الذكر محفوظاً.", systemImage: "arrow.counterclockwise")
            Label("تنبيه الضغطات: اختر نغمة قصيرة أو اهتزازاً لكل تسبيحة، أو أوقف التنبيه.", systemImage: "hand.tap")
            Label("الخصوصية: الاطلاع على سياسة بيانات التطبيق وأذوناته.", systemImage: "checkmark.shield")
        }
        .font(.subheadline)
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(UIColor.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 22))
    }
}

/// Clear static instructional artwork for the double-tap gesture.
private struct AnimatedGestureGuideImage: View {
    var body: some View {
        Image("WatchGuideGestures")
            .resizable()
            .scaledToFit()
            .accessibilityLabel("صورة توضيحية لإيماءة النقر المزدوج")
            .accessibilityAddTraits(.isImage)
    }
}

private struct WatchGettingStartedView: View {
    var body: some View {
        List {
            Section("افتح فاذكروني على الساعة") {
                Label("افتح تطبيق Watch على الآيفون المقترن بالساعة.", systemImage: "1.circle")
                Label("من «ساعتي» ثم «التطبيقات»، ابحث عن فاذكروني ضمن التطبيقات المتاحة واضغط «تثبيت» إن لم يكن مثبتاً.", systemImage: "2.circle")
                Label("اضغط تاج الساعة لعرض التطبيقات، ثم افتح فاذكروني.", systemImage: "3.circle")
                Label("ابدأ التسبيح، ودوّر التاج للوصول إلى الأذكار والأهداف وبقية الخيارات.", systemImage: "4.circle")
            }
            Section {
                Link(L10n.isEnglish ? "Apple guide for installing watch apps" : "شرح Apple لتثبيت التطبيقات", destination: URL(string: "https://support.apple.com/109023")!)
                Link(L10n.isEnglish ? "Apple guide for Double Tap gesture" : "شرح Apple للنقر المزدوج", destination: URL(string: "https://support.apple.com/guide/watch/apdabb7b275c/watchos")!)
            }
        }
        .navigationTitle(L10n.isEnglish ? "Start on Watch" : "ابدأ على الساعة")
        .navigationBarTitleDisplayMode(.inline)
        .environment(\.layoutDirection, AppLanguage.shared.layoutDirection)
    }
}
