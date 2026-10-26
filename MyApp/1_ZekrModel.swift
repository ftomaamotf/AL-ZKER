//
//  ZekrModel.swift
//  Fadhkuruni (Shared between iOS & watchOS)
//

import Foundation

public struct ZekrItem: Identifiable, Codable, Hashable {
    public var id: UUID
    public var title: String
    public var defaultTarget: Int
    
    public init(id: UUID = UUID(), title: String, defaultTarget: Int = 33) {
        self.id = id
        self.title = title
        self.defaultTarget = defaultTarget
    }
    
    public static let builtInAzkar: [ZekrItem] = [
        ZekrItem(title: "سبحان الله", defaultTarget: 33),
        ZekrItem(title: "الحمد لله", defaultTarget: 33),
        ZekrItem(title: "لا إله إلا الله", defaultTarget: 33),
        ZekrItem(title: "الله أكبر", defaultTarget: 33),
        ZekrItem(title: "أستغفر الله", defaultTarget: 100),
        ZekrItem(title: "لا حول ولا قوة إلا بالله", defaultTarget: 33),
        ZekrItem(title: "اللهم صلِّ وسلم على نبينا محمد", defaultTarget: 10),
        ZekrItem(title: "سبحان الله وبحمده سبحان الله العظيم", defaultTarget: 100)
    ]
}
