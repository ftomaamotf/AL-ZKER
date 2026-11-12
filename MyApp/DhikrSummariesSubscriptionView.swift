import SwiftUI
import StoreKit

public struct DhikrSummariesSubscriptionView: View {
    @ObservedObject private var access = DhikrSummariesSubscriptionAccess.shared
    @Environment(\.dismiss) private var dismiss

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                // الشعار والعنوان
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(colors: [Color(red: 0.05, green: 0.65, blue: 0.45), Color(red: 0.02, green: 0.30, blue: 0.20)], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 84, height: 84)
                            .shadow(color: .mint.opacity(0.35), radius: 12, y: 4)

                        Image(systemName: "chart.bar.xaxis")
                            .font(.system(size: 38, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .padding(.top, 10)

                    Text("اشتراك فذكروني")
                        .font(.title2.weight(.bold))
                        .multilineTextAlignment(.center)

                    Text("ملخصات الذكر، حجب العداد، ووضع الأمان في مكان واحد")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }

                // بطاقة العرض والشهر المجاني
                VStack(spacing: 14) {
                    HStack(spacing: 10) {
                        Image(systemName: "gift.fill")
                            .font(.title2)
                            .foregroundStyle(.green)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("شهر كامل مجاناً")
                                .font(.headline.weight(.bold))
                                .foregroundStyle(.primary)

                            Text("ملخصات الذكر وحجب العداد ووضع الأمان مجانية لمدة 30 يوماً من أول يوم استخدام.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(14)
                    .background(Color.green.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))

                    HStack(spacing: 10) {
                        Image(systemName: "tag.fill")
                            .font(.title2)
                            .foregroundStyle(.mint)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(access.displayPrice) شهرياً بعد انتهاء الشهر")
                                .font(.headline.weight(.bold))
                                .foregroundStyle(.primary)

                            Text("سعر رمزي بسيط لدعم استمرار وتطوير التطبيق وخدمة الذكر.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(14)
                    .background(Color.mint.opacity(0.10), in: RoundedRectangle(cornerRadius: 16))

                    HStack(spacing: 10) {
                        Image(systemName: "sparkles")
                            .font(.title2)
                            .foregroundStyle(.orange)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("أساسيات التطبيق مجانية دائماً")
                                .font(.headline.weight(.bold))
                                .foregroundStyle(.primary)

                            Text("العدّاد، الأذكار، الأهداف، القبلة، المواقيت، وساعة Apple Watch متاحة للجميع.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(14)
                    .background(Color.orange.opacity(0.10), in: RoundedRectangle(cornerRadius: 16))
                }
                .padding(.horizontal, 16)

                // حالة الاشتراك الحالية
                if access.isSubscribed {
                    Label("اشتراكك مفعّل بنجاح. شكراً لدعمك!", systemImage: "checkmark.seal.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.green)
                        .padding(.vertical, 8)
                } else if access.isWithinFreeTrial {
                    VStack(spacing: 4) {
                        Text("أنت الآن تستمتع بالفترة المجانية")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.green)
                        Text("متبقي لك \(access.trialDaysRemaining) يوماً من الشهر المجاني. يمكنك الاشتراك الآن لضمان استمرار الميزة دون انقطاع.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)
                    }
                    .padding(12)
                    .background(Color(UIColor.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal, 16)
                } else {
                    VStack(spacing: 4) {
                        Text("انتهى الشهر المجاني للميزات المتقدمة")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.red)
                        Text("للاستمرار في ملخصات الذكر وحجب العداد ووضع الأمان، اشترك الآن بالسعر الظاهر في متجر Apple.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)
                    }
                    .padding(12)
                    .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal, 16)
                }

                if let message = access.message {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }

                // أزرار الشراء والاستعادة
                VStack(spacing: 12) {
                    if !access.isSubscribed {
                        Button {
                            Task {
                                _ = await access.purchase()
                            }
                        } label: {
                            HStack {
                                if access.isChecking {
                                    ProgressView().tint(.white)
                                } else {
                                    Text(access.isWithinFreeTrial ? "الاشتراك الآن (\(access.displayPrice) شهرياً)" : "بدء الاشتراك (\(access.displayPrice) شهرياً)")
                                        .font(.headline.weight(.bold))
                                }
                            }
                            .frame(maxWidth: .infinity, minHeight: 48)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color(red: 0.05, green: 0.65, blue: 0.45))
                        .disabled(access.isChecking)
                        .padding(.horizontal, 20)
                    }

                    Button {
                        Task {
                            await access.restore()
                        }
                    } label: {
                        Text("استعادة الاشتراك")
                            .font(.subheadline.weight(.medium))
                            .frame(maxWidth: .infinity, minHeight: 38)
                    }
                    .buttonStyle(.bordered)
                    .disabled(access.isChecking)
                    .padding(.horizontal, 20)
                }

                // شروط أبل والخصوصية
                VStack(spacing: 6) {
                    Text("يتم تجديد الاشتراك تلقائياً بسعر \(access.displayPrice) شهرياً ما لم يتم إلغاؤه قبل 24 ساعة على الأقل من نهاية الفترة الحالية. يمكنك إدارة أو إلغاء اشتراكك في أي وقت من إعدادات حساب Apple.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)

                    HStack(spacing: 16) {
                        Link("سياسة الخصوصية", destination: URL(string: "https://ffazkuruni.wordpress.com/privacy-policy/")!)
                            .font(.caption2)
                            .foregroundStyle(.green)

                        Text("•").foregroundStyle(.secondary)

                        Link("شروط الاستخدام (EULA)", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                            .font(.caption2)
                            .foregroundStyle(.green)
                    }
                    .padding(.top, 4)
                }
                .padding(.bottom, 20)
            }
            .padding(.vertical, 16)
        }
        .navigationTitle(L10n.isEnglish ? "Dhikr Summaries" : "ملخصات الذكر")
        .navigationBarTitleDisplayMode(.inline)
        .environment(\.layoutDirection, AppLanguage.shared.layoutDirection)
    }
}
