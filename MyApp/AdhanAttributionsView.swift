import SwiftUI

struct AdhanAttributionsView: View {
    var body: some View {
        List {
            Section {
                Text("تتضمن الأصوات المدمجة مقاطع مختارة لا تتجاوز 30 ثانية، لتتوافق مع حد إشعارات الآيفون.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Section("المصادر والتراخيص") {
                attribution("مكة — الحرم", "Seyfula Islam · CC BY 3.0", "https://commons.wikimedia.org/wiki/File:Adhan,_Great_Mosque_of_Mecca_-_Jan_21,_2013.webm")
                attribution("مكة — المغرب", "3omar Faruq · CC BY 3.0", "https://commons.wikimedia.org/wiki/File:Maghrib_Adhan_at_the_Masjid_al_Haram,_Mecca_-_25_Feb,_2012.webm")
                attribution("الدار البيضاء", "Fraguando · CC BY-SA 4.0", "https://commons.wikimedia.org/wiki/File:Llamada_a_oraci%C3%B3n_Mezquita_Hassan_II.wav")
                attribution("أذان هادئ", "Adam-synagda · CC0", "https://commons.wikimedia.org/wiki/File:Beautiful_adhan.ogg")
                attribution("أذان مختصر", "Atcovi · CC0", "https://commons.wikimedia.org/wiki/File:Adhan.ogg")
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
