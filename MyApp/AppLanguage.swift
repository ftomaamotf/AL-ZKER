//
//  AppLanguage.swift
//  Fadhkuruni (Shared between iOS & watchOS)
//

import SwiftUI
import Combine

public enum LanguagePreference: String, CaseIterable, Identifiable {
    case system = "system"
    case arabic = "ar"
    case english = "en"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .system:
            return AppLanguage.shared.isEnglish ? "System Default" : "تلقائي (حسب لغة الجهاز)"
        case .arabic:
            return "العربية"
        case .english:
            return "English"
        }
    }
}

@MainActor
public final class AppLanguage: ObservableObject {
    public static let shared = AppLanguage()

    // فذكروني يُعرض بالعربية فقط. أبقينا المفتاح للتوافق مع الإصدارات السابقة
    // والمزامنة، لكن لا نسمح لقيمة محفوظة قديمة بتغيير لغة الواجهة.
    @AppStorage("fadhkuruni_app_language_preference") public var preferenceRaw: String = LanguagePreference.arabic.rawValue {
        didSet {
            objectWillChange.send()
        }
    }

    public var preference: LanguagePreference {
        get { LanguagePreference(rawValue: preferenceRaw) ?? .system }
        set { preferenceRaw = newValue.rawValue }
    }

    public var isEnglish: Bool { false }

    public var isRTL: Bool {
        !isEnglish
    }

    public var layoutDirection: LayoutDirection {
        isRTL ? .rightToLeft : .leftToRight
    }

    public var locale: Locale { Locale(identifier: "ar_SA") }

    // MARK: - Translation Dictionary
    private static let enMap: [String: String] = [
        // App Name & General Navigation
        "فَاذْكُرُونِي": "Fadhkuruni",
        "العداد": "Counter",
        "العدّاد": "Counter",
        "الأذكار والأهداف": "Azkar & Targets",
        "التذكيرات": "Reminders",
        "الإعدادات": "Settings",
        "رجوع": "Back",
        "إلغاء": "Cancel",
        "حفظ": "Save",
        "تم": "Done",
        "تعديل": "Edit",
        "حذف": "Delete",
        "تأكيد": "Confirm",
        "موافق": "OK",
        "قبول": "Confirm",
        "إغلاق": "Close",
        "استعادة": "Restore",
        "تأكيد وحفظ": "Confirm & Save",
        "حفظ التعديل": "Save Changes",
        "الخيارات": "Options",
        "الأذكار": "Azkar",
        "الهدف": "Target",
        "الخصوصية": "Privacy",
        "سياسة الخصوصية": "Privacy Policy",
        "شروط الاستخدام": "Terms of Use",
        "الدعم": "Support",
        "تواصل معنا": "Contact Us",

        // Counter Screen
        "الذكر الحالي": "Current Dhikr",
        "مواقيت الصلاة": "Prayer Times",
        "بوصلة القبلة الشريفة": "Holy Qibla Compass",
        "بحسب موقعك اليوم": "Based on your location today",
        "وجّه الهاتف نحو الكعبة": "Point phone towards the Kaaba",
        "وجّه الساعة نحو الكعبة": "Point watch towards the Kaaba",
        "المس زر المواقيت بأعلى الشاشة للعودة للعدّاد": "Tap prayer button at top to return to counter",
        "المس زر القبلة بأعلى الشاشة للعودة للعدّاد": "Tap Qibla button at top to return to counter",
        "المس في أي مكان بالشاشة للتسبيح": "Tap anywhere on the screen to count",
        "التسبيح": "Tasbih",
        "المس لإضافة تسبيحة": "Tap to add count",
        "تصفير": "Reset",
        "إنقاص": "Minus",
        "زيادة": "Add",
        "قفل العدّاد": "Lock Counter",
        "قفل الأزرار": "Lock Buttons",
        "فتح قفل العدّاد": "Unlock Counter",
        "فتح الأزرار": "Unlock Buttons",
        "تم القفل لمنع الأخطاء": "Locked to prevent mistakes",
        "اضغط مطولاً لفتح القفل": "Press & hold to unlock",
        "الإنجاز": "Progress",
        "تفاصيل الذكر": "Dhikr Details",
        "حجب الشاشة": "Cover Screen",
        "إظهار رقم عداد الساعة": "Show watch counter number",
        "عرض الوقت بدل رقم عداد الساعة": "Show clock face instead of counter",
        "فاذكروني على الساعة — صور وطريقة الاستخدام": "Fadhkuruni on Apple Watch — guide & gestures",
        "العودة للعدّاد": "Return to Counter",
        "اتجاه القبلة": "Qibla Direction",
        "محاذاة تامة": "Aligned",
        "وجّه الساعة": "Point Watch",
        "تصفير عدّاد الذكر؟": "Reset Dhikr Counter?",
        "تصفير عداد الذكر؟": "Reset Dhikr Counter?",
        "تصفير العداد": "Reset Counter",
        "إنقاص العدد": "Minus Count",
        "البدء من جديد": "Start Over",
        "إدارة العداد": "Counter Management",
        "زر إنقاص العداد": "Minus Button",
        "زر تصفير العداد": "Reset Button",
        "عرض وجه الساعة": "Show Clock Face",
        "إغلاق الخيارات": "Close Options",
        "تقدم الهدف": "Target Progress",
        "اختر ذكراً من القائمة": "Select a Dhikr from the list",
        "اختر ذكرك": "Select your Dhikr",
        "تنبيه الضغطات": "Tap Feedback",
        "نغمة قصيرة أو اهتزاز": "Short tone or haptics",
        "دليل استخدام الأزرار": "Buttons & Gestures Guide",

        // Azkar & Targets
        "إضافة ذكر جديد": "Add New Dhikr",
        "إضافة ذكر": "Add Dhikr",
        "تعديل الذكر": "Edit Dhikr",
        "نص الذكر": "Dhikr Text",
        "الهدف الافتراضي": "Default Target",
        "الهدف الحالي": "Current Target",
        "مجموع التسبيحات": "Total Counts",
        "عدد الأذكار": "Total Azkar",
        "اختر الذكر للتسبيح": "Select Dhikr to count",
        "استعادة الأذكار الافتراضية": "Restore Default Azkar",
        "هل تريد استعادة الأذكار الافتراضية؟": "Restore default Azkar list?",
        "حذف الذكر": "Delete Dhikr",
        "هل تريد بالتأكيد حذف هذا الذكر؟": "Are you sure you want to delete this Dhikr?",
        "مرة": "times",
        "مرات": "times",
        "تسبيحة": "counts",

        // Prayer Times & Qibla
        "الفجر": "Fajr",
        "الشروق": "Sunrise",
        "الظهر": "Dhuhr",
        "العصر": "Asr",
        "المغرب": "Maghrib",
        "العشاء": "Isha",
        "الصلاة القادمة": "Next Prayer",
        "الوقت المتبقي": "Time Remaining",
        "متبقي حتى أذان": "Time until",
        "حان الآن وقت أذان": "It is now time for",
        "فعّل خدمات الموقع لعرض المواقيت": "Enable location services to show prayer times",
        "جاري تحديد موقعك…": "Locating your position…",
        "يلزم السماح بالموقع لحساب المواقيت": "Location access needed for prayer times",
        "اسمح بالموقع من إعدادات الآيفون لعرض المواقيت": "Allow location in Settings to show prayer times",
        "تتحدث المواقيت حسب موقعك": "Prayer times updated for your location",
        "تعذر حساب المواقيت لهذا الموقع": "Could not calculate times for this location",
        "تعذر تحديد الموقع، حاول مرة أخرى": "Unable to determine location, try again",
        "التعديلات اليدوية": "Manual Adjustments",
        "تقديم أو تأخير مواقيت الصلاة بالدقائق": "Adjust prayer times forward or backward in minutes",
        "نغمة كل صلاة": "Adhan Tone per Prayer",
        "اختر نغمة التنبيه لكل وقت": "Choose alert tone for each prayer",
        "بوصلة القبلة": "Qibla Compass",
        "محاذاة تامة للقبلة": "Perfect Qibla Alignment",
        "درجة": "°",
        "الشمال": "N",
        "الشرق": "E",
        "الجنوب": "S",
        "الغرب": "W",

        // Dhikr Statistics & Summaries
        "ملخص الذكر": "Dhikr Summary",
        "إحصائيات الذكر": "Dhikr Statistics",
        "ملخص أيام الأسبوع": "Weekly Dhikr Summary",
        "كافة الأذكار": "All Azkar",
        "اليوم": "Today",
        "أمس": "Yesterday",
        "هذا الأسبوع": "This Week",
        "أكثر من الأمس": "More than yesterday",
        "أقل من الأمس": "Less than yesterday",
        "مثل الأمس تماماً": "Same as yesterday",
        "الأيام الأكثر ذكراً": "Most Active Days",
        "متوسط اليومي": "Daily Average",
        "أطول تتابع": "Longest Streak",
        "أيام": "days",
        "يوم": "days",
        "أنت في فترة التجربة المجانية": "You are in the Free Trial Period",
        "الاشتراك": "Subscribe",
        "اشتراك ملخصات الذكر": "Dhikr Summaries Subscription",
        "شهر تجربة مجانية، ثم 1$ شهرياً": "1 month free trial, then $1 / month",
        "مسح الإحصائيات": "Clear Statistics",
        "تأكيد مسح الإحصائيات": "Confirm Clear Statistics",
        "الهدف اليومي": "Daily Goal",
        "استعادة الشراء": "Restore Purchase",
        "بدء التجربة المجانية — 1$ شهرياً بعد الشهر الأول": "Start Free Trial — $1/month after 1st month",
        "شراء دائم": "Lifetime Purchase",
        "فتح ملخصات الذكر اليومية والأسبوعية، الإحصائيات المتقدمة، المقارنة بين الأيام، وأطول تتابع للتسبيح.": "Unlock daily & weekly Dhikr summaries, advanced statistics, day-to-day comparisons, and tasbih streaks.",

        // Settings
        "لغة التطبيق": "App Language",
        "تلقائي (حسب لغة الجهاز)": "System Default",
        "تجربتك، كما تحبّها": "Your spiritual journey, tailored for you",
        "عدد الذكر على أيقونة التطبيق": "Badge Count on App Icon",
        "تعرض الشارة آخر عدد محفوظ للذكر الحالي، وتختفي عند الصفر. اسمح بالإشعارات والشارات من إعدادات الآيفون. يتحدث عدد الساعة عند وصول المزامنة إلى الآيفون.": "The app icon badge displays your latest count and clears at zero. Enable badges in iOS Settings. Watch count syncs when connected.",
        "دليل الاستخدام": "User Guide",
        "شرح لكل زر وطريقة ضغطه واستخدامه": "Explanation for every button and gesture",
        "على الآيفون": "On iPhone",
        "وضع أمان": "Driving Safety Mode",
        "التطبيق والساعة متوقفان أثناء القيادة": "App and Watch paused while driving",
        "يتوقف التسبيح على الآيفون والساعة تلقائياً أثناء القيادة، ويعود بعد انخفاض السرعة.": "Counting pauses automatically while driving for your safety, resuming after slowing down.",
        "وضع الأمان مفعّل": "Driving Safety Mode Active",
        "صوت الضغطات": "Tap Sound",
        "نقرة خفيفة": "Soft click",
        "الصوت والاهتزاز": "Sound & Haptics",
        "تنبيهات الأهداف": "Target Completion Alerts",
        "تنبيه إكمال الذكر على الآيفون": "Alert upon reaching target on iPhone",
        "ساعة آبل": "Apple Watch",
        "دليل ساعة آبل": "Apple Watch Guide",
        "حول التطبيق": "About App",
        "الخصوصية والشروط": "Privacy & Terms",

        // Reminders
        "ملخصات الذكر": "Dhikr Summaries",
        "ملخص أيام الأسبوع والمقارنات": "Weekly Summary & Trends",
        "إشعار ملخص الذكر اليومي": "Daily Dhikr Summary Alert",
        "بدء الإحصاءات من اليوم": "Start Statistics From Today",
        "تذكيراتك المخصصة": "Custom Reminders",
        "أضف تذكيراً بالوقت والنص اللذين تختارهما.": "Add a custom reminder with your chosen time and text.",
        "تذكير": "Reminder",
        "لا تنسَ ذكر الله": "Don't forget to remember Allah",
        "تذكير جديد": "New Reminder",
        "بدء الإحصاءات من اليوم؟": "Start Statistics from Today?",
        "بدء جديد": "Start Fresh",
        "سيُحذف سجل أرقام الإحصاءات القديم فقط، ويبدأ احتساب اليوم من الصفر. لن تُحذف الأذكار أو الأهداف أو العداد الحالي.": "Only past statistical counts will be reset, starting today from zero. Your Azkar, targets, and current counter will not be deleted.",
        "لم يتم بدء الإحصاءات الجديدة": "Could Not Reset Statistics",
        "اسم التذكير": "Reminder Title",
        "نص التذكير": "Reminder Message",
        "تشغيل التذكير": "Enable Reminder",
        "تذكير مخصص": "Custom Reminder",
        "تذكيرات الأذكار والصلوات": "Dhikr & Prayer Reminders",
        "إضافة تذكير": "Add Reminder",
        "وقت التذكير": "Reminder Time",
        "تكرار التذكير": "Repeat Reminder",
        "تذكير يومي": "Daily Reminder",
        "كل يوم": "Every day",
        "تفعيل التذكير": "Enable Reminder",
        "حذف التذكير": "Delete Reminder",
        "تنبيه مواقيت الصلاة": "Prayer Times Alert"
    ]

    // MARK: - Localized Lookup
    public func tr(_ key: String) -> String {
        if isEnglish {
            return Self.enMap[key] ?? key
        }
        return key
    }

    // MARK: - Specialized Localizations
    public func prayerName(id: String, arabicFallback: String) -> String {
        if isEnglish {
            switch id.lowercased() {
            case "fajr": return "Fajr"
            case "sunrise": return "Sunrise"
            case "dhuhr": return "Dhuhr"
            case "asr": return "Asr"
            case "maghrib": return "Maghrib"
            case "isha": return "Isha"
            default: return Self.enMap[arabicFallback] ?? arabicFallback
            }
        }
        return arabicFallback
    }

    public func zekrTitle(_ title: String) -> String {
        if isEnglish {
            switch DhikrText.key(title) {
            case DhikrText.key("سبحان الله"):
                return "Subhan Allah"
            case DhikrText.key("الحمد لله"):
                return "Alhamdulillah"
            case DhikrText.key("لا إله إلا الله"):
                return "La ilaha illa Allah"
            case DhikrText.key("الله أكبر"):
                return "Allahu Akbar"
            case DhikrText.key("أستغفر الله"):
                return "Astaghfirullah"
            case DhikrText.key("لا حول ولا قوة إلا بالله"):
                return "La hawla wa la quwwata illa billah"
            case DhikrText.key("اللهم صلِّ وسلم على نبينا محمد"):
                return "Blessings upon Muhammad"
            case DhikrText.key("سبحان الله وبحمده سبحان الله العظيم"):
                return "Subhan Allahi wa bihamdihi"
            default:
                return title
            }
        }
        return title
    }

    public func zekrSubtitle(_ title: String) -> String? {
        if isEnglish {
            switch DhikrText.key(title) {
            case DhikrText.key("سبحان الله"):
                return "Glory be to Allah • سبحان الله"
            case DhikrText.key("الحمد لله"):
                return "Praise be to Allah • الحمد لله"
            case DhikrText.key("لا إله إلا الله"):
                return "There is no god but Allah • لا إله إلا الله"
            case DhikrText.key("الله أكبر"):
                return "Allah is the Greatest • الله أكبر"
            case DhikrText.key("أستغفر الله"):
                return "I seek forgiveness from Allah • أستغفر الله"
            case DhikrText.key("لا حول ولا قوة إلا بالله"):
                return "No power nor strength except with Allah"
            case DhikrText.key("اللهم صلِّ وسلم على نبينا محمد"):
                return "اللهم صلِّ وسلم على نبينا محمد"
            case DhikrText.key("سبحان الله وبحمده سبحان الله العظيم"):
                return "Glory be to Allah & His praise, the Almighty"
            default:
                return nil
            }
        }
        return nil
    }

    public func dayName(dayKey: String) -> String {
        if isEnglish {
            switch dayKey {
            case "الأحد", "Sun": return "Sunday"
            case "الإثنين", "Mon": return "Monday"
            case "الثلاثاء", "Tue": return "Tuesday"
            case "الأربعاء", "Wed": return "Wednesday"
            case "الخميس", "Thu": return "Thursday"
            case "الجمعة", "Fri": return "Friday"
            case "السبت", "Sat": return "Saturday"
            default: return dayKey
            }
        }
        return dayKey
    }

    public func dayShortName(dayKey: String) -> String {
        if isEnglish {
            switch dayKey {
            case "الأحد", "Sun": return "Sun"
            case "الإثنين", "Mon": return "Mon"
            case "الثلاثاء", "Tue": return "Tue"
            case "الأربعاء", "Wed": return "Wed"
            case "الخميس", "Thu": return "Thu"
            case "الجمعة", "Fri": return "Fri"
            case "السبت", "Sat": return "Sat"
            default: return dayKey
            }
        }
        return dayKey
    }
}

// MARK: - Convenient Global Helper
public enum L10n {
    public static func tr(_ key: String) -> String {
        AppLanguage.shared.tr(key)
    }

    public static func prayerName(id: String, arabicFallback: String) -> String {
        AppLanguage.shared.prayerName(id: id, arabicFallback: arabicFallback)
    }

    public static func zekrTitle(_ title: String) -> String {
        AppLanguage.shared.zekrTitle(title)
    }

    public static func zekrSubtitle(_ title: String) -> String? {
        AppLanguage.shared.zekrSubtitle(title)
    }

    public static func dayName(dayKey: String) -> String {
        AppLanguage.shared.dayName(dayKey: dayKey)
    }

    public static func dayShortName(dayKey: String) -> String {
        AppLanguage.shared.dayShortName(dayKey: dayKey)
    }

    public static var isEnglish: Bool {
        AppLanguage.shared.isEnglish
    }

    public static var isRTL: Bool {
        AppLanguage.shared.isRTL
    }

    public static var layoutDirection: LayoutDirection {
        AppLanguage.shared.layoutDirection
    }

    public static var locale: Locale {
        AppLanguage.shared.locale
    }
}

// MARK: - String Extension
extension String {
    public var localized: String {
        AppLanguage.shared.tr(self)
    }
}
