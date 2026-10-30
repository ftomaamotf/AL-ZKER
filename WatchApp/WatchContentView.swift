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

            // 2. زر الزيادة الأساسي (مخصص لاستقبال إيماءة Double Tap باليد)
            Button {
                // نفس مسار العد للتفاعل باللمس أو الإيماءة.
                incrementCount()
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(Color.green)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("زيادة عداد التسبيح")
            .accessibilityHint("اضغط الزائد أو استخدم إيماءة النقر المزدوج لإضافة تسبيحة")
            .enableDoubleTapGesture() // تفعيل إيماءة النقر المزدوج بالسبابة والإبهام


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
            .confirmationDialog("تصفير عداد الذكر؟", isPresented: $showResetConfirmation, titleVisibility: .visible) {
                Button("قبول", role: .destructive) {
                    if let item = pendingReset {
                        sync.resetZekrCount(for: item)
                        WatchKeepAwakeManager.shared.recordCountingActivity()
                        WKInterfaceDevice.current().play(.success)
                    }
                    pendingReset = nil
                }
                Button("إلغاء", role: .cancel) { pendingReset = nil }
            } message: {
                Text(pendingReset.map { "سيُصفّر عداد «\($0.title)» فقط، وسيبقى الذكر محفوظاً." } ?? "")
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
                .background(Color.white.opacity(0.1), in: Circle())
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
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(LinearGradient(colors: isDestructive ? [Color.red.opacity(0.18), Color.red.opacity(0.08)] : [Color.white.opacity(0.095), Color.white.opacity(0.045)], startPoint: .topLeading, endPoint: .bottomTrailing))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(isDestructive ? Color.red.opacity(0.14) : Color.white.opacity(0.045), lineWidth: 0.5)
        }
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(subtitle ?? "")
    }
}

// MARK: - شاشة تحديد الهدف في الساعة
struct WatchSetTargetView: View {
    @ObservedObject var sync: WatchSyncService
    @Binding var isPresented: Bool
    @State private var currentTarget: Int = 33
    @FocusState private var isTargetCrownFocused: Bool
    
    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                Text("\(currentTarget)")
                    .font(.system(size: 46, weight: .heavy, design: .rounded))
                    .foregroundColor(.orange)
                
                // أزرار الزيادة والنقصان
                HStack(spacing: 14) {
                    Button {
                        if currentTarget > 1 {
                            currentTarget = max(1, currentTarget - (currentTarget > 10 ? 10 : 1))
                            WKInterfaceDevice.current().play(.click)
                        }
                    } label: {
                        Image(systemName: "minus")
                            .font(.headline.bold())
                    }
                    .buttonStyle(.bordered)
                    
                    Button {
                        currentTarget += 10
                        WKInterfaceDevice.current().play(.click)
                    } label: {
                        Image(systemName: "plus")
                            .font(.headline.bold())
                    }
                    .buttonStyle(.bordered)
                }
                
                // أهداف سريعة
                Text("أهداف سريعة:")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 4) {
                    ForEach([33, 100, 300, 1000], id: \.self) { val in
                        Button("\(val)") {
                            currentTarget = val
                            WKInterfaceDevice.current().play(.click)
                        }
                        .buttonStyle(.bordered)
                        .tint(currentTarget == val ? .orange : .gray)
                        .font(.caption2.bold())
                    }
                }
                
                Button("تأكيد وحفظ") {
                    sync.sendSyncPayload(count: sync.currentCount, zekr: sync.currentZekr, target: currentTarget)
                    WKInterfaceDevice.current().play(.success)
                    isPresented = false
                }
                .tint(.green)
                .padding(.top, 4)
            }
            .padding(.horizontal, 4)
        }
        .navigationTitle("تحديد الهدف")
        .environment(\.layoutDirection, .rightToLeft)
        .onAppear {
            currentTarget = sync.target
            isTargetCrownFocused = true
        }
        .focusable()
        .focused($isTargetCrownFocused)
        .digitalCrownRotation(
            Binding(
                get: { Double(currentTarget) },
                set: { currentTarget = max(1, Int($0)) }
            ),
            from: 1,
            through: 10000,
            by: 1,
            sensitivity: .medium,
            isContinuous: false,
            isHapticFeedbackEnabled: true
        )
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
