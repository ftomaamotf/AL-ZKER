import SwiftUI

struct SubscriptionView: View {
    @ObservedObject private var access = DhikrSummariesSubscriptionAccess.shared

    var body: some View {
        Form {
            Section("مجاني بالكامل") {
                Label("جميع ميزات التسبيح والساعة مجانية", systemImage: "checkmark.seal.fill")
                    .foregroundStyle(.green)
                Text("العدّاد، الأذكار، الأهداف، اتجاه القبلة، مواقيت الصلاة ونغماتها، وقفل العدّاد، وجميع ميزات Apple Watch متاحة مجاناً 100% لجميع المستخدمين دون أي رسوم.")
            }

            Section("اشتراك ملخصات الذكر") {
                HStack(spacing: 12) {
                    Image(systemName: "chart.bar.xaxis")
                        .foregroundStyle(.mint)
                        .font(.title2)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("ملخصات الذكر وإحصاءات الأسبوع")
                            .font(.body.weight(.medium))
                        Text(access.statusDescription)
                            .font(.caption)
                            .foregroundStyle(access.isSubscribed ? .green : (access.isWithinFreeTrial ? .mint : .secondary))
                    }
                }
                .padding(.vertical, 3)

                Text("ميزة ملخصات الذكر متاحة مجاناً لمدة شهر كامل لجميع المستخدمين، وتتطلب بعد ذلك اشتراكاً رمزياً بسيطاً بسعر 1$ شهرياً فقط لدعم استمرار وتطوير التطبيق.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                NavigationLink("تفاصيل اشتراك ملخصات الذكر") {
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
