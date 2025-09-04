//
//  Page.swift
//  TalkToMe
//
//  Created by Eric Carroll on 9/3/25.
//

import Foundation
import SwiftData

@Model
final class Page: Identifiable {
    var id: UUID
    var name: String
    var order: Int
    var isRoot: Bool

    // Relationships
    // Inverse to Tile.page (owning tiles for this page)
    var tiles: [Tile]

    // Hierarchical pages: children <-> parent
    var parent: Page?
    var children: [Page]

    init(
        id: UUID = UUID(),
        name: String,
        order: Int,
        isRoot: Bool = false,
        tiles: [Tile] = [],
        parent: Page? = nil,
        children: [Page] = []
    ) {
        self.id = id
        self.name = name
        self.order = order
        self.isRoot = isRoot
        self.tiles = tiles
        self.parent = parent
        self.children = children
    }
}
