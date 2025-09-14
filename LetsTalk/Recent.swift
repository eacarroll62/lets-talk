// Recent.swift

import Foundation
import SwiftData

@Model
final class Recent: Identifiable {
    var id: UUID
    var text: String
    var timestamp: Date
    var count: Int

    init(id: UUID = UUID(), text: String, timestamp: Date = Date(), count: Int = 1) {
        self.id = id
        self.text = text
        self.timestamp = timestamp
        self.count = count
    }
}
