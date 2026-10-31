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

    // توقيت آخر تسبيحة لإلغاء وتفادي أي هزة ثانية متكررة عند تحريك الأصابع
    @State private var lastIncrementTime: Date = .distantPast

    var body: some View {
        VStack(spacing: 6) {
            // 1. المنطقة العلوية (العنوان + الذكر + العداد) قابلة للمس المباشر
            VStack(spacing: 4) {
                Text("فَاذْكُرُونِي")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text(sync.currentZekr)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .padding(.horizontal, 4)

                Text("\(sync.currentCount)")
                    .font(.system(size: 54, weight: .bold, design: .rounded))
                    .foregroundStyle(.green)
                    .contentTransition(.numericText())
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            // لمس المنطقة العلوية للعد (اهتزاز بنقرة واحدة عند لمس الشاشة)
            .onTapGesture {
                incrementCount()
            }

            HStack(spacing: 16) {
                if sync.showsDecrementButton {
                Button {
                    decrementCount()
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.85))
                        .frame(width: 44, height: 44)
                        .fadhkuruniGlass(radius: 22)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .disabled(sync.currentCount == 0)
                .opacity(sync.currentCount == 0 ? 0.45 : 1)
                .accessibilityLabel("إنقاص عداد الذكر بمقدار واحد")
                .accessibilityHint("اضغط لإنقاص العدد مرة واحدة")
                .accessibilityAction(named: Text("إنقاص العدد مرة واحدة")) {
                    decrementCount()
                }
                }
            Button {
                // نفس مسار العد للتفاعل باللمس أو الإيماءة.
                incrementCount()
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .fadhkuruniGlass(tint: .green, radius: 28)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("زيادة عداد التسبيح")
            .accessibilityHint("اضغط الزائد أو استخدم إيماءة النقر المزدوج لإضافة تسبيحة")
            .enableDoubleTapGesture() // تفعيل إيماءة النقر المزدوج بالسبابة والإبهام

            }
            .environment(\.layoutDirection, .leftToRight)

            if sync.showsResetButton {
            Button {
                pendingScreenReset = sync.azkarList.first { $0.title == sync.currentZekr }
                showScreenResetConfirmation = pendingScreenReset != nil
            } label: {
                HStack(spacing: 10) {
                    Text("تصفير").foregroundStyle(.white.opacity(0.9))
                    Image(systemName: "arrow.counterclockwise")
                        .foregroundStyle(.white.opacity(0.85))
                        .frame(width: 26, height: 26)
                        .background(.black.opacity(0.3), in: Circle())
                }
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 114, height: 38)
                .fadhkuruniGlass(radius: 14)
                .contentShape(RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
            .disabled(sync.currentCount == 0)
            .opacity(sync.currentCount == 0 ? 0.45 : 1)
            .accessibilityLabel("تصفير عداد الذكر الحالي")
            .accessibilityHint("يفتح تأكيد تصفير العداد")
            }


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
        }
        .onChange(of: scenePhase) {
            if scenePhase == .active {
                sync.activateSession()
                WatchKeepAwakeManager.shared.resumeCountingSession()
                restoreCrownFocus()
            } else if scenePhase == .background {
                WatchKeepAwakeManager.shared.stopKeepAwake()
                isCrownFocused = false
            }
            // Inactive (for example, a lowered wrist) keeps the existing session and idle deadline.
        }
    }

    private func restoreCrownFocus() {
        isCrownFocused = scenePhase == .active && !showCrownMenu
    }

    private func decrementCount() {
        guard sync.currentCount > 0 else { return }
        sync.sendSyncPayload(count: sync.currentCount - 1, zekr: sync.currentZekr, target: sync.target)
        lastIncrementTime = Date()
        WatchKeepAwakeManager.shared.recordCountingActivity()
        WKInterfaceDevice.current().play(.click)
    }

    // MARK: - التسبيح والاهتزاز
    private func incrementCount() {
        let now = Date()
        // إلغاء أي هزة ثانية متكررة عند تحريك الأصابع فوراً (Debounce 0.4s)
        guard now.timeIntervalSince(lastIncrementTime) > 0.4 else {
            return
        }
        lastIncrementTime = now
        
        // Renew the five-minute idle deadline for every local tasbih action.
        WatchKeepAwakeManager.shared.recordCountingActivity()

        guard let reachedGoal = sync.incrementCurrentZekr() else { return }
        TapFeedback.shared.play(goalReached: reachedGoal)
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

                        Text("إدارة العداد")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 10)
                            .padding(.horizontal, 6)

                        Button {
                            guard sync.currentCount > 0 else { return }
                            sync.sendSyncPayload(count: sync.currentCount - 1, zekr: sync.currentZekr, target: sync.target)
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
                            WatchQiblaView()
                        } label: {
                            CrownOptionCard(title: "القبلة", subtitle: "اتجاه الكعبة", symbol: "location.north.circle", tint: .teal)
                        }
                        .buttonStyle(.plain)

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
