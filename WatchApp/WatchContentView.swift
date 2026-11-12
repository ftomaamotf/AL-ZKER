import SwiftUI
import WatchKit

// دعم إيماءة النقر المزدوج باليد على ساعة آبل (Apple Watch Double Tap)
extension View {
    @ViewBuilder
    func enableDoubleTapGesture() -> some View {
        if #available(watchOS 11.0, *) {
            self.handGestureShortcut(.primaryAction)
        } else {
            self
        }
    }
}

struct WatchContentView: View {
    @ObservedObject private var sync = WatchSyncService.shared
    @Environment(\.scenePhase) private var scenePhase
    
    // استشعار تدوير زر التاج (Digital Crown)
    @State private var crownRotation: Double = 0.0
    @State private var showCrownMenu: Bool = false
    @State private var pendingScreenReset: ZekrItem?
    @State private var showScreenResetConfirmation = false
    @FocusState private var isCrownFocused: Bool
    @State private var isQiblaActive: Bool = false
    @State private var isPrayerTimesActive: Bool = false
    @ObservedObject private var qibla = QiblaManager.shared

    // توقيت آخر تسبيحة لإلغاء وتفادي أي هزة ثانية متكررة عند تحريك الأصابع
    @State private var lastIncrementTime: Date = .distantPast
    @State private var isCounterPressing = false

    var body: some View {
        VStack(spacing: 2) {
            // 1. الشريط العلوي: زر القبلة بأعلى اليمين + اسم الذكر
            HStack(alignment: .center) {
                // الزاوية اليمنى: القبلة.
                VStack(spacing: 7) {
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            isQiblaActive.toggle()
                            if isQiblaActive {
                                isPrayerTimesActive = false
                                QiblaManager.shared.start()
                            } else {
                                QiblaManager.shared.stop()
                            }
                        }
                        WKInterfaceDevice.current().play(.click)
                    } label: {
                        ZStack {
                            Circle()
                                .fill(isQiblaActive ? Color.green : Color.green.opacity(0.18))
                                .frame(width: 32, height: 32)
                                .overlay(
                                    Circle()
                                        .strokeBorder(Color.green.opacity(0.45), lineWidth: 1)
                                )
                            Image(systemName: "safari.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(isQiblaActive ? Color.black : Color.green)
                        }
                        .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(isQiblaActive ? "العودة للعدّاد" : "اتجاه القبلة")

                }
                .offset(y: -24)

                Spacer()

                // عنوان الذكر / التطبيق
                VStack(alignment: .trailing, spacing: 1) {
                    if isPrayerTimesActive {
                        Text("مواقيت الصلاة")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                    } else if isQiblaActive {
                        Text("اتجاه القبلة")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)

                        Text(qibla.isAligned ? "محاذاة تامة" : "وجّه الساعة")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(qibla.isAligned ? Color.yellow : Color.secondary)
                            .lineLimit(1)
                    } else if sync.showsWatchClockCover {
                        // عند حجب شاشة الساعة: إخفاء نوع الذكر تماماً للخصوصية التامة
                        Text("فَاذْكُرُونِي")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                    } else {
                        Text(sync.currentZekr)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }
                .offset(y: (sync.showsWatchClockCover && !isQiblaActive) ? -38 : -46)
                .padding(.bottom, -14)
                .animation(.spring(response: 0.35, dampingFraction: 0.8), value: sync.showsWatchClockCover)

                // الزاوية اليسرى: مواقيت الصلاة.
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        isPrayerTimesActive.toggle()
                        if isPrayerTimesActive {
                            isQiblaActive = false
                            QiblaManager.shared.stop()
                        }
                    }
                    sync.requestSyncFromPhone()
                    WKInterfaceDevice.current().play(.click)
                } label: {
                    ZStack {
                        Circle()
                            .fill(isPrayerTimesActive ? Color.green : Color.green.opacity(0.18))
                            .frame(width: 32, height: 32)
                            .overlay(Circle().strokeBorder(Color.green.opacity(0.45), lineWidth: 1))
                        Image(systemName: "moon.stars.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(isPrayerTimesActive ? Color.black : Color.green)
                    }
                    .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .offset(y: -24)
                .accessibilityLabel(isPrayerTimesActive ? "العودة للعدّاد" : "مواقيت الصلاة")

            }
            .padding(.horizontal, 4)
            .padding(.top, 18)

            // 2. المنطقة المركزية: دائرة العداد المتطابقة مع الآيفون أو بوصلة القبلة
            ZStack {
                if isPrayerTimesActive {
                    watchPrayerCircleView
                } else if isQiblaActive {
                    watchQiblaCircleView
                } else {
                    watchCounterCircleView
                }
            }
            .frame(width: 136, height: 136)
            .scaleEffect(1.20)
            .frame(width: 164, height: 164)
            .offset(y: -36)
            .padding(.bottom, -36)

        }
        .sheet(isPresented: $showScreenResetConfirmation, onDismiss: { pendingScreenReset = nil }) {
            WatchResetConfirmationView {
                if let item = pendingScreenReset {
                    sync.resetZekrCount(for: item)
                    lastIncrementTime = Date()
                    WatchKeepAwakeManager.shared.recordCountingActivity()
                    WKInterfaceDevice.current().play(.success)
                }
                pendingScreenReset = nil
            }
        }
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        // The background receives only empty-screen taps while an auxiliary
        // screen is visible. It never competes with the counter's own Button.
        .background {
            if isQiblaActive || isPrayerTimesActive {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { returnToCounter() }
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
        // ربط تدوير زر التاج (Digital Crown) لإظهار الخيارات
        .focusable()
        .focused($isCrownFocused)
        .digitalCrownRotation(
            $crownRotation,
            from: -100.0,
            through: 100.0,
            by: 1.0,
            sensitivity: .low,
            isContinuous: false,
            isHapticFeedbackEnabled: false // تعطيل اهتزاز التاج لعدم إصدار أي نقرة ثانوية عند حركة اليد
        )
        .onChange(of: crownRotation) { _, newValue in
            guard abs(newValue) >= 1.0,
                  !showCrownMenu else { return }
            crownRotation = 0
            isCrownFocused = false
            WKInterfaceDevice.current().play(.directionUp)
            showCrownMenu = true
        }
        // عرض شاشة الخيارات (تحديد الهدف وتغيير نوع الذكر)
        .sheet(isPresented: $showCrownMenu) {
            CrownOptionsView(sync: sync, isPresented: $showCrownMenu)
        }
        .onChange(of: showCrownMenu) { _, isShowing in
            if !isShowing {
                crownRotation = 0
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    restoreCrownFocus()
                }
            }
        }
        // إبقاء الساعة مستيقظة طالما التطبيق مفتوح ومزامنة العداد فوراً مع الآيفون
        .onAppear {
            sync.activateSession()
            WatchKeepAwakeManager.shared.beginCountingSession()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                restoreCrownFocus()
            }
        }
        // إعادة الساعة إلى طبيعتها وحفظ الطاقة فور الخروج من التطبيق
        .onDisappear {
            WatchKeepAwakeManager.shared.stopKeepAwake()
            if isQiblaActive {
                QiblaManager.shared.stop()
            }
        }
        .onChange(of: scenePhase) {
            if scenePhase == .active {
                sync.activateSession()
                WatchKeepAwakeManager.shared.resumeCountingSession()
                restoreCrownFocus()
                if isQiblaActive {
                    QiblaManager.shared.start()
                }
            } else if scenePhase == .background {
                WatchKeepAwakeManager.shared.stopKeepAwake()
                isCrownFocused = false
                if isQiblaActive {
                    QiblaManager.shared.stop()
                }
            }
            // Inactive (for example, a lowered wrist) keeps the existing session and idle deadline.
        }
    }

    // MARK: - دائرة العداد المتطابقة مع الآيفون
    private var watchCounterCircleView: some View {
        ZStack {
            Group {
                // حلقة المسار الخلفية
                Circle()
                    .stroke(Color.green.opacity(0.14), lineWidth: 6)

                // حلقة التقدم المضيئة
                Circle()
                    .trim(from: 0, to: sync.target > 0 ? min(1, max(0, Double(sync.currentCount) / Double(sync.target))) : 0)
                    .stroke(
                        LinearGradient(colors: [.green.opacity(0.65), .mint], startPoint: .bottomLeading, endPoint: .topTrailing),
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.35, dampingFraction: 0.8), value: sync.currentCount)
            }

            // A complete luminous ring appears around the existing edge on
            // every tasbih, without shrinking the circle or the counter text.
            Circle()
                .stroke(
                    LinearGradient(colors: [.white, .mint, .green], startPoint: .leading, endPoint: .trailing),
                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                )
                .opacity(isCounterPressing ? 1 : 0)
                .scaleEffect(isCounterPressing ? 1.02 : 0.98)
                .shadow(color: .mint.opacity(isCounterPressing ? 0.9 : 0), radius: 5)

            if sync.showsWatchClockCover {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    EmeraldAnalogClock(
                        date: context.date,
                        photoData: sync.watchClockPhotoData
                    )
                }
                .offset(y: 0)
                .allowsHitTesting(false)
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            } else {
                // الرقم والهدف في المنتصف
                VStack(spacing: 2) {
                    Text("\(sync.currentCount)")
                        .font(.system(size: 38, weight: .bold, design: .rounded))
                        .foregroundStyle(.green)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)

                    Text("الهدف \(sync.target)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Text("فَاذْكُرُونِي")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(Color.secondary)
                        .lineLimit(1)
                }
                .padding(12)
                .offset(y: -22)
                .allowsHitTesting(false)
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }

            // The system's hand double-tap shortcut must be attached to an
            // actual Button. Its near-transparent fill keeps the control
            // visually invisible while retaining a reliable touch target.
            Button(action: incrementCount) {
                Circle().fill(Color.black.opacity(0.001))
            }
            .buttonStyle(.plain)
            .frame(width: 136, height: 136)
            .contentShape(Circle())
            .enableDoubleTapGesture()
            .accessibilityLabel("تسبيح بالإيماءة")

            if !sync.showsWatchClockCover && sync.showsDecrementButton {
                Button { decrementCount() } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.85))
                        .frame(width: 30, height: 30)
                        .fadhkuruniGlass(radius: 15)
                }
                .buttonStyle(.plain)
                .disabled(sync.currentCount == 0)
                .opacity(sync.currentCount == 0 ? 0.35 : 1)
                .offset(x: -27, y: 31)
                .accessibilityLabel("إنقاص عداد الذكر بمقدار واحد")
            }

            if !sync.showsWatchClockCover && sync.showsResetButton {
                Button {
                    pendingScreenReset = sync.azkarList.first { $0.title == sync.currentZekr }
                    showScreenResetConfirmation = pendingScreenReset != nil
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                        .frame(width: 32, height: 32)
                        .fadhkuruniGlass(radius: 16)
                }
                .buttonStyle(.plain)
                .disabled(sync.currentCount == 0)
                .opacity(sync.currentCount == 0 ? 0.35 : 1)
                .offset(x: 27, y: 31)
                .accessibilityLabel("تصفير عداد الذكر الحالي")
            }

        }
        .environment(\.layoutDirection, .leftToRight)
        .frame(width: 136, height: 136)
        .contentShape(Circle())
    }

private struct EmeraldAnalogClock: View {
    let date: Date
    let photoData: Data?

    private var calendar: Calendar { Calendar.current }
    private var hourAngle: Double {
        let parts = calendar.dateComponents([.hour, .minute, .second], from: date)
        let hour = Double((parts.hour ?? 0) % 12)
        let minute = Double(parts.minute ?? 0)
        let second = Double(parts.second ?? 0)
        return hour * 30 + minute * 0.5 + second / 120
    }
    private var minuteAngle: Double {
        let parts = calendar.dateComponents([.minute, .second], from: date)
        return Double(parts.minute ?? 0) * 6 + Double(parts.second ?? 0) * 0.1
    }
    private var secondAngle: Double {
        Double(calendar.component(.second, from: date)) * 6
    }

    var body: some View {
        ZStack {
            if let photoData, let image = UIImage(data: photoData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    // Keep the chosen photo large and square, inside a frosted
                    // crystal frame that fits the counter's existing circle.
                    .frame(width: 118, height: 118)
                    .clipShape(RoundedRectangle(cornerRadius: 27, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 27, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .opacity(0.18)
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 27, style: .continuous)
                            .strokeBorder(
                                LinearGradient(colors: [.white.opacity(0.92), .mint.opacity(0.45), .white.opacity(0.30)], startPoint: .topLeading, endPoint: .bottomTrailing),
                                lineWidth: 1.4
                            )
                    }
                    .shadow(color: .mint.opacity(0.36), radius: 9, y: 3)
            } else {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.white.opacity(0.92), .mint.opacity(0.70), .green.opacity(0.52), Color(red: 0.01, green: 0.22, blue: 0.12)],
                            center: .topLeading,
                            startRadius: 3,
                            endRadius: 106
                        )
                    )
            }
            Circle()
                .strokeBorder(.white.opacity(0.72), lineWidth: 1.2)
                .shadow(color: .mint.opacity(0.38), radius: 12)
            Circle()
                .strokeBorder(.white.opacity(0.22), lineWidth: 1)
                .padding(11)
            Circle()
                .strokeBorder(
                    AngularGradient(
                        colors: [.clear, .white.opacity(0.86), .mint.opacity(0.65), .clear, .white.opacity(0.50), .clear],
                        center: .center
                    ),
                    lineWidth: 2
                )
                .padding(5)
            RoundedRectangle(cornerRadius: 25, style: .continuous)
                .fill(.white.opacity(photoData == nil ? 0.23 : 0.16))
                .frame(width: 83, height: 20)
                .rotationEffect(.degrees(-31))
                .offset(x: -20, y: -40)
                .blur(radius: 2)
            Circle()
                .fill(.black.opacity(0.13))
                .frame(width: 98, height: 98)
                .offset(x: 26, y: 33)
                .blur(radius: 14)
            Image(systemName: "sparkle")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(.white.opacity(0.94))
                .shadow(color: .mint.opacity(0.9), radius: 5)
                .offset(x: -39, y: -37)
            Image(systemName: "sparkle")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.78))
                .shadow(color: .mint.opacity(0.8), radius: 4)
                .offset(x: 42, y: 22)
            ForEach(0..<12, id: \.self) { tick in
                Capsule()
                    .fill(.white.opacity(tick % 3 == 0 ? 0.92 : 0.48))
                    .frame(width: tick % 3 == 0 ? 2.5 : 1, height: tick % 3 == 0 ? 10 : 5)
                    .offset(y: -51)
                    .rotationEffect(.degrees(Double(tick) * 30))
            }

            clockHand(length: 31, width: 5, color: .white, angle: hourAngle)
            clockHand(length: 43, width: 3, color: .white.opacity(0.92), angle: minuteAngle)
            clockHand(length: 47, width: 1.25, color: .mint.opacity(0.96), angle: secondAngle)

            Circle()
                .fill(.mint)
                .frame(width: 9, height: 9)
                .overlay(Circle().stroke(.white.opacity(0.9), lineWidth: 1))
                .shadow(color: .mint.opacity(0.9), radius: 5)
        }
        .environment(\.layoutDirection, .leftToRight)
        .frame(width: 136, height: 136)
        .clipShape(Circle())
    }

    private func clockHand(length: CGFloat, width: CGFloat, color: Color, angle: Double) -> some View {
        Capsule()
            .fill(color)
            .frame(width: width, height: length)
            .offset(y: -length / 2)
            .rotationEffect(.degrees(angle))
            .shadow(color: .black.opacity(0.28), radius: 1.5, y: 1)
    }
}

    // MARK: - مواقيت الصلاة داخل الدائرة نفسها
    private var watchPrayerCircleView: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            let prayers = sync.prayerTimes.sorted { $0.date < $1.date }
            let nextIndex = prayers.firstIndex { $0.date > context.date }
            ZStack {
                Circle().stroke(Color.green.opacity(0.14), lineWidth: 6)

                if let nextIndex {
                    let next = prayers[nextIndex]
                    let previousDate = nextIndex > 0 ? prayers[nextIndex - 1].date : next.date.addingTimeInterval(-3 * 60 * 60)
                    let interval = max(1, next.date.timeIntervalSince(previousDate))
                    let elapsed = min(max(0, context.date.timeIntervalSince(previousDate)), interval)
                    let progress = elapsed / interval
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(LinearGradient(colors: [.green.opacity(0.65), .mint], startPoint: .bottomLeading, endPoint: .topTrailing), style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .rotationEffect(.degrees(-90))

                    VStack(spacing: 2) {
                        Image(systemName: next.symbol)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.mint)
                        Text("القادمة")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.secondary)
                        Text(next.title)
                            .font(.system(size: 17, weight: .bold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.65)
                        Text(watchPrayerRemainingText(until: next.date, from: context.date))
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.green)
                            .lineLimit(1)
                        Text(next.date.formatted(date: .omitted, time: .shortened))
                            .font(.system(size: 9, weight: .medium).monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
                } else {
                    VStack(spacing: 5) {
                        Image(systemName: "location.circle")
                            .font(.system(size: 25, weight: .light))
                            .foregroundStyle(.green)
                        Text("تحديث المواقيت")
                            .font(.system(size: 12, weight: .semibold))
                        Text("افتح تطبيق الآيفون")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(width: 136, height: 136)
        }
        .environment(\.layoutDirection, .leftToRight)
        .contentShape(Circle())
        .onTapGesture {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                isPrayerTimesActive = false
            }
            WKInterfaceDevice.current().play(.click)
        }
    }

    private func watchPrayerRemainingText(until date: Date, from now: Date) -> String {
        let minutes = max(1, Int((date.timeIntervalSince(now) / 60).rounded(.up)))
        if minutes < 60 { return "باقي \(minutes) د" }
        let hours = minutes / 60
        let remainder = minutes % 60
        return remainder == 0 ? "باقي \(hours) س" : "باقي \(hours) س \(remainder) د"
    }

    // MARK: - بطاقة القبلة داخل دائرة الساعة
    private var watchQiblaCircleView: some View {
        ZStack {
            // الحلقة الخارجية
            Circle()
                .stroke(
                    qibla.isAligned
                        ? LinearGradient(colors: [Color.yellow, Color(red: 0.98, green: 0.75, blue: 0.14), Color.yellow], startPoint: .topLeading, endPoint: .bottomTrailing)
                        : LinearGradient(colors: [Color.green.opacity(0.4), Color.green.opacity(0.15)], startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: qibla.isAligned ? 3 : 2
                )
                .shadow(color: qibla.isAligned ? Color.yellow.opacity(0.4) : .clear, radius: 8)

            if qibla.isAligned {
                // صورة الكعبة المشرفة فائقة الوضوح تحت العدسة الزجاجية الكريستالية
                ZStack {
                    Image("HolyKaaba")
                        .resizable()
                        .scaledToFill()
                        .frame(width: 122, height: 122)
                        .clipShape(Circle())

                    // العدسة الزجاجية الكريستالية
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.white.opacity(0.48),
                                    Color.white.opacity(0.15),
                                    Color.black.opacity(0.30),
                                    Color.white.opacity(0.25)
                                ],
                                center: .init(x: 0.35, y: 0.25),
                                startRadius: 0,
                                endRadius: 65
                            )
                        )
                        .frame(width: 122, height: 122)
                        .overlay(
                            Circle()
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.85),
                                            Color.yellow.opacity(0.45),
                                            Color.white.opacity(0.20)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1.5
                                )
                        )
                        .overlay(alignment: .top) {
                            Ellipse()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.white.opacity(0.70), Color.white.opacity(0.18), Color.clear],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .frame(width: 76, height: 32)
                                .padding(.top, 4)
                        }
                        .overlay(alignment: .bottom) {
                            Ellipse()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.clear, Color.white.opacity(0.25)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .frame(width: 56, height: 10)
                                .padding(.bottom, 4)
                        }
                }
                .transition(.scale(scale: 0.88).combined(with: .opacity))
            } else {
                // قرص وإبرة بوصلة القبلة
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.04))
                        .frame(width: 122, height: 122)

                    // علامات الجهات
                    VStack {
                        Text("ش")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.red)
                        Spacer()
                        Text("ج")
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                    .frame(height: 114)

                    HStack {
                        Text("غ")
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("ش")
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                    .frame(width: 114)

                    // إبرة قبلة زجاجية — تدويرها يبقى مرتبطاً بالاتجاه الحقيقي للقبلة.
                    VStack(spacing: 0) {
                        ZStack {
                            Image(systemName: "location.north.fill")
                                .font(.system(size: 25, weight: .bold))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.white.opacity(0.96), .mint.opacity(0.9), .green.opacity(0.92)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                            Image(systemName: "location.north.fill")
                                .font(.system(size: 25, weight: .bold))
                                .foregroundStyle(.white.opacity(0.36))
                                .blur(radius: 0.7)
                                .offset(x: -1, y: -1)
                        }
                        .shadow(color: .green.opacity(0.42), radius: 6, y: 2)
                    }
                    .rotationEffect(.degrees(qibla.needleAngle))
                    .animation(.spring(response: 0.35, dampingFraction: 0.75), value: qibla.needleAngle)

                    // توجيه الحركة
                    VStack {
                        Spacer()
                        let angle = qibla.needleAngle
                        Text(abs(angle) <= 12 ? "اقتربت" : (angle > 0 ? "اتجه يميناً" : "اتجه يساراً"))
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(abs(angle) <= 12 ? Color.yellow : Color.green)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(Color.black.opacity(0.75))
                            .clipShape(Capsule())
                            .padding(.bottom, 12)
                    }
                }
            }
        }
        .environment(\.layoutDirection, .leftToRight)
        .frame(width: 136, height: 136)
        .contentShape(Circle())
        .onTapGesture {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                isQiblaActive = false
                QiblaManager.shared.stop()
            }
            WKInterfaceDevice.current().play(.click)
        }
    }

    private func restoreCrownFocus() {
        isCrownFocused = scenePhase == .active && !showCrownMenu
    }

    private func decrementCount() {
        guard sync.currentCount > 0 else { return }
        sync.decrementCurrentZekr()
        lastIncrementTime = Date()
        WatchKeepAwakeManager.shared.recordCountingActivity()
        WKInterfaceDevice.current().play(.click)
    }

    // MARK: - التسبيح والاهتزاز
    private func incrementCount() {
        let now = Date()
        // منع اللمسة المكررة غير المقصودة فقط، من دون تعطيل التسبيح السريع.
        guard now.timeIntervalSince(lastIncrementTime) > 0.12 else {
            return
        }
        lastIncrementTime = now
        
        // Renew the five-minute idle deadline for every local tasbih action.
        WatchKeepAwakeManager.shared.recordCountingActivity()

        guard let reachedGoal = sync.incrementCurrentZekr() else { return }
        withAnimation(.easeOut(duration: 0.28)) {
            isCounterPressing = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.30) {
            withAnimation(.easeOut(duration: 0.14)) {
                isCounterPressing = false
            }
        }
        TapFeedback.shared.play(goalReached: reachedGoal)
    }

    private func returnToCounter() {
        guard isQiblaActive || isPrayerTimesActive else { return }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            isQiblaActive = false
            isPrayerTimesActive = false
            QiblaManager.shared.stop()
        }
        WKInterfaceDevice.current().play(.click)
    }
}

// MARK: - قائمة التاج
struct CrownOptionsView: View {
    @ObservedObject var sync: WatchSyncService
    @Binding var isPresented: Bool
    @State private var showResetConfirmation = false
    @State private var pendingReset: ZekrItem?

    private var progress: Double {
        guard sync.target > 0 else { return 0 }
        return min(1, max(0, Double(sync.currentCount) / Double(sync.target)))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        Text("الخيارات")
                            .font(.headline)
                            .foregroundStyle(.green)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 6)
                        progressSummary
                            .padding(.bottom, 4)

                        NavigationLink {
                            WatchSelectZekrView(sync: sync, isPresented: $isPresented)
                        } label: {
                            CrownOptionCard(title: "الأذكار", subtitle: "اختر ذكرك", symbol: "arrow.triangle.2.circlepath", tint: .green)
                        }
                        .buttonStyle(.plain)

                        NavigationLink {
                            WatchSetTargetView(sync: sync, isPresented: $isPresented)
                        } label: {
                            CrownOptionCard(title: "الهدف", subtitle: "\(sync.target.formatted()) مرة", symbol: "target", tint: .yellow)
                        }
                        .buttonStyle(.plain)

                        Toggle("زر إنقاص العداد", isOn: Binding(
                            get: { sync.showsDecrementButton },
                            set: { sync.setShowsDecrementButton($0) }
                        ))
                        .font(.caption)
                        .tint(.green)
                        .padding(10)

                        Toggle("زر تصفير العداد", isOn: Binding(
                            get: { sync.showsResetButton },
                            set: { sync.setShowsResetButton($0) }
                        ))
                        .font(.caption)
                        .tint(.green)
                        .padding(10)

                        Toggle("عرض وجه الساعة", isOn: Binding(
                            get: { sync.showsWatchClockCover },
                            set: { sync.setWatchClockCover($0) }
                        ))
                        .font(.caption)
                        .tint(.mint)
                        .padding(10)

                        Text("إدارة العداد")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 10)
                            .padding(.horizontal, 6)

                        Button {
                            guard sync.currentCount > 0 else { return }
                            sync.decrementCurrentZekr()
                            WatchKeepAwakeManager.shared.recordCountingActivity()
                            WKInterfaceDevice.current().play(.click)
                        } label: {
                            CrownOptionCard(title: "إنقاص العدد", subtitle: "العدد الحالي: \(sync.currentCount.formatted())", symbol: "minus.circle", tint: .orange, showsChevron: false)
                        }
                        .buttonStyle(.plain)
                        .disabled(sync.currentCount == 0)
                        .opacity(sync.currentCount == 0 ? 0.45 : 1)

                        Button(role: .destructive) {
                            pendingReset = sync.azkarList.first { $0.title == sync.currentZekr }
                            showResetConfirmation = pendingReset != nil
                        } label: {
                            CrownOptionCard(title: "تصفير العداد", subtitle: "البدء من جديد", symbol: "arrow.counterclockwise", tint: .red, showsChevron: false, isDestructive: true)
                        }
                        .buttonStyle(.plain)
                        .disabled(sync.currentCount == 0)
                        .opacity(sync.currentCount == 0 ? 0.45 : 1)

                        NavigationLink {
                            TapFeedbackSettingsView()
                        } label: {
                            CrownOptionCard(title: "تنبيه الضغطات", subtitle: "نغمة قصيرة أو اهتزاز", symbol: "hand.tap", tint: .blue)
                        }
                        .buttonStyle(.plain)

                        NavigationLink {
                            PrivacyPolicyView()
                        } label: {
                            CrownOptionCard(title: "الخصوصية", subtitle: nil, symbol: "checkmark.shield", tint: .gray)
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 2)

                        NavigationLink {
                            WatchButtonsGuideView { isPresented = false }
                        } label: {
                            CrownOptionCard(title: "دليل استخدام الأزرار", subtitle: "شرح لكل زر وإيماءة", symbol: "questionmark.circle.fill", tint: .teal)
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 2)
                    }
                    .padding(.horizontal, 2)
                    .padding(.bottom, 16)
                }
                // The scroll view owns crown scrolling while this sheet is open.
                .scrollIndicators(.visible)
            }
            .padding(.horizontal, 8)
            .background(Color.black.ignoresSafeArea())
            .environment(\.layoutDirection, .rightToLeft)
            .toolbar(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    closeButton
                }
            }
            .sheet(isPresented: $showResetConfirmation, onDismiss: { pendingReset = nil }) {
                WatchResetConfirmationView {
                    if let item = pendingReset {
                        sync.resetZekrCount(for: item)
                        WatchKeepAwakeManager.shared.recordCountingActivity()
                        WKInterfaceDevice.current().play(.success)
                    }
                    pendingReset = nil
                }
            }
        }
        .environment(\.layoutDirection, .leftToRight)
        .preferredColorScheme(.dark)
    }

    private var closeButton: some View {
        Button {
            isPresented = false
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .fadhkuruniGlass(radius: 15)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("إغلاق الخيارات")
    }

    private var progressSummary: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(sync.currentZekr.isEmpty ? "اختر ذكراً من القائمة" : sync.currentZekr)
                .font(.headline)
                .foregroundStyle(.white)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 4) {
                Text(sync.currentCount, format: .number)
                Text("/")
                Text(sync.target, format: .number)
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(.green)
            .environment(\.layoutDirection, .leftToRight)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(sync.currentCount) من \(sync.target)")
            ProgressView(value: progress)
                .tint(.green)
                .accessibilityLabel("تقدم الهدف")
                .animation(.easeOut(duration: 0.2), value: progress)
        }
        .padding(.horizontal, 6)
    }
}

private struct CrownOptionCard: View {
    let title: String
    let subtitle: String?
    let symbol: String
    let tint: Color
    var showsChevron = true
    var isDestructive = false
    @ScaledMetric(relativeTo: .body) private var iconSize: CGFloat = 34

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: symbol)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(tint)
                .frame(width: iconSize, height: iconSize)
                .background(tint.opacity(0.16), in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.58))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if showsChevron {
                Image(systemName: "chevron.forward")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.55))
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)
        .fadhkuruniGlass(tint: isDestructive ? .red : tint, radius: 18)
    }
}

// MARK: - شاشة تحديد الهدف في الساعة
struct WatchSetTargetView: View {
    @ObservedObject var sync: WatchSyncService
    @Binding var isPresented: Bool
    @State private var currentTarget = 33
    @FocusState private var isTargetCrownFocused: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                Text(sync.currentZekr)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Text(currentTarget.formatted())
                    .font(.system(size: 32, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                    .foregroundStyle(.orange)
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel("الهدف \(currentTarget) مرة")
                HStack(spacing: 12) {
                    targetAdjustment(symbol: "minus", label: "إنقاص الهدف", disabled: currentTarget <= 1) {
                        currentTarget = max(1, currentTarget - (currentTarget > 10 ? 10 : 1))
                    }
                    targetAdjustment(symbol: "plus", label: "زيادة الهدف", disabled: currentTarget >= 10000) {
                        currentTarget = min(10000, currentTarget + 10)
                    }
                }
                .environment(\.layoutDirection, .leftToRight)
                Text("أهداف سريعة")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                WatchTargetPresets(selection: $currentTarget)
                Button {
                    sync.sendSyncPayload(count: sync.currentCount, zekr: sync.currentZekr, target: currentTarget)
                    WKInterfaceDevice.current().play(.success)
                    isPresented = false
                } label: {
                    Text("حفظ الهدف")
                        .font(.system(size: 14, weight: .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .fadhkuruniGlass(tint: .green)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
        }
        .navigationTitle("الهدف")
        .environment(\.layoutDirection, .rightToLeft)
        .onAppear {
            currentTarget = min(10000, max(1, sync.target))
            isTargetCrownFocused = true
        }
        .focusable()
        .focused($isTargetCrownFocused)
        .digitalCrownRotation(
            Binding(get: { Double(currentTarget) }, set: { currentTarget = min(10000, max(1, Int($0))) }),
            from: 1, through: 10000, by: 1, sensitivity: .medium,
            isContinuous: false, isHapticFeedbackEnabled: true
        )
    }

    private func targetAdjustment(symbol: String, label: String, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button {
            action()
            WKInterfaceDevice.current().play(.click)
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .semibold))
                .frame(maxWidth: .infinity, minHeight: 44)
                .fadhkuruniGlass(radius: 14)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.4 : 1)
        .accessibilityLabel(label)
    }
}

// MARK: - شاشة اختيار وتغيير نوع الذكر في الساعة
struct WatchSelectZekrView: View {
    @ObservedObject var sync: WatchSyncService
    @Binding var isPresented: Bool
    
    var body: some View {
        List {
            NavigationLink {
                WatchAddZekrView(sync: sync, isPresented: $isPresented)
            } label: {
                Label("إضافة ذكر جديد", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .foregroundStyle(.green)
                    .padding(.vertical, 4)
            }
            .accessibilityHint("أضف نص الذكر وحدد هدفه واحفظه على الساعة والآيفون")

            ForEach(sync.azkarList) { item in
                Button {
                    sync.selectZekr(item)
                    WKInterfaceDevice.current().play(.success)
                    isPresented = false
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title)
                                .font(.headline)
                                .foregroundColor(sync.currentZekr == item.title ? .green : .primary)
                            HStack(spacing: 6) {
                                Text("المنجز: \(item.count)")
                                    .font(.caption2.bold())
                                    .foregroundColor(.green)
                                Text("•")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Text("الهدف: \(item.defaultTarget)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        Spacer()
                        if sync.currentZekr == item.title {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.body)
                        }
                    }
                }
            }
        }
        .navigationTitle("نوع الذكر")
        .environment(\.layoutDirection, .rightToLeft)
    }
}

#Preview {
    WatchContentView()
}

// Shared by the counter and Crown menu; cancellation never mutates the count.
private struct WatchResetConfirmationView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var didConfirm = false
    let onConfirm: () -> Void
    private let coral = Color(red: 1, green: 0.53, blue: 0.50)

    var body: some View {
        ScrollView {
            VStack(spacing: 9) {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 21, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))
                    .frame(width: 42, height: 42)
                    .fadhkuruniGlass(radius: 21)
                Text("تصفير العداد؟")
                    .font(.system(size: 17, weight: .semibold))
                Text("سيعود عداد الذكر الحالي إلى الصفر")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Button(role: .destructive) {
                    guard !didConfirm else { return }
                    didConfirm = true
                    onConfirm()
                    dismiss()
                } label: {
                    Text("تصفير")
                        .frame(maxWidth: .infinity, minHeight: 42)
                        .foregroundStyle(coral)
                        .fadhkuruniGlass(tint: coral, radius: 15)
                }
                .disabled(didConfirm)
                Button { dismiss() } label: {
                    Text("رجوع")
                        .frame(maxWidth: .infinity, minHeight: 42)
                        .foregroundStyle(.white)
                        .fadhkuruniGlass(radius: 15)
                }
                .accessibilityHint("إلغاء التصفير والاحتفاظ بالعدد")
            }
            .font(.system(size: 15, weight: .semibold))
            .buttonStyle(.plain)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
        .background(Color.black.ignoresSafeArea())
        .environment(\.layoutDirection, .rightToLeft)
        .preferredColorScheme(.dark)
    }
}

