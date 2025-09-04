//
//  TileGridView.swift
//  TalkToMe
//
//  Created by Eric Carroll on 9/3/25.
//

import SwiftUI
import SwiftData

struct TileGridView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(Speaker.self) private var speaker

    // Hold a binding to the current page so we can reassign it (navigate)
    var currentPage: Binding<Page>

    // iPad-first: default to 6 columns; adapt down on compact width
    @Environment(\.horizontalSizeClass) private var hSizeClass

    var body: some View {
        let columns = gridColumns()

        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                // Navigation helpers (Back, Home) if not root
                if currentPage.wrappedValue.isRoot == false {
                    navTile(systemName: "arrow.backward.circle.fill", label: "Back") {
                        navigateBack()
                    }
                    navTile(systemName: "house.fill", label: "Home") {
                        navigateHome()
                    }
                }

                ForEach(sortedTiles()) { tile in
                    TileButton(tile: tile) {
                        handleTap(tile)
                    }
                }
            }
            .padding()
        }
        .navigationTitle(currentPage.wrappedValue.name)
    }

    private func gridColumns() -> [GridItem] {
        let isCompact = hSizeClass == .compact
        let count = isCompact ? 4 : 6
        return Array(repeating: GridItem(.flexible(minimum: 100), spacing: 16), count: count)
    }

    private func sortedTiles() -> [Tile] {
        currentPage.wrappedValue.tiles.sorted(by: { $0.order < $1.order })
    }

    private func navigateBack() {
        if let parent = currentPage.wrappedValue.parent {
            currentPage.wrappedValue = parent
        }
    }

    private func navigateHome() {
        var node: Page = currentPage.wrappedValue
        while let parent = node.parent {
            node = parent
        }
        currentPage.wrappedValue = node
    }

    private func handleTap(_ tile: Tile) {
        if let dest = tile.destinationPage {
            currentPage.wrappedValue = dest
            return
        }
        let phrase = tile.pronunciationOverride?.isEmpty == false ? tile.pronunciationOverride! : tile.text
        speaker.speak(phrase)
    }

    // Simple nav tile
    @ViewBuilder
    private func navTile(systemName: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: systemName)
                    .font(.system(size: 42, weight: .bold))
                Text(label)
                    .font(.headline)
            }
            .frame(maxWidth: .infinity, minHeight: 110)
            .padding()
            .background(Color.blue.opacity(0.15))
            .foregroundColor(.blue)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct TileButton: View {
    let tile: Tile
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                if let symbol = tile.symbolName, !symbol.isEmpty {
                    Image(systemName: symbol)
                        .font(.system(size: 42, weight: .bold))
                }
                Text(tile.text)
                    .font(.headline)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.6)
            }
            .frame(maxWidth: .infinity, minHeight: 110)
            .padding()
            .background(tileBackground())
            .foregroundColor(.primary)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: .black.opacity(0.08), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(.plain)
    }

    private func tileBackground() -> Color {
        if let hex = tile.colorHex, let color = Color(hex: hex) {
            return color.opacity(0.2)
        }
        return Color.yellow.opacity(0.2)
    }
}

private extension Color {
    // Minimal hex -> Color helper (#RRGGBB or RRGGBB)
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if hexSanitized.hasPrefix("#") {
            hexSanitized.removeFirst()
        }
        guard hexSanitized.count == 6,
              let rgb = Int(hexSanitized, radix: 16) else {
            return nil
        }
        let r = Double((rgb >> 16) & 0xFF) / 255.0
        let g = Double((rgb >> 8) & 0xFF) / 255.0
        let b = Double(rgb & 0xFF) / 255.0
        self = Color(red: r, green: g, blue: b)
    }
}
