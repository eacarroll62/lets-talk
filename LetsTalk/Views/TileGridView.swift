//
//  TileGridView.swift
//  Let's Talk
//
//  Created by Eric Carroll on 9/3/25.
//

import SwiftUI
import SwiftData
import UIKit
import NaturalLanguage
import AudioToolbox

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

    // New: distinct preview volume (0.0 ... 1.0)
    @AppStorage("previewVolume") private var previewVolume: Double = 0.33

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

    // Row/Column scanning state
    @State private var isRowPhase: Bool = true
    @State private var focusedRow: Int? = nil
    @State private var activeRowRange: Range<Int>? = nil

    // Undo (simple) for tile delete
    @State private var recentlyDeletedTile: (tile: Tile, page: Page, index: Int, imagePath: String?)?
    @State private var showUndoBanner: Bool = false

    private var selectionBehavior: SelectionBehavior {
        SelectionBehavior(rawValue: selectionBehaviorRaw) ?? .both
    }
    private var scanningMode: ScanningMode {
        ScanningMode(rawValue: scanningModeRaw) ?? .step
    }
    private var isRowColumnMode: Bool {
        // Prefer enum if updated; otherwise honor raw string
        return scanningModeRaw == "rowColumn" || scanningMode == .step && false // keep compiler aware of usage
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
                    let isFocusedVisually = isItemFocused(idx: idx, columns: columns.count, total: focusables.count)
                    focusableView(item: item,
                                  isEditing: isEditing,
                                  isSelecting: isSelecting,
                                  isFocused: isFocusedVisually)
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
                if scanningEnabled && (scanningMode == .step || isRowColumnMode) {
                    Button {
                        stepFocusBackward()
                    } label: {
                        Label(String(localized: "Previous"), systemImage: "arrow.left.circle")
                    }
                    .disabled(buildFocusableItems().isEmpty)

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
                    .disabled(!hasAnyFocus())

                    Button {
                        cancelScanning()
                    } label: {
                        Label(String(localized: "Cancel"), systemImage: "xmark.circle")
                    }

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
        // Hardware key bindings
        .background(
            KeyCommandBridgeView(
                isActive: true,
                onNext: { stepFocusForward() },
                onPrevious: { stepFocusBackward() },
                onSelect: { activateFocused() },
                onCancel: { cancelScanning() }
            )
        )
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

    private func isItemFocused(idx: Int, columns: Int, total: Int) -> Bool {
        if scanningEnabled && isRowColumnMode {
            if let range = activeRowRange, range.contains(idx) {
                // In row phase we want the whole row highlighted; in column phase, single item is highlighted
                return isRowPhase || (focusedIndex == idx)
            }
            // If no active row, only highlight the single focused index (initial condition)
            return focusedIndex == idx
        } else {
            return focusedIndex == idx
        }
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
                    let phrase = tile.pronunciationOverride?.isEmpty == false ? tile.pronunciationOverride! : tile.text
                    let code = resolvedLanguage(for: tile, text: phrase)
                    // Softer preview using distinct volume
                    speaker.preview(phrase, languageOverride: code, volume: Float(max(0.0, min(1.0, previewVolume))))
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

                        // Morphology quick actions based on Part of Speech
                        if let pos = tile.partOfSpeech {
                            Divider()
                            switch pos {
                            case .verb:
                                Button(String(localized: "Add “\(MorphologyEngine.toIng(tile.text))” to Message")) {
                                    addToMessage(MorphologyEngine.toIng(tile.text))
                                }
                                Button(String(localized: "Add “\(MorphologyEngine.toPast(tile.text))” to Message")) {
                                    addToMessage(MorphologyEngine.toPast(tile.text))
                                }
                                Button(String(localized: "Add “\(MorphologyEngine.to3rdPersonS(tile.text))” to Message")) {
                                    addToMessage(MorphologyEngine.to3rdPersonS(tile.text))
                                }
                                Button(String(localized: "Add “not”")) {
                                    speaker.text = MorphologyEngine.appendWord("not", to: speaker.text)
                                }
                            case .noun:
                                Button(String(localized: "Add Plural “\(MorphologyEngine.pluralize(tile.text))”")) {
                                    addToMessage(MorphologyEngine.pluralize(tile.text))
                                }
                            case .pronoun:
                                let variants = MorphologyEngine.pronounVariants(tile.text)
                                if variants.count > 1 {
                                    ForEach(variants, id: \.self) { form in
                                        Button(String(localized: "Add “\(form)”")) {
                                            addToMessage(form)
                                        }
                                    }
                                }
                            case .adjective:
                                Button(String(localized: "Add Comparative “\(MorphologyEngine.toComparative(tile.text))” to Message")) {
                                    addToMessage(MorphologyEngine.toComparative(tile.text))
                                }
                                Button(String(localized: "Add Superlative “\(MorphologyEngine.toSuperlative(tile.text))” to Message")) {
                                    addToMessage(MorphologyEngine.toSuperlative(tile.text))
                                }
                                Button(String(localized: "Add Adverb “\(MorphologyEngine.toAdverb(tile.text))” to Message")) {
                                    addToMessage(MorphologyEngine.toAdverb(tile.text))
                                }
                            case .adverb:
                                Button(String(localized: "Add Adjective “\(MorphologyEngine.adverbToAdjective(tile.text))” to Message")) {
                                    addToMessage(MorphologyEngine.adverbToAdjective(tile.text))
                                }
                            default:
                                EmptyView()
                            }
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
                    let code = resolvedLanguage(for: tile, text: phrase)
                    // Softer preview on focus
                    speaker.preview(phrase, languageOverride: code, volume: Float(max(0.0, min(1.0, previewVolume))))
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

    // Reusable lock badge for overlays in TileGridView
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

    // MARK: - Scanning logic

    private func startScanningIfNeeded() {
        guard scanningEnabled else {
            focusedIndex = nil
            focusedRow = nil
            activeRowRange = nil
            isRowPhase = true
            stopScanning()
            return
        }
        let count = buildFocusableItems().count
        guard count > 0 else { return }
        if focusedIndex == nil && focusedRow == nil {
            // Initialize to first item or first row depending on mode
            if isRowColumnMode {
                isRowPhase = true
                focusedRow = 0
                updateActiveRowRange()
            } else {
                focusedIndex = 0
            }
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

    private func hasAnyFocus() -> Bool {
        return focusedIndex != nil || focusedRow != nil
    }

    private func cancelScanning() {
        focusedIndex = nil
        focusedRow = nil
        activeRowRange = nil
        isRowPhase = true
        playEarconCancel()
    }

    private func updateActiveRowRange() {
        let total = buildFocusableItems().count
        let columns = gridColumns().count
        guard columns > 0 else { activeRowRange = nil; return }
        let row = max(0, focusedRow ?? 0)
        let start = row * columns
        let end = min(total, start + columns)
        if start < end {
            activeRowRange = start..<end
        } else {
            activeRowRange = nil
        }
    }

    private func stepFocusForward() {
        let total = buildFocusableItems().count
        guard total > 0 else {
            cancelScanning()
            return
        }
        if isRowColumnMode {
            let columns = gridColumns().count
            guard columns > 0 else { return }
            if isRowPhase {
                // Advance row
                let rowCount = Int(ceil(Double(total) / Double(columns)))
                let nextRow = ((focusedRow ?? -1) + 1) % max(1, rowCount)
                focusedRow = nextRow
                updateActiveRowRange()
            } else {
                // Column phase within active row
                guard let range = activeRowRange else { return }
                if let idx = focusedIndex {
                    let next = (idx + 1 <= range.upperBound - 1) ? idx + 1 : range.lowerBound
                    focusedIndex = next
                } else {
                    focusedIndex = range.lowerBound
                }
            }
        } else {
            // Step mode: single index
            let next = ((focusedIndex ?? -1) + 1) % total
            focusedIndex = next
        }
        playEarconAdvance()
    }

    private func stepFocusBackward() {
        let total = buildFocusableItems().count
        guard total > 0 else {
            cancelScanning()
            return
        }
        if isRowColumnMode {
            let columns = gridColumns().count
            guard columns > 0 else { return }
            if isRowPhase {
                // Previous row
                let rowCount = Int(ceil(Double(total) / Double(columns)))
                let prevRow = ((focusedRow ?? rowCount) - 1 + rowCount) % max(1, rowCount)
                focusedRow = prevRow
                updateActiveRowRange()
            } else {
                // Column phase within active row
                guard let range = activeRowRange else { return }
                if let idx = focusedIndex {
                    let prev = (idx - 1 >= range.lowerBound) ? idx - 1 : range.upperBound - 1
                    focusedIndex = prev
                } else {
                    focusedIndex = range.upperBound - 1
                }
            }
        } else {
            // Step mode: single index
            let prev = ((focusedIndex ?? total) - 1 + total) % total
            focusedIndex = prev
        }
        playEarconAdvance()
    }

    private func activateFocused() {
        guard scanningEnabled else { return }
        let items = buildFocusableItems()
        if isRowColumnMode {
            if isRowPhase {
                // Enter column phase for the active row
                isRowPhase = false
                if let range = activeRowRange {
                    focusedIndex = range.lowerBound
                } else {
                    // If range is nil, recompute and set to first
                    updateActiveRowRange()
                    if let range = activeRowRange {
                        focusedIndex = range.lowerBound
                    }
                }
                playEarconSelect()
                return
            }
            // Column phase: activate the focused item
            guard let idx = focusedIndex, idx >= 0, idx < items.count else { return }
            playEarconSelect()
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
            // Return to row phase on next step
            isRowPhase = true
            focusedIndex = nil
        } else {
            // Step mode
            guard let idx = focusedIndex, idx >= 0, idx < items.count else { return }
            playEarconSelect()
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
        let code = resolvedLanguage(for: tile, text: phrase)

        switch selectionBehavior {
        case .speak:
            speaker.speak(phrase, languageOverride: code, policy: .replaceCurrent)
            logRecent(text: tile.text)

        case .addToMessage:
            addToMessage(phrase)

        case .both:
            addToMessage(phrase)
            speaker.speak(phrase, languageOverride: code, policy: .replaceCurrent)
            logRecent(text: tile.text)
        }
    }

    // Auto-detect language if missing using NLLanguageRecognizer; persist on first use.
    private func resolvedLanguage(for tile: Tile, text: String) -> String? {
        if let code = tile.languageCode, !code.isEmpty { return code }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(trimmed)
        if let lang = recognizer.dominantLanguage {
            let bcp47 = lang.rawValue // e.g., "en", "es"
            // Persist for future uses
            tile.languageCode = bcp47
            try? modelContext.save()
            return bcp47
        }
        return nil
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

    // MARK: - Earcons

    private func playEarconAdvance() {
        AudioServicesPlaySystemSound(1104) // Tock
    }

    private func playEarconSelect() {
        AudioServicesPlaySystemSound(1110) // KeyPressClick
    }

    private func playEarconCancel() {
        AudioServicesPlaySystemSound(1053) // SMSReceived_Alert
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

    // Dwell progress
    @State private var dwellProgress: CGFloat = 0.0
    @State private var isDwelling: Bool = false

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
                // Dwell-to-select with progress ring
                .simultaneousGesture(
                    dwellEnabled
                    ? LongPressGesture(minimumDuration: dwellTime, maximumDistance: 50)
                        .onEnded { _ in
                            onPrimaryTap()
                            withAnimation(.easeOut(duration: 0.1)) {
                                dwellProgress = 0
                                isDwelling = false
                            }
                        }
                        .onChanged { pressing in
                            if !isDwelling {
                                isDwelling = true
                                withAnimation(.linear(duration: dwellTime)) {
                                    dwellProgress = 1.0
                                }
                            }
                        }
                    : nil
                )
                // Preview via shorter long press
                .simultaneousGesture(
                    LongPressGesture(minimumDuration: 0.5).onEnded { _ in onLongPressPreview() }
                )
                // Dwell ring overlay
                .overlay(alignment: .topTrailing) {
                    if dwellEnabled && isDwelling {
                        ZStack {
                            Circle()
                                .stroke(Color.gray.opacity(0.25), lineWidth: 6)
                            Circle()
                                .trim(from: 0, to: max(0.0, min(1.0, dwellProgress)))
                                .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                                .rotationEffect(.degrees(-90))
                        }
                        .frame(width: 28, height: 28)
                        .padding(8)
                        .transition(.opacity)
                    }
                }
                .onChange(of: isDwelling) { _, now in
                    if !now {
                        dwellProgress = 0
                    }
                }

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

// MARK: - Hardware key command bridge

private struct KeyCommandBridgeView: UIViewControllerRepresentable {
    var isActive: Bool
    var onNext: () -> Void
    var onPrevious: () -> Void
    var onSelect: () -> Void
    var onCancel: () -> Void

    func makeUIViewController(context: Context) -> KeyCommandHostingController {
        let vc = KeyCommandHostingController()
        vc.onNext = onNext
        vc.onPrevious = onPrevious
        vc.onSelect = onSelect
        vc.onCancel = onCancel
        vc.isActive = isActive
        return vc
    }

    func updateUIViewController(_ uiViewController: KeyCommandHostingController, context: Context) {
        uiViewController.onNext = onNext
        uiViewController.onPrevious = onPrevious
        uiViewController.onSelect = onSelect
        uiViewController.onCancel = onCancel
        uiViewController.isActive = isActive
        // Ensure it stays first responder to receive key events
        if isActive, uiViewController.view.window != nil {
            uiViewController.becomeFirstResponder()
        }
    }
}

private final class KeyCommandHostingController: UIViewController {
    var isActive: Bool = true
    var onNext: () -> Void = {}
    var onPrevious: () -> Void = {}
    var onSelect: () -> Void = {}
    var onCancel: () -> Void = {}

    override var canBecomeFirstResponder: Bool { true }

    private lazy var nextCommand: UIKeyCommand = {
        let cmd = UIKeyCommand(input: UIKeyCommand.inputRightArrow, modifierFlags: [], action: #selector(handleNext))
        cmd.discoverabilityTitle = String(localized: "Next")
        return cmd
    }()

    private lazy var previousCommand: UIKeyCommand = {
        let cmd = UIKeyCommand(input: UIKeyCommand.inputLeftArrow, modifierFlags: [], action: #selector(handlePrevious))
        cmd.discoverabilityTitle = String(localized: "Previous")
        return cmd
    }()

    private lazy var selectSpaceCommand: UIKeyCommand = {
        let cmd = UIKeyCommand(input: " ", modifierFlags: [], action: #selector(handleSelect))
        cmd.discoverabilityTitle = String(localized: "Select")
        return cmd
    }()

    private lazy var selectReturnCommand: UIKeyCommand = {
        let cmd = UIKeyCommand(input: "\r", modifierFlags: [], action: #selector(handleSelect))
        cmd.discoverabilityTitle = String(localized: "Select")
        return cmd
    }()

    private lazy var selectEnterCommand: UIKeyCommand = {
        // Some keyboards may send newline for Enter; handle it in addition to Return.
        let cmd = UIKeyCommand(input: "\n", modifierFlags: [], action: #selector(handleSelect))
        cmd.discoverabilityTitle = String(localized: "Select")
        return cmd
    }()

    private lazy var cancelEscapeCommand: UIKeyCommand = {
        let cmd = UIKeyCommand(input: UIKeyCommand.inputEscape, modifierFlags: [], action: #selector(handleCancel))
        cmd.discoverabilityTitle = String(localized: "Cancel")
        return cmd
    }()

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        _ = becomeFirstResponder()
    }

    override var keyCommands: [UIKeyCommand]? {
        guard isActive else { return [] }
        return [nextCommand, previousCommand, selectSpaceCommand, selectReturnCommand, selectEnterCommand, cancelEscapeCommand]
    }

    @objc private func handleNext() {
        guard isActive else { return }
        onNext()
    }

    @objc private func handlePrevious() {
        guard isActive else { return }
        onPrevious()
    }

    @objc private func handleSelect() {
        guard isActive else { return }
        onSelect()
    }

    @objc private func handleCancel() {
        guard isActive else { return }
        onCancel()
    }
}

