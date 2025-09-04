// QuickPhrase.swift

import Foundation
import SwiftData

@Model
final class QuickPhrase: Identifiable {
    var id: UUID
    var text: String
    var order: Int

    init(id: UUID = UUID(), text: String, order: Int) {
        self.id = id
        self.text = text
        self.order = order
    }
}
