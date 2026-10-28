//
//  ZekrModel.swift
//  Fadhkuruni (Shared between iOS & watchOS)
//

import Foundation

public struct ZekrItem: Identifiable, Codable, Hashable {
    public var id: UUID
    public var title: String
    public var defaultTarget: Int
    public var count: Int
    
    public init(id: UUID = UUID(), title: String, defaultTarget: Int = 33, count: Int = 0) {
        self.id = id
        self.title = title
        self.defaultTarget = defaultTarget
        self.count = count
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case defaultTarget
        case count
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.title = try container.decode(String.self, forKey: .title)
        self.defaultTarget = try container.decodeIfPresent(Int.self, forKey: .defaultTarget) ?? 33
        self.count = try container.decodeIfPresent(Int.self, forKey: .count) ?? 0
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(defaultTarget, forKey: .defaultTarget)
        try container.encode(count, forKey: .count)
    }
    
    public static let builtInAzkar: [ZekrItem] = [
        ZekrItem(title: "سبحان الله", defaultTarget: 33, count: 0),
        ZekrItem(title: "الحمد لله", defaultTarget: 33, count: 0),
        ZekrItem(title: "لا إله إلا الله", defaultTarget: 33, count: 0),
        ZekrItem(title: "الله أكبر", defaultTarget: 33, count: 0),
        ZekrItem(title: "أستغفر الله", defaultTarget: 100, count: 0),
        ZekrItem(title: "لا حول ولا قوة إلا بالله", defaultTarget: 33, count: 0),
        ZekrItem(title: "اللهم صلِّ وسلم على نبينا محمد", defaultTarget: 10, count: 0),
        ZekrItem(title: "سبحان الله وبحمده سبحان الله العظيم", defaultTarget: 100, count: 0)
    ]
}
