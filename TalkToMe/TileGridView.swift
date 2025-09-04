//
//  TileGridView.swift
//  Let's Talk
//
//  Created by Eric Carroll on 9/3/25.
//

import SwiftUI
import SwiftData

struct TileGridView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(Speaker.self) private var speaker

    var currentPage: Binding<Page>

    @Environment(\.horizontalSizeClass) private var hSizeClass
    @AppStorage("gridSizePreference") private var gridSizeRaw: String = SettingsView.GridSizePreference.medium.rawValue

    @State private var isPresentingEditor: Bool = false
    @State private var editingTile: Tile? = nil

    var body: some View {
        let columns = gridColumns()

        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                if currentPage.wrappedValue.isRoot == false {
                    navTile(systemName: "arrow.backward.circle.fill", label: String(localized: "Back")) {
                        navigateBack()
                    }
                    navTile(systemName: "house.fill", label: String(localized: "Home")) {
                        navigateHome()
                    }
                }

                addTileButton()

                ForEach(sortedTiles()) { tile in
                    TileButton(tile: tile) {
                        handleTap(tile)
                    }
                    .contextMenu {
                        Button(String(localized: "Edit")) { startEditing(tile) }
                        Button(String(localized: "Move Up")) { move(tile, direction: -1) }
                        Button(String(localized: "Move Down")) { move(tile, direction: +1) }
                        Button(String(localized: "Delete"), role: .destructive) { delete(tile) }
                    }
                    .onLongPressGesture {
                        startEditing(tile)
                    }
                    .accessibilityLabel(Text(tile.text))
                    .accessibilityHint(Text(tile.destinationPage == nil
                                            ? String(localized: "Speaks this word")
                                            : String(localized: "Opens category")))
                }
            }
            .padding()
        }
        .navigationTitle(currentPage.wrappedValue.name)
        .sheet(isPresented: $isPresentingEditor, onDismiss: {
            editingTile = nil
        }) {
            TileEditorView(
                page: currentPage.wrappedValue,
                tileToEdit: editingTile
            )
            .environment(speaker)
        }
    }

    private func gridColumns() -> [GridItem] {
        let pref = SettingsView.GridSizePreference(rawValue: gridSizeRaw) ?? .medium
        let isCompact = hSizeClass == .compact
        let base = isCompact ? 4 : 6
        let count: Int = {
            switch pref {
            case .small: return base + 2
            case .medium: return base
            case .large: return max(2, base - 2)
            }
        }()
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

    private func startEditing(_ tile: Tile) {
        editingTile = tile
        isPresentingEditor = true
    }

    private func move(_ tile: Tile, direction: Int) {
        var tiles = sortedTiles()
        guard let idx = tiles.firstIndex(where: { $0.id == tile.id }) else { return }
        let newIndex = idx + direction
        guard newIndex >= 0 && newIndex < tiles.count else { return }
        tiles.swapAt(idx, newIndex)
        for (i, t) in tiles.enumerated() {
            t.order = i
        }
        try? modelContext.save()
    }

    private func delete(_ tile: Tile) {
        TileImagesStorage.delete(relativePath: tile.imageRelativePath)
        if let index = currentPage.wrappedValue.tiles.firstIndex(where: { $0.id == tile.id }) {
            currentPage.wrappedValue.tiles.remove(at: index)
        }
        modelContext.delete(tile)
        try? modelContext.save()
    }

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
        .accessibilityLabel(Text(label))
    }

    @ViewBuilder
    private func addTileButton() -> some View {
        Button(action: { isPresentingEditor = true }) {
            VStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 42, weight: .bold))
                Text(String(localized: "Add"))
                    .font(.headline)
            }
            .frame(maxWidth: .infinity, minHeight: 110)
            .padding()
            .background(Color.green.opacity(0.15))
            .foregroundColor(.green)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: .black.opacity(0.08), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(String(localized: "Add Tile")))
        .accessibilityHint(Text(String(localized: "Create a new tile")))
    }
}

private struct TileButton: View {
    let tile: Tile
    let action: () -> Void

    private var sizeMultiplier: CGFloat {
        CGFloat(tile.size ?? 1.0)
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                if let url = tile.imageURL, let uiImage = UIImage(contentsOfFile: url.path) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 60 * sizeMultiplier)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                } else if let symbol = tile.symbolName, !symbol.isEmpty {
                    Image(systemName: symbol)
                        .font(.system(size: 42 * sizeMultiplier, weight: .bold))
                }
                Text(tile.text)
                    .font(.system(size: 17 * sizeMultiplier, weight: .semibold))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.6)
            }
            .frame(maxWidth: .infinity, minHeight: 110 * sizeMultiplier)
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
