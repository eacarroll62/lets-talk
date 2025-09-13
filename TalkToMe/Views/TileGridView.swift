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

    @Query(sort: \Page.order) private var pages: [Page]

    var currentPage: Binding<Page>

    @Environment(\.horizontalSizeClass) private var hSizeClass
    @AppStorage("gridSizePreference") private var gridSizeRaw: String = SettingsView.GridSizePreference.medium.rawValue
    @AppStorage("customGridColumns") private var customGridColumns: Int = 4
    @AppStorage("editLocked") private var editLocked: Bool = true

    // Interaction prefs
    @AppStorage("selectionBehavior") private var selectionBehaviorRaw: String = SelectionBehavior.both.rawValue
    @AppStorage("largeTouchTargets") private var largeTouchTargets: Bool = false
    @AppStorage("scanningEnabled") private var scanningEnabled: Bool = false
    @AppStorage("scanningMode") private var scanningModeRaw: String = ScanningMode.step.rawValue
    @AppStorage("scanInterval") private var scanInterval: Double = 1.2
    @AppStorage("auditoryPreviewOnFocus") private var auditoryPreviewOnFocus: Bool = false
    @AppStorage("dwellEnabled") private var dwellEnabled: Bool = false
    @AppStorage("dwellTime") private var dwellTime: Double = 0.9

    // View visibility toggles
    @AppStorage("showNavTiles") private var showNavTiles: Bool = true
    @AppStorage("showAddTileButton") private var showAddTileButton: Bool = true
    @AppStorage("showBottomActionBar") private var showBottomActionBar: Bool = true

    // AAC scheme
    @AppStorage("aacColorScheme") private var aacColorSchemeRaw: String = AACColorScheme.fitzgerald.rawValue
    private var aacScheme: AACColorScheme { AACColorScheme(rawValue: aacColorSchemeRaw) ?? .fitzgerald }

    @State private var isPresentingEditor: Bool = false
    @State private var editingTile: Tile? = nil

    // Batch selection state
    @State private var selectedTileIDs: Set<UUID> = []
    @State private var showMoveSheet: Bool = false
    @State private var moveDestination: Page?

    // Scanning state
    @State private var focusedIndex: Int? = nil
    @State private var scanTimer: Timer? = nil

    // Undo (simple) for tile delete
    @State private var recentlyDeletedTile: (tile: Tile, page: Page, index: Int, imagePath: String?)?
    @State private var showUndoBanner: Bool = false

    private var selectionBehavior: SelectionBehavior {
        SelectionBehavior(rawValue: selectionBehaviorRaw) ?? .both
    }
    private var scanningMode: ScanningMode {
        ScanningMode(rawValue: scanningModeRaw) ?? .step
    }

    // Precomputed roots to keep type-check simple
    private var rootPages: [Page] {
        pages.filter { $0.parent == nil }
    }

    var body: some View {
        let columns = gridColumns()
        let isEditing = !editLocked && (editMode?.wrappedValue.isEditing ?? false)
        let isSelecting = isEditing

        ScrollView {
            LazyVGrid(columns: columns, spacing: largeTouchTargets ? 20 : 16) {
                // Focusable items in order: Back, Home, Add, Tiles...
                let focusables = buildFocusableItems()
                ForEach(focusables.indices, id: \.self) { idx in
                    let item = focusables[idx]
                    focusableView(item: item,
                                  isEditing: isEditing,
                                  isSelecting: isSelecting,
                                  isFocused: focusedIndex == idx)
                        .onAppear {
                            // Initialize focus when scanning starts
                            startScanningIfNeeded()
                        }
                }
            }
            .padding(largeTouchTargets ? 20 : 16)
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
        .sheet(isPresented: $showMoveSheet) {
            MoveDestinationPickerView(
                selection: $moveDestination,
                rootPages: rootPages,
                currentPageID: currentPage.wrappedValue.id,
                onCancel: { showMoveSheet = false },
                onConfirm: {
                    if let dest = moveDestination {
                        haptic(.rigid)
                        moveSelected(to: dest)
                        showMoveSheet = false
                    }
                }
            )
        }
        .toolbar {
            VisibilityMenuButton()

            ToolbarItemGroup(placement: .bottomBar) {
                if scanningEnabled && scanningMode == .step {
                    Button {
                        stepFocusForward()
                    } label: {
                        Label(String(localized: "Next"), systemImage: "arrow.right.circle")
                    }
                    .disabled(buildFocusableItems().isEmpty)

                    Button {
                        activateFocused()
                    } label: {
                        Label(String(localized: "Select"), systemImage: "checkmark.circle")
                    }
                    .disabled(focusedIndex == nil)

                    Spacer()
                }

                if showBottomActionBar && isSelecting {
                    let selectionCount = selectedTileIDs.count
                    Button {
                        showMoveSheet = true
                        moveDestination = nil
                    } label: {
                        Label(String(localized: "Move"), systemImage: "arrowshape.turn.up.right")
                    }
                    .disabled(editLocked || selectionCount == 0)

                    Button(role: .destructive) {
                        batchDeleteSelected()
                    } label: {
                        Label(String(localized: "Delete"), systemImage: "trash")
                    }
                    .disabled(editLocked || selectionCount == 0)

                    Spacer()

                    if selectionCount > 0 {
                        Text(String(localized: "\(selectionCount) selected"))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .overlay(alignment: .bottom) {
            if showUndoBanner, let payload = recentlyDeletedTile {
                HStack {
                    Text(String(localized: "Tile deleted"))
                    Spacer()
                    Button(String(localized: "Undo")) {
                        undoDelete(payload)
                    }
                }
                .padding()
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .padding()
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .onChange(of: scanningEnabled) { _, enabled in
            if enabled { startScanningIfNeeded() } else { stopScanning() }
        }
        .onDisappear {
            stopScanning()
        }
    }

    // MARK: - Focusables and views

    private enum FocusableItem {
        case back
        case home
        case add
        case tile(Tile)
    }

    private func buildFocusableItems() -> [FocusableItem] {
        var items: [FocusableItem] = []
        if showNavTiles && currentPage.wrappedValue.isRoot == false {
            items.append(.back)
            items.append(.home)
        }
        if showAddTileButton {
            items.append(.add)
        }
        items += sortedTiles().map { .tile($0) }
        return items
    }

    @ViewBuilder
    private func focusableView(item: FocusableItem, isEditing: Bool, isSelecting: Bool, isFocused: Bool) -> some View {
        switch item {
        case .back:
            navTile(systemName: "arrow.backward.circle.fill", label: String(localized: "Back")) {
                haptic(.light)
                navigateBack()
            }
            .overlay(focusRing(visible: scanningEnabled && isFocused))
            .aspectRatio(1, contentMode: .fit)

        case .home:
            navTile(systemName: "house.fill", label: String(localized: "Home")) {
                haptic(.light)
                navigateHome()
            }
            .overlay(focusRing(visible: scanningEnabled && isFocused))
            .aspectRatio(1, contentMode: .fit)

        case .add:
            addTileButton()
                .disabled(editLocked)
                .overlay(alignment: .topLeading) {
                    if editLocked {
                        lockBadge()
                            .padding(8)
                    }
                }
                .overlay(focusRing(visible: scanningEnabled && isFocused))
                .aspectRatio(1, contentMode: .fit)

        case .tile(let tile):
            let isSelected = selectedTileIDs.contains(tile.id)

            TileButton(
                tile: tile,
                aacScheme: aacScheme,
                isEditing: isEditing,
                isLocked: editLocked,
                isSelecting: isSelecting,
                isSelected: isSelected,
                onPrimaryTap: {
                    if isSelecting {
                        toggleSelection(for: tile)
                    } else {
                        haptic(.soft)
                        handleTap(tile)
                    }
                },
                onEdit: {
                    haptic(.medium)
                    startEditing(tile)
                },
                onDelete: {
                    haptic(.warning)
                    delete(tile)
                },
                onToggleSelect: {
                    toggleSelection(for: tile)
                },
                dwellEnabled: dwellEnabled,
                dwellTime: dwellTime,
                onLongPressPreview: {
                    // Long-press to preview speech without adding
                    let phrase = tile.pronunciationOverride?.isEmpty == false ? tile.pronunciationOverride! : tile.text
                    speaker.speak(phrase, languageOverride: tile.languageCode, policy: .enqueueIfSpeaking)
                }
            )
            .if(!editLocked && !isSelecting) { view in
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
            .if(!editLocked && !isSelecting) { view in
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
            .overlay(focusRing(visible: scanningEnabled && isFocused))
            .aspectRatio(1, contentMode: .fit)
            .onChange(of: isFocused) { _, focused in
                if focused, scanningEnabled, auditoryPreviewOnFocus {
                    let phrase = tile.pronunciationOverride?.isEmpty == false ? tile.pronunciationOverride! : tile.text
                    speaker.speak(phrase, languageOverride: tile.languageCode, policy: .enqueueIfSpeaking)
                }
            }
        }
    }

    @ViewBuilder
    private func focusRing(visible: Bool) -> some View {
        if visible {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.accentColor, lineWidth: 4)
                .padding(4)
                .animation(.easeInOut(duration: 0.15), value: visible)
        } else {
            EmptyView()
        }
    }

    // MARK: - Scanning logic

    private func startScanningIfNeeded() {
        guard scanningEnabled else {
            focusedIndex = nil
            stopScanning()
            return
        }
        let count = buildFocusableItems().count
        guard count > 0 else { return }
        if focusedIndex == nil {
            focusedIndex = 0
        }
        stopScanning()
        if scanningMode == .auto {
            scanTimer = Timer.scheduledTimer(withTimeInterval: max(0.3, scanInterval), repeats: true) { _ in
                stepFocusForward()
            }
        }
    }

    private func stopScanning() {
        scanTimer?.invalidate()
        scanTimer = nil
    }

    private func stepFocusForward() {
        let total = buildFocusableItems().count
        guard total > 0 else {
            focusedIndex = nil
            return
        }
        let next = ((focusedIndex ?? -1) + 1) % total
        focusedIndex = next
    }

    private func activateFocused() {
        guard scanningEnabled, let idx = focusedIndex else { return }
        let items = buildFocusableItems()
        guard idx >= 0 && idx < items.count else { return }
        switch items[idx] {
        case .back: navigateBack()
        case .home: navigateHome()
        case .add:
            if !editLocked {
                haptic(.medium)
                isPresentingEditor = true
            }
        case .tile(let tile):
            handleTap(tile)
        }
    }

    // MARK: - Grid & data

    private func gridColumns() -> [GridItem] {
        let pref = SettingsView.GridSizePreference(rawValue: gridSizeRaw) ?? .medium
        let isCompact = hSizeClass == .compact
        let base = isCompact ? 4 : 6
        let count: Int = {
            switch pref {
            case .small: return base + 2
            case .medium: return base
            case .large: return max(2, base - 2)
            case .extraLarge: return max(2, base - 4)
            case .custom: return max(2, min(10, customGridColumns))
            }
        }()
        let minSize: CGFloat = largeTouchTargets ? 140 : 100
        return Array(repeating: GridItem(.flexible(minimum: minSize), spacing: largeTouchTargets ? 20 : 16), count: count)
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
            if dest.parent == nil {
                dest.parent = currentPage.wrappedValue
                try? modelContext.save()
            }
            currentPage.wrappedValue = dest
            return
        }

        let phrase = tile.pronunciationOverride?.isEmpty == false ? tile.pronunciationOverride! : tile.text

        switch selectionBehavior {
        case .speak:
            speaker.speak(phrase, languageOverride: tile.languageCode, policy: .replaceCurrent)
            logRecent(text: tile.text)

        case .addToMessage:
            addToMessage(phrase)

        case .both:
            addToMessage(phrase)
            speaker.speak(phrase, languageOverride: tile.languageCode, policy: .replaceCurrent)
            logRecent(text: tile.text)
        }
    }

    private func addToMessage(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        speaker.text = speaker.text.isEmpty ? trimmed : speaker.text + " " + trimmed
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

        // Stage delete for undo
        let page = currentPage.wrappedValue
        guard let index = page.tiles.firstIndex(where: { $0.id == tile.id }) else { return }
        let payload = (tile: tile, page: page, index: index, imagePath: tile.imageRelativePath)

        // Remove from arrays/model, but do not remove image yet
        page.tiles.remove(at: index)
        modelContext.delete(tile)
        try? modelContext.save()

        recentlyDeletedTile = payload
        withAnimation { showUndoBanner = true }

        // Auto-dismiss after 5 seconds and finalize image deletion
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            if self.showUndoBanner {
                self.finalizeDeleteImage(imagePath: payload.imagePath)
                withAnimation { self.showUndoBanner = false }
                self.recentlyDeletedTile = nil
            }
        }
    }

    private func undoDelete(_ payload: (tile: Tile, page: Page, index: Int, imagePath: String?)) {
        // Recreate tile with original properties (SwiftData deleted instance is gone)
        let t = payload.tile
        let restored = Tile(
            id: t.id,
            text: t.text,
            symbolName: t.symbolName,
            colorHex: t.colorHex,
            order: t.order,
            isCore: t.isCore,
            pronunciationOverride: t.pronunciationOverride,
            destinationPage: t.destinationPage,
            page: payload.page,
            imageRelativePath: t.imageRelativePath,
            size: t.size,
            languageCode: t.languageCode,
            partOfSpeechRaw: t.partOfSpeechRaw
        )
        modelContext.insert(restored)
        payload.page.tiles.insert(restored, at: min(payload.index, payload.page.tiles.count))
        try? modelContext.save()

        withAnimation { showUndoBanner = false }
        recentlyDeletedTile = nil
    }

    private func finalizeDeleteImage(imagePath: String?) {
        TileImagesStorage.delete(relativePath: imagePath)
    }

    private func toggleSelection(for: Tile) {
        if selectedTileIDs.contains(`for`.id) {
            selectedTileIDs.remove(`for`.id)
        } else {
            selectedTileIDs.insert(`for`.id)
        }
    }

    // MARK: - Batch actions

    private func batchDeleteSelected() {
        guard !editLocked else { return }
        let ids = selectedTileIDs
        guard !ids.isEmpty else { return }
        let tiles = currentPage.wrappedValue.tiles.filter { ids.contains($0.id) }
        for tile in tiles {
            TileImagesStorage.delete(relativePath: tile.imageRelativePath)
            modelContext.delete(tile)
        }
        currentPage.wrappedValue.tiles.removeAll { ids.contains($0.id) }
        for (i, t) in currentPage.wrappedValue.tiles.sorted(by: { $0.order < $1.order }).enumerated() {
            t.order = i
        }
        try? modelContext.save()
        selectedTileIDs.removeAll()
    }

    private func moveSelected(to destination: Page) {
        guard !editLocked else { return }
        let ids = selectedTileIDs
        guard !ids.isEmpty else { return }
        let sourcePage = currentPage.wrappedValue
        let movingTiles = sourcePage.tiles.filter { ids.contains($0.id) }
        guard !movingTiles.isEmpty else { return }

        sourcePage.tiles.removeAll { ids.contains($0.id) }
        for (i, t) in sourcePage.tiles.sorted(by: { $0.order < $1.order }).enumerated() {
            t.order = i
        }

        let startOrder = (destination.tiles.map { $0.order }.max() ?? -1) + 1
        var order = startOrder
        for tile in movingTiles {
            tile.page = destination
            destination.tiles.append(tile)
            tile.order = order
            order += 1
        }

        try? modelContext.save()
        selectedTileIDs.removeAll()
        if destination.id != sourcePage.id {
            currentPage.wrappedValue = destination
        }
    }

    // MARK: - Nav tiles

    @ViewBuilder
    private func navTile(systemName: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: systemName)
                    .font(.system(size: 42, weight: .bold))
                Text(label)
                    .font(.headline)
                    .minimumScaleFactor(0.8)
                    .lineLimit(1)
                    .dynamicTypeSize(.large ... .accessibility3)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                    .minimumScaleFactor(0.8)
                    .lineLimit(1)
                    .dynamicTypeSize(.large ... .accessibility3)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        let descriptor = FetchDescriptor<Recent>(sortBy: [SortDescriptor(\.timestamp, order: .reverse)])
        if let all = try? modelContext.fetch(descriptor), all.count > maxCount {
            for r in all.dropFirst(maxCount) {
                modelContext.delete(r)
            }
        }
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

// MARK: - Move Destination Picker (unchanged)

private struct MoveDestinationPickerView: View {
    @Binding var selection: Page?
    let rootPages: [Page]
    let currentPageID: UUID
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        NavigationStack {
            List {
                Section(String(localized: "Select Destination Page")) {
                    RecursivePagesList(
                        pages: rootPages,
                        level: 0,
                        selection: $selection,
                        currentPageID: currentPageID
                    )
                }
            }
            .navigationTitle(String(localized: "Move Tiles"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Cancel")) { onCancel() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Move")) { onConfirm() }
                        .disabled(selection == nil || selection?.id == currentPageID)
                }
            }
        }
    }
}

private struct RecursivePagesList: View {
    let pages: [Page]
    let level: Int
    @Binding var selection: Page?
    let currentPageID: UUID

    var body: some View {
        ForEach(pages) { page in
            MoveDestinationRow(
                page: page,
                isSelected: selection?.id == page.id,
                isDisabled: page.id == currentPageID,
                indent: CGFloat(level) * 16
            ) {
                selection = page
            }
            if !page.children.isEmpty {
                RecursivePagesList(
                    pages: page.children,
                    level: level + 1,
                    selection: $selection,
                    currentPageID: currentPageID
                )
            }
        }
    }
}

private struct MoveDestinationRow: View {
    let page: Page
    let isSelected: Bool
    let isDisabled: Bool
    let indent: CGFloat
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                Image(systemName: page.isRoot ? "house.fill" : "folder")
                Text(page.name)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundColor(.blue)
                }
            }
            .padding(.leading, indent)
        }
        .disabled(isDisabled)
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
    let aacScheme: AACColorScheme
    let isEditing: Bool
    let isLocked: Bool

    // Batch selection
    let isSelecting: Bool
    let isSelected: Bool
    let onPrimaryTap: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onToggleSelect: () -> Void

    // New: dwell and preview
    let dwellEnabled: Bool
    let dwellTime: Double
    let onLongPressPreview: () -> Void

    private var sizeMultiplier: CGFloat {
        let v = CGFloat(tile.size ?? 1.0)
        return max(0.5, min(2.0, v))
    }

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let imageHeight = side * 0.5 * sizeMultiplier
            let symbolFont = side * 0.38 * sizeMultiplier
            let textFont = side * 0.16 * sizeMultiplier

            ZStack(alignment: .topLeading) {
                Button(action: onPrimaryTap) {
                    VStack(spacing: 8) {
                        if let url = tile.imageURL, let uiImage = UIImage(contentsOfFile: url.path) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFit()
                                .frame(height: imageHeight)
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        } else if let symbol = tile.symbolName, !symbol.isEmpty {
                            Image(systemName: symbol)
                                .font(.system(size: symbolFont, weight: .bold))
                        }
                        Text(tile.text)
                            .font(.system(size: textFont, weight: .semibold))
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                            .minimumScaleFactor(0.6)
                            .dynamicTypeSize(.large ... .accessibility3)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
                    .background(tileBackground().overlay(selectionOverlay()))
                    .foregroundColor(.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: .black.opacity(0.08), radius: 2, x: 0, y: 1)
                }
                .buttonStyle(.plain)
                .disabled(isEditing && !isSelecting)
                .simultaneousGesture(
                    dwellEnabled
                    ? LongPressGesture(minimumDuration: dwellTime).onEnded { _ in onPrimaryTap() }
                    : nil
                )
                .simultaneousGesture(
                    LongPressGesture(minimumDuration: 0.5).onEnded { _ in onLongPressPreview() }
                )

                if isLocked {
                    lockBadge()
                        .padding(8)
                }

                if isEditing && !isSelecting {
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

                if isSelecting {
                    // Selection checkmark
                    Button(action: onToggleSelect) {
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(isSelected ? .blue : .secondary)
                            .padding(8)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(isSelected ? String(localized: "Deselect") : String(localized: "Select")))
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private func selectionOverlay() -> some View {
        Group {
            if isSelecting && isSelected {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.blue, lineWidth: 3)
            } else {
                EmptyView()
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
        if let pos = tile.partOfSpeech {
            return FitzgeraldKey.color(for: pos, scheme: aacScheme, alpha: 0.2)
        }
        if let hex = tile.colorHex {
            return Color(hex: hex, alpha: 0.2)
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

// Shared lock badge helper for use outside TileButton in this file
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
