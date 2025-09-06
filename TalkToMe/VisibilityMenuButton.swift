// VisibilityMenuButton.swift
import SwiftUI

struct VisibilityMenuButton: ToolbarContent {
    @AppStorage("showNavTiles") private var showNavTiles: Bool = true
    @AppStorage("showAddTileButton") private var showAddTileButton: Bool = true
    @AppStorage("showBottomActionBar") private var showBottomActionBar: Bool = true
    @AppStorage("showSentenceBar") private var showSentenceBar: Bool = true

    var body: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Toggle(isOn: $showSentenceBar) {
                    Label(String(localized: "Sentence Bar"), systemImage: "text.bubble")
                }
                Toggle(isOn: $showNavTiles) {
                    Label(String(localized: "Back/Home Tiles"), systemImage: "arrow.triangle.branch")
                }
                Toggle(isOn: $showAddTileButton) {
                    Label(String(localized: "Add Tile Button"), systemImage: "plus.circle")
                }
                Toggle(isOn: $showBottomActionBar) {
                    Label(String(localized: "Bottom Action Bar"), systemImage: "square.bottomthird.inset.filled")
                }
            } label: {
                Label(String(localized: "View Options"), systemImage: "eye")
            }
        }
    }
}
