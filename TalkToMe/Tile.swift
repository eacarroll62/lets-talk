//
//  Tile.swift
//  TalkToMe
//
//  Created by Eric Carroll on 9/3/25.
//

import Foundation
import SwiftData

@Model
final class Tile: Identifiable {
    var id: UUID
    var text: String
    var symbolName: String?
    var colorHex: String?
    var order: Int
    var isCore: Bool
    var pronunciationOverride: String?

    // Relationships inferred by SwiftData
    var destinationPage: Page?
    var page: Page?

    init(
        id: UUID = UUID(),
        text: String,
        symbolName: String? = nil,
        colorHex: String? = nil,
        order: Int,
        isCore: Bool = false,
        pronunciationOverride: String? = nil,
        destinationPage: Page? = nil,
        page: Page? = nil
    ) {
        self.id = id
        self.text = text
        self.symbolName = symbolName
        self.colorHex = colorHex
        self.order = order
        self.isCore = isCore
        self.pronunciationOverride = pronunciationOverride
        self.destinationPage = destinationPage
        self.page = page
    }
}
