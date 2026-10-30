import SwiftUI

// Kept as an information screen for users of older versions; no subscription
// products, trials, or purchase actions remain in this version.
struct SubscriptionView: View {
    var body: some View {
        Form {
            Section("مجانية بالكامل") {
                Label("جميع ميزات الآيفون متاحة للجميع", systemImage: "checkmark.seal.fill")
                    .foregroundStyle(.green)
                Text("التسبيح والأذكار والأهداف والقبلة ونغمات إكمال الهدف وقفل العدّاد مجانية، دون مدة تجريبية أو اشتراك.")
            }
            Section("نسخة الساعة") {
                Text("تُفتح نسخة Apple Watch بشراء دائم لمرة واحدة، دون تجديد تلقائي. يظهر سعر متجرك قبل تأكيد الشراء.")
                NavigationLink("شراء نسخة الساعة أو استعادة الشراء") { WatchPurchaseView() }
            }
            Section("اشتراك من إصدار سابق") {
                Text("إذا سبق لك الاشتراك، فإن تحديث التطبيق لا يلغي التجديد تلقائيًا. يمكنك مراجعة الاشتراك أو إلغاؤه من حساب Apple. تبقى ميزات الآيفون متاحة مجانًا بعد الإلغاء.")
                    .font(.footnote).foregroundStyle(.secondary)
                Link("إدارة الاشتراكات السابقة", destination: URL(string: "https://apps.apple.com/account/subscriptions")!)
            }
        }
        .navigationTitle("ميزات الآيفون")
        .environment(\.layoutDirection, .rightToLeft)
    }
}
