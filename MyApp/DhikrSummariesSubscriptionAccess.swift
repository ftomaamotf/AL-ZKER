import Foundation
import Combine
import StoreKit
import SwiftUI

@MainActor
public final class DhikrSummariesSubscriptionAccess: ObservableObject {
    public static let shared = DhikrSummariesSubscriptionAccess()

    public static let productID = "com.abduallhajmi.fadhkuruni.summaries.subscription"
    public static let trialDurationDays = 30

    @Published public private(set) var isSubscribed: Bool = false
    @Published public private(set) var isChecking: Bool = false
    @Published public private(set) var message: String? = nil
    @Published public private(set) var product: Product? = nil

    private let trialStartDateKey = "fadhkuruni_summaries_trial_start_date_v2"
    private var updatesTask: Task<Void, Never>?

    private init() {
        ensureTrialStartDateInitialized()
        listenForTransactionUpdates()
        Task {
            await refresh()
            await loadProduct()
        }
    }

    deinit {
        updatesTask?.cancel()
    }

    // MARK: - فترة التجربة المجانية (شهر كامل - 30 يوماً)
    private func ensureTrialStartDateInitialized() {
        if UserDefaults.standard.double(forKey: trialStartDateKey) == 0 {
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: trialStartDateKey)
        }
    }

    public var trialStartDate: Date {
        let timestamp = UserDefaults.standard.double(forKey: trialStartDateKey)
        if timestamp == 0 {
            let now = Date()
            UserDefaults.standard.set(now.timeIntervalSince1970, forKey: trialStartDateKey)
            return now
        }
        return Date(timeIntervalSince1970: timestamp)
    }

    /// هل المستخدم حالياً داخل فترة الشهر المجاني؟
    public var isWithinFreeTrial: Bool {
        let elapsed = Date().timeIntervalSince(trialStartDate)
        let totalTrialSeconds = Double(Self.trialDurationDays * 86_400)
        return elapsed < totalTrialSeconds
    }

    /// الأيام المتبقية من الشهر المجاني
    public var trialDaysRemaining: Int {
        let elapsed = Date().timeIntervalSince(trialStartDate)
        let totalTrialSeconds = Double(Self.trialDurationDays * 86_400)
        let remainingSeconds = totalTrialSeconds - elapsed
        guard remainingSeconds > 0 else { return 0 }
        return max(1, Int(ceil(remainingSeconds / 86_400)))
    }

    /// هل يملك المستخدم حق الدخول إلى ملخصات الذكر (إما خلال الشهر المجاني أو باشتراك فعال)؟
    public var hasAccess: Bool {
        return isWithinFreeTrial || isSubscribed
    }

    public var statusDescription: String {
        if isSubscribed {
            return "مفعّل باشتراك (1$ شهرياً)"
        } else if isWithinFreeTrial {
            return "تجربة مجانية كاملة (متبقي \(trialDaysRemaining) يوماً)"
        } else {
            return "يتطلب اشتراك (1$ شهرياً بعد انتهاء الشهر المجاني)"
        }
    }

    public var displayPrice: String {
        product?.displayPrice ?? "1.00 $"
    }

    // MARK: - StoreKit 2
    public func loadProduct() async {
        do {
            let products = try await Product.products(for: [Self.productID])
            self.product = products.first
        } catch {
            print("Failed to load subscription product: \(error)")
        }
    }

    public func refresh() async {
        isChecking = true
        defer { isChecking = false }

        var active = false
        for await verification in Transaction.currentEntitlements {
            guard case .verified(let transaction) = verification else { continue }
            if transaction.productID == Self.productID && transaction.revocationDate == nil {
                if let expiration = transaction.expirationDate {
                    if expiration > Date() {
                        active = true
                        break
                    }
                } else {
                    active = true
                    break
                }
            }
        }
        self.isSubscribed = active
    }

    public func purchase() async -> Bool {
        guard let product else {
            message = "جاري تحميل تفاصيل الاشتراك، يرجى المحاولة بعد قليل."
            await loadProduct()
            return false
        }

        isChecking = true
        message = nil
        defer { isChecking = false }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    await transaction.finish()
                    self.isSubscribed = true
                    self.message = "تم تفعيل اشتراك ملخصات الذكر بنجاح! تقبل الله طاعتكم."
                    return true
                case .unverified(_, let error):
                    self.message = "تعذر التحقق من العملية: \(error.localizedDescription)"
                    return false
                }
            case .userCancelled:
                return false
            case .pending:
                self.message = "طلب الاشتراك قيد المراجعة أو يتطلب موافقة عائلية."
                return false
            @unknown default:
                return false
            }
        } catch {
            self.message = "تعذر إتمام الاشتراك: \(error.localizedDescription)"
            return false
        }
    }

    public func restore() async {
        isChecking = true
        message = nil
        defer { isChecking = false }

        do {
            try await AppStore.sync()
            await refresh()
            if isSubscribed {
                message = "تمت استعادة اشتراكك بنجاح!"
            } else {
                message = "لم يتم العثور على اشتراك نشط مسجل لهذا الحساب."
            }
        } catch {
            message = "تعذر الاتصال بـ App Store لاستعادة الاشتراك."
        }
    }

    private func listenForTransactionUpdates() {
        updatesTask = Task.detached { [weak self] in
            for await verification in Transaction.updates {
                if case .verified(let transaction) = verification {
                    await transaction.finish()
                }
                await self?.refresh()
            }
        }
    }
}
