import SwiftUI

struct SubscriptionView: View {
    @ObservedObject private var access = DhikrSummariesSubscriptionAccess.shared

    var body: some View {
        Form {
            Section("مجاني بالكامل") {
                Label("جميع ميزات التسبيح والساعة مجانية", systemImage: "checkmark.seal.fill")
                    .foregroundStyle(.green)
                Text("العدّاد، الأذكار، الأهداف، اتجاه القبلة، مواقيت الصلاة ونغماتها، وجميع ميزات Apple Watch الأساسية متاحة مجاناً لجميع المستخدمين.")
            }

            Section("اشتراك الميزات المتقدمة") {
                HStack(spacing: 12) {
                    Image(systemName: "chart.bar.xaxis")
                        .foregroundStyle(.mint)
                        .font(.title2)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("الملخصات وحجب العداد ووضع الأمان")
                            .font(.body.weight(.medium))
                        Text(access.statusDescription)
                            .font(.caption)
                            .foregroundStyle(access.isSubscribed ? .green : (access.isWithinFreeTrial ? .mint : .secondary))
                    }
                }
                .padding(.vertical, 3)

                Text("ملخصات الذكر وحجب عداد الذكر ووضع الأمان متاحة مجاناً لمدة شهر كامل، ثم تتطلب اشتراكاً شهرياً بالسعر الظاهر في متجر Apple.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                NavigationLink("تفاصيل الاشتراك") {
                    DhikrSummariesSubscriptionView()
                }
            }

            Section("إدارة الاشتراك") {
                Text("يمكنك مراجعة أو إلغاء اشتراكك في أي وقت من إعدادات حسابك في Apple. تبقى جميع ميزات التسبيح والساعة متاحة مجاناً حتى بعد الإلغاء.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Link("إدارة الاشتراكات في حساب Apple", destination: URL(string: "https://apps.apple.com/account/subscriptions")!)
            }
        }
        .navigationTitle(L10n.isEnglish ? "Subscriptions & Pricing" : "الاشتراك والأسعار")
        .environment(\.layoutDirection, AppLanguage.shared.layoutDirection)
    }
}
