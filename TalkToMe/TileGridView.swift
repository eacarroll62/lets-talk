//
//  TileGridView.swift
//  Let's Talk
//
//  Created by Eric Carroll on 9/3/25.
//

import SwiftUI
import SwiftData
import UIKit

struct TileGridView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(Speaker.self) private var speaker
    @Environment(\.editMode) private var editMode

    var currentPage: Binding<Page>

    @Environment(\.horizontalSizeClass) private var hSizeClass
    @AppStorage("gridSizePreference") private var gridSizeRaw: String = SettingsView.GridSizePreference.medium.rawValue
    @AppStorage("editLocked") private var editLocked: Bool = true

    @State private var isPresentingEditor: Bool = false
    @State private var editingTile: Tile? = nil

    var body: some View {
        let columns = gridColumns()
        // Edit mode only meaningful if not locked
        let isEditing = !editLocked && (editMode?.wrappedValue.isEditing ?? false)

        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                if currentPage.wrappedValue.isRoot == false {
                    navTile(systemName: "arrow.backward.circle.fill", label: String(localized: "Back")) {
                        haptic(.light)
                        navigateBack()
                    }
                    navTile(systemName: "house.fill", label: String(localized: "Home")) {
                        haptic(.light)
                        navigateHome()
                    }
                }

                addTileButton()
                    .disabled(editLocked)
                    .overlay(alignment: .topLeading) {
                        if editLocked {
                            lockBadge()
                                .padding(8)
                        }
                    }

                ForEach(sortedTiles()) { tile in
                    TileButton(
                        tile: tile,
                        isEditing: isEditing,
                        isLocked: editLocked,
                        onPrimaryTap: {
                            haptic(.soft)
                            handleTap(tile)
                        },
                        onEdit: {
                            haptic(.medium)
                            startEditing(tile)
                        },
                        onDelete: {
                            haptic(.warning)
                            delete(tile)
                        }
                    )
                    .if(!editLocked) { view in
                        view
                            .contextMenu {
                                Button(String(localized: "Edit")) {
                                    haptic(.medium)
                                    startEditing(tile)
                                }
                                Button(String(localized: "Move Up")) {
                                    haptic(.light)
                                    move(tile, direction: -1)
                                }
                                Button(String(localized: "Move Down")) {
                                    haptic(.light)
                                    move(tile, direction: +1)
                                }
                                Button(String(localized: "Delete"), role: .destructive) {
                                    haptic(.warning)
                                    delete(tile)
                                }
                            }
                            .onLongPressGesture {
                                haptic(.medium)
                                startEditing(tile)
                            }
                    }
                    .accessibilityLabel(Text(tile.text))
                    .accessibilityHint(Text(tile.destinationPage == nil
                                            ? String(localized: "Speaks this word")
                                            : String(localized: "Opens category")))
                    // Drag & drop reordering only when unlocked
                    .if(!editLocked) { view in
                        view
                            .draggable(tile.id.uuidString)
                            .dropDestination(for: String.self) { items, _ in
                                guard let sourceIDString = items.first,
                                      let sourceID = UUID(uuidString: sourceIDString)
                                else { return false }
                                haptic(.rigid)
                                reorder(from: sourceID, to: tile.id)
                                return true
                            } isTargeted: { _ in }
                    }
                }

                if !editLocked {
                    Color.clear
                        .frame(height: 1)
                        .dropDestination(for: String.self) { items, _ in
                            guard let sourceIDString = items.first,
                                  let sourceID = UUID(uuidString: sourceIDString)
                            else { return false }
                            haptic(.rigid)
                            moveToEnd(sourceID: sourceID)
                            return true
                        }
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
        // No editing interactions while locked, but normal speak/navigate still work
        if let dest = tile.destinationPage {
            if dest.parent == nil {
                dest.parent = currentPage.wrappedValue
                try? modelContext.save()
            }
            currentPage.wrappedValue = dest
            return
        }
        let phrase = tile.pronunciationOverride?.isEmpty == false ? tile.pronunciationOverride! : tile.text
        speaker.speak(phrase)
        logRecent(text: tile.text)
    }

    private func startEditing(_ tile: Tile) {
        guard !editLocked else { return }
        editingTile = tile
        isPresentingEditor = true
    }

    private func move(_ tile: Tile, direction: Int) {
        guard !editLocked else { return }
        var tiles = sortedTiles()
        guard let idx = tiles.firstIndex(where: { $0.id == tile.id }) else { return }
        let newIndex = idx + direction
        guard newIndex >= 0 && newIndex < tiles.count else { return }
        tiles.swapAt(idx, newIndex)
        for (i, t) in tiles.enumerated() { t.order = i }
        try? modelContext.save()
    }

    private func delete(_ tile: Tile) {
        guard !editLocked else { return }
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
        Button(action: {
            if !editLocked {
                haptic(.medium)
                isPresentingEditor = true
            }
        }) {
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

    // MARK: - Drag & Drop

    private func reorder(from sourceID: UUID, to targetID: UUID) {
        guard !editLocked else { return }
        var tiles = sortedTiles()
        guard let fromIndex = tiles.firstIndex(where: { $0.id == sourceID }),
              let toIndex = tiles.firstIndex(where: { $0.id == targetID }),
              fromIndex != toIndex else { return }
        let moving = tiles.remove(at: fromIndex)
        tiles.insert(moving, at: toIndex)
        for (i, t) in tiles.enumerated() { t.order = i }
        try? modelContext.save()
    }

    private func moveToEnd(sourceID: UUID) {
        guard !editLocked else { return }
        var tiles = sortedTiles()
        guard let fromIndex = tiles.firstIndex(where: { $0.id == sourceID }) else { return }
        let moving = tiles.remove(at: fromIndex)
        tiles.append(moving)
        for (i, t) in tiles.enumerated() { t.order = i }
        try? modelContext.save()
    }

    // MARK: - Recents logging

    private func logRecent(text: String) {
        let predicate = #Predicate<Recent> { $0.text == text }
        var descriptor = FetchDescriptor<Recent>(predicate: predicate)
        descriptor.fetchLimit = 1
        if let existing = try? modelContext.fetch(descriptor).first {
            existing.count += 1
            existing.timestamp = Date()
        } else {
            modelContext.insert(Recent(text: text, timestamp: Date(), count: 1))
        }
        pruneRecents(maxCount: 20)
        try? modelContext.save()
    }

    private func pruneRecents(maxCount: Int) {
        var descriptor = FetchDescriptor<Recent>(sortBy: [SortDescriptor(\.timestamp, order: .reverse)])
        if let all = try? modelContext.fetch(descriptor), all.count > maxCount {
            for r in all.dropFirst(maxCount) {
                modelContext.delete(r)
            }
        }
    }

    // Small lock badge used on tiles when editing is locked
    @ViewBuilder
    private func lockBadge() -> some View {
        Image(systemName: "lock.fill")
            .font(.system(size: 14, weight: .bold))
            .padding(6)
            .background(.thinMaterial)
            .clipShape(Circle())
            .foregroundColor(.secondary)
            .accessibilityHidden(true)
    }

    // MARK: - Haptics

    private func haptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }

    private func haptic(_ notification: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(notification)
    }
}

// Convenience view modifier to conditionally apply modifiers
private extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition { transform(self) } else { self }
    }
}

private struct TileButton: View {
    let tile: Tile
    let isEditing: Bool
    let isLocked: Bool
    let onPrimaryTap: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    private var sizeMultiplier: CGFloat {
        CGFloat(tile.size ?? 1.0)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Button(action: onPrimaryTap) {
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
            .disabled(isEditing) // disable primary tap during edit mode

            if isLocked {
                lockBadge()
                    .padding(8)
            }

            if isEditing {
                HStack {
                    Button(role: .destructive, action: onDelete) {
                        Image(systemName: "trash.fill")
                            .font(.system(size: 18, weight: .bold))
                            .padding(8)
                            .background(Color.red.opacity(0.9))
                            .foregroundColor(.white)
                            .clipShape(Circle())
                    }
                    .accessibilityLabel(Text(String(localized: "Delete")))
                    .padding([.top, .leading], 8)

                    Spacer()

                    Button(action: onEdit) {
                        Image(systemName: "pencil")
                            .font(.system(size: 18, weight: .bold))
                            .padding(8)
                            .background(Color.blue.opacity(0.9))
                            .foregroundColor(.white)
                            .clipShape(Circle())
                    }
                    .accessibilityLabel(Text(String(localized: "Edit")))
                    .padding([.top, .trailing], 8)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        }
    }

    @ViewBuilder
    private func lockBadge() -> some View {
        Image(systemName: "lock.fill")
            .font(.system(size: 14, weight: .bold))
            .padding(6)
            .background(.thinMaterial)
            .clipShape(Circle())
            .foregroundColor(.secondary)
            .accessibilityHidden(true)
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

