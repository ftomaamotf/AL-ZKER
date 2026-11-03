import SwiftUI

struct AdhanAttributionsView: View {
    var body: some View {
        List {
            Section {
                Text("تتضمن الأصوات المدمجة تسجيلات أذان كاملة عالية الدقة داخل التطبيق، ومقاطع متوافقة مع حد إشعارات الآيفون (30 ثانية).")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Section("المصادر والتراخيص") {
                attribution("مكة — الحرم المكي", "Seyfula Islam · CC BY 3.0", "https://commons.wikimedia.org/wiki/File:Adhan,_Great_Mosque_of_Mecca_-_Jan_21,_2013.webm")
                attribution("المدينة — المسجد النبوي", "تسجيل الحرم النبوي الشريف · Public Domain / أرشيف", "https://archive.org/details/MadinahAsrAdhan2913SheikhSurayhi")
                attribution("مصر — الشيخ عبد الباسط", "القارئ الشيخ عبد الباسط عبد الصمد · ملكية عامة", "https://archive.org/details/EgyptAdhan")
                attribution("القدس والشام — تاريخي", "صباح فخري · ملكية عامة / Public Domain", "https://commons.wikimedia.org/wiki/File:Call_to_prayer_by_Sabah_Fakhry.mp3")
                attribution("تكبيرات العيد والحرم", "تسجيل جامع إبيناي · CC BY 3.0", "https://commons.wikimedia.org/wiki/File:Takbeerat_of_Eid_al-Fitr_1434_AH_at_the_Mosque_of_Epinay-Sur-Seine_-_8_August_2013.webm")
                attribution("مكة — أذان المغرب", "3omar Faruq · CC BY 3.0", "https://commons.wikimedia.org/wiki/File:Maghrib_Adhan_at_the_Masjid_al_Haram,_Mecca_-_25_Feb,_2012.webm")
                attribution("الدار البيضاء — جامع الحسن الثاني", "Fraguando · CC BY-SA 4.0", "https://commons.wikimedia.org/wiki/File:Llamada_a_oraci%C3%B3n_Mezquita_Hassan_II.wav")
                attribution("أذان نديّ وهادئ", "عاقب عزيز · CC BY-SA 4.0", "https://commons.wikimedia.org/wiki/File:The_Adhan_-_Muslim_Call_to_Prayer_-_Aaqib_Azeez.mp3")
                attribution("أذان السكينة", "Adam-synagda · CC0", "https://commons.wikimedia.org/wiki/File:Beautiful_adhan.ogg")
                attribution("أذان مختصر للتنبيه", "Atcovi · CC0", "https://commons.wikimedia.org/wiki/File:Adhan.ogg")
            }
        }
        .navigationTitle("تراخيص الأصوات")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func attribution(_ title: String, _ details: String, _ source: String) -> some View {
        Link(destination: URL(string: source)!) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).foregroundStyle(.primary)
                Text(details).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}
